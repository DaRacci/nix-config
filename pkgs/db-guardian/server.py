#!/usr/bin/env python3
"""
Database Guardian - WebSocket Server

This server runs on client machines that depend on a database primary host.
It listens for drain/undrain commands from the database coordinator to
control database-dependent services.

Protocol:
- The listener is TLS-only and requires a client certificate issued by the DB Guardian
  intermediate whose common name is in the configured allowlist
- All messages are JSON
- Coordinator sends: {"type": "command", "action": "drain|undrain|ping"}
- Server responds: {"type": "response", "status": "ok|error", "message": "..."}
"""

import argparse
import asyncio
import json
import logging
import os
import ssl
import sys
import unittest
from time import monotonic, sleep
from unittest import mock

import websockets
from pystemd.dbusexc import DBusBaseError
from pystemd.systemd1 import Unit
from websockets import serve

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)
logger = logging.getLogger(__name__)


class ProtocolError(ValueError):
    """Raised when a client sends an invalid protocol payload."""


def create_server_context(
    ca_cert: str, server_cert: str, server_key: str
) -> ssl.SSLContext:
    """Build the mTLS context for the listener, trusting only the guardian intermediate."""
    context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    context.minimum_version = ssl.TLSVersion.TLSv1_2
    context.verify_mode = ssl.CERT_REQUIRED
    # The trust file holds an intermediate certificate that is not self-signed, so the
    # chain may terminate there only with partial-chain verification enabled.
    context.verify_flags |= ssl.VERIFY_X509_PARTIAL_CHAIN
    context.load_cert_chain(certfile=server_cert, keyfile=server_key)
    context.load_verify_locations(cafile=ca_cert)
    return context


def peer_common_name(connection) -> str | None:
    """Return the verified common name of the peer certificate, or None when absent."""
    certificate = connection.transport.get_extra_info("peercert")
    if not certificate:
        return None
    for relative_distinguished_name in certificate.get("subject", ()):
        for attribute, value in relative_distinguished_name:
            if attribute == "commonName":
                return value
    return None


def format_client_id(remote_address: object) -> str:
    if isinstance(remote_address, tuple) and len(remote_address) >= 2:
        return f"{remote_address[0]}:{remote_address[1]}"
    if remote_address:
        return str(remote_address)
    return "unknown"


def decode_json_object(raw_message: str) -> dict[str, object]:
    try:
        message = json.loads(raw_message)
    except json.JSONDecodeError as exc:
        raise ProtocolError("Invalid JSON") from exc

    if not isinstance(message, dict):
        raise ProtocolError("Invalid message: expected JSON object")

    return message


async def run_action(action: str) -> tuple[bool, str] | None:
    handlers = {
        "drain": handle_drain,
        "undrain": handle_undrain,
    }
    handler = handlers.get(action)
    if handler is None:
        return None
    return await asyncio.to_thread(handler)


def _decode_state(state) -> str:
    if isinstance(state, bytes):
        return state.decode()
    return state or "unknown"


def _wait_for_state(
    unit_obj: Unit,
    unit_name: str,
    dependencies: dict[str, Unit],
    target_state: str,
    timeout: float = 45,
) -> tuple[bool, str]:
    deadline = monotonic() + timeout
    last_state = _decode_state(unit_obj.Unit.ActiveState)

    dependency_objs: dict[str, tuple[Unit, str]] = {}
    for dep_unit, dep_obj in dependencies.items():
        dep_obj.load()
        current_dep_state = _decode_state(dep_obj.Unit.ActiveState)
        dependency_objs[dep_unit] = (dep_obj, current_dep_state)

    logger.info(
        f"Waiting for {unit_name} to reach state {target_state} (unit: {last_state})"
        + (
            f"\n\tdependency states: {', '.join(f'{k}={v[1]}' for k, v in dependency_objs.items())}"
            if dependencies
            else ""
        )
    )

    while monotonic() < deadline:
        unit_obj.load()
        current_state = _decode_state(unit_obj.Unit.ActiveState)
        last_state = current_state

        for dep_unit in dependencies:
            dep_obj, _ = dependency_objs[dep_unit]
            dep_obj.load()
            current_dep_state = _decode_state(dep_obj.Unit.ActiveState)
            dependency_objs[dep_unit] = (dep_obj, current_dep_state)

        unit_finished = current_state in ("failed", target_state)
        deps_finished = all(
            dep[1] in ("failed", target_state) for dep in dependency_objs.values()
        )

        if unit_finished and deps_finished:
            if current_state == target_state and all(
                dep[1] == target_state for dep in dependency_objs.values()
            ):
                return (
                    True,
                    f"{unit_name} and dependencies reached state {current_state}",
                )
            else:
                return (
                    False,
                    f"{unit_name} or dependencies reached failed state (unit: {current_state}, dependencies: {', '.join(f'{k}={v[1]}' for k, v in dependency_objs.items())})",
                )

        sleep(0.5)

    return (
        False,
        f"Timeout waiting for {unit_name} to reach state {target_state} (unit: {last_state}, dependencies: {', '.join(f'{k}={v[1]}' for k, v in dependency_objs.items())})",
    )


