#!/usr/bin/env python3
"""
IO Database Guardian - WebSocket Client

This client runs on IO Hosts (the database host) and connects to guardian
servers running on client machines to send drain/undrain commands.

Usage:
    io-guardian-client --action drain --hosts nixai,nixdev,nixcloud
    io-guardian-client --action undrain --hosts nixai,nixdev,nixcloud
"""

from __future__ import annotations

import argparse
import asyncio
import json
import logging
import os
import sys
import unittest
from pathlib import Path

import websockets

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)
logger = logging.getLogger(__name__)


class ProtocolError(ValueError):
    """Raised when the server responds with an invalid protocol payload."""


def load_psk(psk_file: str) -> str:
    """Load the pre-shared key from file."""
    path = Path(psk_file)
    if not path.exists():
        logger.error(f"PSK file not found: {psk_file}")
        raise SystemExit(1)

    psk = path.read_text(encoding="utf-8").strip()
    if len(psk) < 32:
        logger.error("PSK must be at least 32 characters")
        raise SystemExit(1)

    return psk


def decode_server_message(raw_message: str, expected_type: str) -> dict[str, object]:
    """Decode and validate a JSON object from the guardian server."""
    try:
        message = json.loads(raw_message)
    except json.JSONDecodeError as exc:
        raise ProtocolError("Invalid JSON response") from exc

    if not isinstance(message, dict):
        raise ProtocolError("Expected JSON object response")

    message_type = message.get("type")
    if message_type != expected_type:
        raise ProtocolError(
            f"Expected response type '{expected_type}', got {message_type!r}"
        )

    return message


async def send_command(
    host: str, port: int, psk: str, action: str, timeout: float
) -> tuple[bool, str]:
    """Send a command to a single guardian server."""
    uri = f"ws://{host}:{port}"
    logger.info(f"Connecting to {uri}...")

    try:
        async with asyncio.timeout(timeout):
            async with websockets.connect(uri) as websocket:
                auth_message = json.dumps({"type": "auth", "key": psk})
                await websocket.send(auth_message)

                response = await websocket.recv()
                auth_response = decode_server_message(response, "auth")

                if auth_response.get("status") != "ok":
                    error_msg = str(
                        auth_response.get("message", "Authentication failed")
                    )
                    logger.error(f"[{host}] Authentication failed: {error_msg}")
                    return False, f"Authentication failed: {error_msg}"

                logger.info(f"[{host}] Authenticated successfully")

                command_message = json.dumps({"type": "command", "action": action})
                await websocket.send(command_message)

                response = await websocket.recv()
                cmd_response = decode_server_message(response, "response")

                status = cmd_response.get("status")
                message = str(cmd_response.get("message", ""))

                if status == "ok":
                    logger.info(f"[{host}] Command '{action}' succeeded: {message}")
                    return True, message

                logger.error(f"[{host}] Command '{action}' failed: {message}")
                return False, message

    except asyncio.TimeoutError:
        logger.error(f"[{host}] Connection timed out after {timeout}s")
        return False, f"Connection timed out after {timeout}s"
    except ConnectionRefusedError:
        logger.warning(f"[{host}] Connection refused (server may not be running)")
        return False, "Connection refused"
    except OSError as exc:
        logger.warning(f"[{host}] Network error: {exc}")
        return False, f"Network error: {exc}"
    except (ProtocolError, websockets.exceptions.WebSocketException) as exc:
        logger.error(f"[{host}] Communication error: {exc}")
        return False, f"Communication error: {exc}"


async def send_to_all_hosts(
    hosts: list[str], port: int, psk: str, action: str, timeout: float
) -> dict[str, tuple[bool, str]]:
    """Send a command to all hosts concurrently."""
    tasks = [send_command(host, port, psk, action, timeout) for host in hosts]
    results = await asyncio.gather(*tasks)
    return dict(zip(hosts, results, strict=True))


def run_tests() -> None:
    class GuardianClientTests(unittest.TestCase):
        def test_decode_server_message_accepts_expected_type(self) -> None:
            message = decode_server_message(
                '{"type": "response", "status": "ok", "message": "pong"}',
                "response",
            )

            self.assertEqual(message["status"], "ok")
            self.assertEqual(message["message"], "pong")

        def test_decode_server_message_rejects_non_object_payload(self) -> None:
            with self.assertRaisesRegex(ProtocolError, "Expected JSON object response"):
                decode_server_message("[]", "auth")

        def test_decode_server_message_rejects_wrong_type(self) -> None:
            with self.assertRaisesRegex(ProtocolError, "Expected response type"):
                decode_server_message('{"type": "error"}', "response")

    suite = unittest.defaultTestLoader.loadTestsFromTestCase(GuardianClientTests)
    result = unittest.TextTestRunner(verbosity=2).run(suite)
    raise SystemExit(0 if result.wasSuccessful() else 1)


async def async_main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(
        description="IO Database Guardian WebSocket Client"
    )
    parser.add_argument(
        "--action",
        type=str,
        required=True,
        choices=["drain", "undrain", "ping"],
        help="Action to send to guardian servers",
    )
    parser.add_argument(
        "--hosts",
        type=str,
        required=True,
        help="Comma-separated list of hostnames to connect to",
    )
    parser.add_argument(
        "--port",
        type=int,
        default=int(os.environ.get("GUARDIAN_PORT", "9876")),
        help="Port to connect to (default: 9876)",
    )
    parser.add_argument(
        "--psk-file",
        type=str,
        default=os.environ.get("GUARDIAN_PSK_FILE"),
        help="Path to file containing the pre-shared key",
    )
    parser.add_argument(
        "--timeout",
        type=float,
        default=float(os.environ.get("GUARDIAN_TIMEOUT", "60")),
        help="Connection timeout in seconds (default: 60)",
    )
    parser.add_argument(
        "--fail-fast",
        action="store_true",
        help="Exit with error if any host fails",
    )

    args = parser.parse_args(argv)

    if not args.psk_file:
        logger.error(
            "PSK file must be specified via --psk-file or GUARDIAN_PSK_FILE env var"
        )
        return 1

    psk = load_psk(args.psk_file)
    hosts = [host.strip() for host in args.hosts.split(",") if host.strip()]
    if not hosts:
        logger.error("No hosts specified")
        return 1

    logger.info(f"Sending '{args.action}' to {len(hosts)} host(s): {', '.join(hosts)}")

    results = await send_to_all_hosts(hosts, args.port, psk, args.action, args.timeout)

    successful = [host for host, (ok, _) in results.items() if ok]
    failed = [host for host, (ok, _) in results.items() if not ok]

    logger.info(f"Results: {len(successful)} succeeded, {len(failed)} failed")

    if successful:
        logger.info(f"  Successful: {', '.join(successful)}")
    if failed:
        logger.warning(f"  Failed: {', '.join(failed)}")

    if args.fail_fast and failed:
        return 1

    return 0


def main(argv: list[str] | None = None) -> int:
    argv = list(sys.argv[1:] if argv is None else argv)
    if len(argv) == 1 and argv[0] in {"test", "--test"}:
        run_tests()
    return asyncio.run(async_main(argv))


if __name__ == "__main__":
    raise SystemExit(main())
