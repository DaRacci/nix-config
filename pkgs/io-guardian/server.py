#!/usr/bin/env python3
"""
IO Database Guardian - WebSocket Server

This server runs on client machines that depend on an IO Hosts database.
It listens for drain/undrain commands from the IO coordinator to
control database-dependent services.

Protocol:
- All messages are JSON
- First message from client must be auth: {"type": "auth", "key": "<psk>"}
- Server responds: {"type": "auth", "status": "ok|error", "message": "..."}
- After auth, coordinator sends: {"type": "command", "action": "drain|undrain|ping"}
- Server responds: {"type": "response", "status": "ok|error", "message": "..."}
"""

import argparse
import asyncio
import json
import logging
import os
import sys
import unittest
from pathlib import Path
from time import monotonic, sleep
from unittest import mock

import websockets
from pystemd.dbuslib import DBusError
from pystemd.systemd1 import Unit
from websockets import serve

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)
logger = logging.getLogger(__name__)

authenticated_clients: set[str] = set()


class ProtocolError(ValueError):
    """Raised when a client sends an invalid protocol payload."""


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


def load_psk(psk_file: str) -> str:
    """Load the pre-shared key from file."""
    path = Path(psk_file)
    if not path.exists():
        logger.error(f"PSK file not found: {psk_file}")
        sys.exit(1)

    psk = path.read_text(encoding="utf-8").strip()
    if len(psk) < 32:
        logger.error("PSK must be at least 32 characters")
        sys.exit(1)

    return psk


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
    except (DBusError, OSError) as e:
        return False, f"Error loading unit {unit}: {e}"

    try:
        getattr(unit_obj.Unit, method_name)(b"replace")
    except DBusError as e:
        return False, f"systemd error while running {action} on {unit}: {e}"

    return _wait_for_state(unit_obj, unit, dependency_objs, target_state)


def handle_drain() -> tuple[bool, str]:
    """Stop the io-databases.target to drain dependent services."""
    logger.info("Executing drain: stopping io-databases.target")
    success, message = run_systemctl("stop", "io-databases.target")
    if success:
        logger.info("Drain successful")
    else:
        logger.error(f"Drain failed: {message}")
    return success, message


def handle_undrain() -> tuple[bool, str]:
    """Start the io-databases.target to enable dependent services."""
    logger.info("Executing undrain: starting io-databases.target")
    success, message = run_systemctl("start", "io-databases.target")
    if success:
        logger.info("Undrain successful")
    else:
        logger.error(f"Undrain failed: {message}")
    return success, message


async def handle_client(websocket, psk: str):
    """Handle a single WebSocket client connection."""
    client_id = format_client_id(websocket.remote_address)
    logger.info(f"New connection from {client_id}")

    is_authenticated = False

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

            # Handle authentication
            if msg_type == "auth":
                provided_key = message.get("key")
                if not isinstance(provided_key, str):
                    provided_key = ""
                if provided_key == psk:
                    is_authenticated = True
                    authenticated_clients.add(client_id)
                    logger.info(f"Client {client_id} authenticated successfully")
                    await websocket.send(
                        json.dumps(
                            {
                                "type": "auth",
                                "status": "ok",
                                "message": "Authentication successful",
                            }
                        )
                    )
                else:
                    logger.warning(f"Client {client_id} failed authentication")
                    await websocket.send(
                        json.dumps(
                            {
                                "type": "auth",
                                "status": "error",
                                "message": "Invalid key",
                            }
                        )
                    )
                    await websocket.close(1008, "Authentication failed")
                    return
                continue

            # All other messages require authentication
            if not is_authenticated:
                await websocket.send(
                    json.dumps({"type": "error", "message": "Not authenticated"})
                )
                await websocket.close(1008, "Not authenticated")
                return

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
        websockets.exceptions.WebSocketException,
        DBusError,
        OSError,
        asyncio.TimeoutError,
    ) as e:
        logger.error(f"Error handling client {client_id}: {e}")
    finally:
        authenticated_clients.discard(client_id)


def run_tests() -> None:
    class GuardianServerTests(unittest.TestCase):
        def test_decode_json_object_accepts_mapping(self) -> None:
            self.assertEqual(decode_json_object('{"type": "ping"}')["type"], "ping")

        def test_decode_json_object_rejects_non_object_payload(self) -> None:
            with self.assertRaisesRegex(ProtocolError, "expected JSON object"):
                decode_json_object("[]")

        def test_format_client_id_handles_missing_remote_address(self) -> None:
            self.assertEqual(format_client_id(None), "unknown")

    class GuardianServerAsyncTests(unittest.IsolatedAsyncioTestCase):
        async def test_run_action_offloads_blocking_handler(self) -> None:
            to_thread = mock.AsyncMock(return_value=(True, "drained"))
            with mock.patch.object(asyncio, "to_thread", to_thread):
                result = await run_action("drain")

            to_thread.assert_awaited_once_with(handle_drain)
            self.assertEqual(result, (True, "drained"))

        async def test_run_action_rejects_unknown_action(self) -> None:
            self.assertIsNone(await run_action("reload"))

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
    parser = argparse.ArgumentParser(
        description="IO Database Guardian WebSocket Server"
    )
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
        "--psk-file",
        type=str,
        default=os.environ.get("GUARDIAN_PSK_FILE"),
        help="Path to file containing the pre-shared key",
    )

    args = parser.parse_args(argv)

    if not args.psk_file:
        logger.error(
            "PSK file must be specified via --psk-file or GUARDIAN_PSK_FILE env var"
        )
        return 1

    psk = load_psk(args.psk_file)
    logger.info(f"Loaded PSK from {args.psk_file}")

    async def handler(websocket):
        await handle_client(websocket, psk)

    logger.info(f"Starting IO Guardian server on {args.host}:{args.port}")

    async with serve(handler, args.host, args.port):
        await asyncio.Future()  # Run forever

    return 0


def main(argv: list[str] | None = None) -> int:
    argv = list(sys.argv[1:] if argv is None else argv)
    if len(argv) == 1 and argv[0] in {"test", "--test"}:
        run_tests()
    return asyncio.run(async_main(argv))


if __name__ == "__main__":
    raise SystemExit(main())