def run_systemctl(action: str, unit: str) -> tuple[bool, str]:
    """Control a systemd unit using pystemd and report the final state."""
    action_map = {
        "start": ("Start", "active"),
        "stop": ("Stop", "inactive"),
        "restart": ("Restart", "active"),
        "reload": ("Reload", "active"),
    }

    action_key = action.lower()

    if action_key not in action_map:
        return False, f"Unsupported systemctl action: {action}"

    method_name, target_state = action_map[action_key]

    dependency_objs: dict[str, Unit] = {}

    try:
        unit_obj = Unit(unit.encode())
        unit_obj.load()

        for dep in unit_obj.Unit.Upholds:
            dep_name = dep.decode()
            dep_obj = Unit(dep)
            dependency_objs[dep_name] = dep_obj
    except (DBusBaseError, OSError) as e:
        return False, f"Error loading unit {unit}: {e}"

    try:
        getattr(unit_obj.Unit, method_name)(b"replace")
    except DBusBaseError as e:
        return False, f"systemd error while running {action} on {unit}: {e}"

    return _wait_for_state(unit_obj, unit, dependency_objs, target_state)


def handle_drain() -> tuple[bool, str]:
    """Stop the db-databases.target to drain dependent services."""
    logger.info("Executing drain: stopping db-databases.target")
    success, message = run_systemctl("stop", "db-databases.target")
    if success:
        logger.info("Drain successful")
    else:
        logger.error(f"Drain failed: {message}")
    return success, message


def handle_undrain() -> tuple[bool, str]:
    """Start the db-databases.target to enable dependent services."""
    logger.info("Executing undrain: starting db-databases.target")
    success, message = run_systemctl("start", "db-databases.target")
    if success:
        logger.info("Undrain successful")
    else:
        logger.error(f"Undrain failed: {message}")
    return success, message


async def handle_client(websocket, allowed_cns: frozenset[str]) -> None:
    """Handle a single WebSocket client connection."""
    client_id = format_client_id(websocket.remote_address)
    common_name = peer_common_name(websocket)

    if common_name is None or common_name not in allowed_cns:
        logger.warning(
            f"Rejecting {client_id}: certificate common name {common_name!r} is not in the allowlist"
        )
        await websocket.close(1008, "Client certificate not allowed")
        return

    logger.info(f"New connection from {client_id} as {common_name}")

    try:
        async for raw_message in websocket:
            try:
                message = decode_json_object(raw_message)
            except ProtocolError as exc:
                await websocket.send(json.dumps({"type": "error", "message": str(exc)}))
                continue

            msg_type = message.get("type")
            if not isinstance(msg_type, str):
                await websocket.send(
                    json.dumps(
                        {
                            "type": "error",
                            "message": "Invalid message: missing string type",
                        }
                    )
                )
                continue

            # Handle commands
            if msg_type == "command":
                action = message.get("action")
                if not isinstance(action, str):
                    await websocket.send(
                        json.dumps(
                            {
                                "type": "error",
                                "message": "Invalid command: missing string action",
                            }
                        )
                    )
                    continue

                if action == "ping":
                    await websocket.send(
                        json.dumps(
                            {
                                "type": "response",
                                "action": "ping",
                                "status": "ok",
                                "message": "pong",
                            }
                        )
                    )
                    continue

                result = await run_action(action)
                if result is not None:
                    success, msg = result
                    await websocket.send(
                        json.dumps(
                            {
                                "type": "response",
                                "action": action,
                                "status": "ok" if success else "error",
                                "message": msg,
                            }
                        )
                    )
                else:
                    await websocket.send(
                        json.dumps(
                            {"type": "error", "message": f"Unknown action: {action}"}
                        )
                    )

            else:
                await websocket.send(
                    json.dumps(
                        {
                            "type": "error",
                            "message": f"Unknown message type: {msg_type}",
                        }
                    )
                )

    except websockets.exceptions.ConnectionClosed:
        logger.info(f"Client {client_id} disconnected")
    except (
        TimeoutError,
        websockets.exceptions.WebSocketException,
        DBusBaseError,
        OSError,
    ) as e:
        logger.error(f"Error handling client {client_id}: {e}")


def run_tests() -> None:
    class FakeTransport:
        def __init__(self, certificate: dict[str, object] | None) -> None:
            self.certificate = certificate

        def get_extra_info(self, name: str) -> dict[str, object] | None:
            return self.certificate if name == "peercert" else None

    class FakeWebSocket:
        def __init__(
            self, certificate: dict[str, object] | None, messages: list[str]
        ) -> None:
            self.remote_address = ("192.0.2.10", 54321)
            self.transport = FakeTransport(certificate)
            self.messages = list(messages)
            self.sent: list[str] = []
            self.closed: tuple[int, str] | None = None

        def __aiter__(self) -> "FakeWebSocket":
            return self

        async def __anext__(self) -> str:
            if not self.messages:
                raise StopAsyncIteration
            return self.messages.pop(0)

        async def send(self, message: str) -> None:
            self.sent.append(message)

        async def close(self, code: int, reason: str = "") -> None:
            self.closed = (code, reason)

    coordinator_certificate: dict[str, object] = {
        "subject": ((("commonName", "db-guardian-coordinator"),),),
        "issuer": ((("commonName", "DB Guardian Intermediate CA"),),),
    }
    stranger_certificate: dict[str, object] = {
        "subject": ((("commonName", "alloy-capture-relay"),),),
        "issuer": ((("commonName", "Alloy Dynamic Capture Intermediate CA"),),),
    }
    server_module = sys.modules[__name__]

    class GuardianServerTests(unittest.TestCase):
        def test_decode_json_object_accepts_mapping(self) -> None:
            self.assertEqual(decode_json_object('{"type": "ping"}')["type"], "ping")

        def test_decode_json_object_rejects_non_object_payload(self) -> None:
            with self.assertRaisesRegex(ProtocolError, "expected JSON object"):
                decode_json_object("[]")

        def test_format_client_id_handles_missing_remote_address(self) -> None:
            self.assertEqual(format_client_id(None), "unknown")

        def test_peer_common_name_reads_verified_certificate(self) -> None:
            websocket = FakeWebSocket(coordinator_certificate, [])
            self.assertEqual(peer_common_name(websocket), "db-guardian-coordinator")

        def test_peer_common_name_returns_none_without_certificate(self) -> None:
            self.assertIsNone(peer_common_name(FakeWebSocket(None, [])))

        def test_create_server_context_requires_client_certificate(self) -> None:
            context = mock.MagicMock()
            context.verify_flags = 0

            with mock.patch.object(ssl, "SSLContext", return_value=context):
                created = create_server_context("ca.pem", "cert.pem", "key.pem")

            self.assertIs(created, context)
            self.assertEqual(created.verify_mode, ssl.CERT_REQUIRED)
            self.assertEqual(created.minimum_version, ssl.TLSVersion.TLSv1_2)
            self.assertIn(ssl.VERIFY_X509_PARTIAL_CHAIN, created.verify_flags)
            created.load_cert_chain.assert_called_once_with(
                certfile="cert.pem", keyfile="key.pem"
            )
            created.load_verify_locations.assert_called_once_with(cafile="ca.pem")

        def test_run_systemctl_reports_dbus_errors(self) -> None:
            unit_factory = mock.MagicMock()
            unit_factory.return_value.load.side_effect = DBusBaseError(
                "org.freedesktop.DBus.Error.AccessDenied", "Access denied"
            )

            with mock.patch.object(server_module, "Unit", unit_factory):
                success, message = run_systemctl("stop", "db-databases.target")

            self.assertFalse(success)
            self.assertIn("Error loading unit", message)

    class GuardianServerAsyncTests(unittest.IsolatedAsyncioTestCase):
        async def test_run_action_offloads_blocking_handler(self) -> None:
            to_thread = mock.AsyncMock(return_value=(True, "drained"))
            with mock.patch.object(asyncio, "to_thread", to_thread):
                result = await run_action("drain")

            to_thread.assert_awaited_once_with(handle_drain)
            self.assertEqual(result, (True, "drained"))

        async def test_run_action_rejects_unknown_action(self) -> None:
            self.assertIsNone(await run_action("reload"))

        async def test_handle_client_rejects_unknown_common_name(self) -> None:
            websocket = FakeWebSocket(
                stranger_certificate, ['{"type": "command", "action": "drain"}']
            )

            await handle_client(websocket, frozenset({"db-guardian-coordinator"}))

            self.assertEqual(websocket.closed, (1008, "Client certificate not allowed"))
            self.assertEqual(websocket.sent, [])

        async def test_handle_client_accepts_allowed_common_name(self) -> None:
            websocket = FakeWebSocket(
                coordinator_certificate, ['{"type": "command", "action": "ping"}']
            )

            await handle_client(websocket, frozenset({"db-guardian-coordinator"}))

            self.assertIsNone(websocket.closed)
            self.assertEqual(
                json.loads(websocket.sent[0]),
                {
                    "type": "response",
                    "action": "ping",
                    "status": "ok",
                    "message": "pong",
                },
            )

        async def test_handle_client_rejects_stale_auth_frame(self) -> None:
            websocket = FakeWebSocket(
                coordinator_certificate, ['{"type": "auth", "key": "old"}']
            )

            await handle_client(websocket, frozenset({"db-guardian-coordinator"}))

            self.assertEqual(
                json.loads(websocket.sent[0])["message"],
                "Unknown message type: auth",
            )

        async def test_empty_allowlist_refuses_to_start(self) -> None:
            with mock.patch.object(server_module, "serve") as serve:
                status = await async_main(
                    [
                        "--ca-cert",
                        "ca.pem",
                        "--server-cert",
                        "cert.pem",
                        "--server-key",
                        "key.pem",
                    ]
                )

            self.assertEqual(status, 1)
            serve.assert_not_called()

    suite = unittest.TestSuite()
    suite.addTests(
        unittest.defaultTestLoader.loadTestsFromTestCase(GuardianServerTests)
    )
    suite.addTests(
        unittest.defaultTestLoader.loadTestsFromTestCase(GuardianServerAsyncTests)
    )
    result = unittest.TextTestRunner(verbosity=2).run(suite)
    raise SystemExit(0 if result.wasSuccessful() else 1)


async def async_main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description="Database Guardian WebSocket Server")
    parser.add_argument(
        "--port",
        type=int,
        default=int(os.environ.get("GUARDIAN_PORT", "9876")),
        help="Port to listen on (default: 9876)",
    )
    parser.add_argument(
        "--host",
        type=str,
        default=os.environ.get("GUARDIAN_HOST", "0.0.0.0"),
        help="Host to bind to (default: 0.0.0.0)",
    )
    parser.add_argument(
        "--ca-cert",
        type=str,
        required=True,
        help="Path to the PEM certificate of the DB Guardian intermediate CA",
    )
    parser.add_argument(
        "--server-cert",
        type=str,
        required=True,
        help="Path to the PEM server certificate chain (leaf followed by intermediate)",
    )
    parser.add_argument(
        "--server-key",
        type=str,
        required=True,
        help="Path to the PEM server private key",
    )
    parser.add_argument(
        "--allowed-cn",
        type=str,
        action="append",
        default=[],
        help="Client certificate common name to accept (repeatable, at least one required)",
    )

    args = parser.parse_args(argv)

    allowed_cns = frozenset(args.allowed_cn)
    if not allowed_cns:
        logger.error("Refusing to start: at least one --allowed-cn is required")
        return 1

    context = create_server_context(args.ca_cert, args.server_cert, args.server_key)

    async def handler(websocket):
        await handle_client(websocket, allowed_cns)

    logger.info(f"Starting DB Guardian server on {args.host}:{args.port} over TLS")

    async with serve(handler, args.host, args.port, ssl=context):
        await asyncio.Future()  # Run forever

    return 0


def main(argv: list[str] | None = None) -> int:
    argv = list(sys.argv[1:] if argv is None else argv)
    if len(argv) == 1 and argv[0] in {"test", "--test"}:
        run_tests()
    return asyncio.run(async_main(argv))


if __name__ == "__main__":
    raise SystemExit(main())
