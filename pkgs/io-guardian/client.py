#!/usr/bin/env python3
"""
IO Database Guardian - WebSocket Client

This client runs on IO Hosts (the database host) and connects to guardian
servers running on client machines to send drain/undrain commands.

Usage:
    io-guardian-client --action drain --hosts nixai,nixdev,nixcloud
    io-guardian-client --action undrain --hosts nixai,nixdev,nixcloud
"""

import argparse
import asyncio
import json
import logging
import os
import sys
from pathlib import Path

import websockets

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)
logger = logging.getLogger(__name__)


def load_psk(psk_file: str) -> str:
    """Load the pre-shared key from file."""
    path = Path(psk_file)
    if not path.exists():
        logger.error(f"PSK file not found: {psk_file}")
        sys.exit(1)

    psk = path.read_text().strip()
    if len(psk) < 32:
        logger.error("PSK must be at least 32 characters")
        sys.exit(1)

    return psk


async def send_command(
    host: str, port: int, psk: str, action: str, timeout: float
) -> tuple[bool, str]:
    """Send a command to a single guardian server."""
    uri = f"ws://{host}:{port}"
    logger.info(f"Connecting to {uri}...")

    try:
        async with asyncio.timeout(timeout):
            async with websockets.connect(uri) as websocket:
                # Authenticate
                auth_message = json.dumps({"type": "auth", "key": psk})
                await websocket.send(auth_message)

                response = await websocket.recv()
                auth_response = json.loads(response)

                if auth_response.get("status") != "ok":
                    error_msg = auth_response.get("message", "Authentication failed")
                    logger.error(f"[{host}] Authentication failed: {error_msg}")
                    return False, f"Authentication failed: {error_msg}"

                logger.info(f"[{host}] Authenticated successfully")

                # Send command
                command_message = json.dumps({"type": "command", "action": action})
                await websocket.send(command_message)

                response = await websocket.recv()
                cmd_response = json.loads(response)

                status = cmd_response.get("status")
                message = cmd_response.get("message", "")

                if status == "ok":
                    logger.info(f"[{host}] Command '{action}' succeeded: {message}")
                    return True, message
                else:
                    logger.error(f"[{host}] Command '{action}' failed: {message}")
                    return False, message

    except asyncio.TimeoutError:
        logger.error(f"[{host}] Connection timed out after {timeout}s")
        return False, f"Connection timed out after {timeout}s"
    except ConnectionRefusedError:
        logger.warning(f"[{host}] Connection refused (server may not be running)")
        return False, "Connection refused"
    except OSError as e:
        logger.warning(f"[{host}] Network error: {e}")
        return False, f"Network error: {e}"
    except Exception as e:
        logger.error(f"[{host}] Unexpected error: {e}")
        return False, f"Unexpected error: {e}"


async def send_to_all_hosts(
    hosts: list[str], port: int, psk: str, action: str, timeout: float
) -> dict[str, tuple[bool, str]]:
    """Send a command to all hosts concurrently."""
    tasks = [send_command(host, port, psk, action, timeout) for host in hosts]
    results = await asyncio.gather(*tasks)
    return dict(zip(hosts, results))


async def main():
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
        default=float(os.environ.get("GUARDIAN_TIMEOUT", "10")),
        help="Connection timeout in seconds (default: 10)",
    )
    parser.add_argument(
        "--fail-fast",
        action="store_true",
        help="Exit with error if any host fails",
    )

    args = parser.parse_args()

    if not args.psk_file:
        logger.error(
            "PSK file must be specified via --psk-file or GUARDIAN_PSK_FILE env var"
        )
        sys.exit(1)

    psk = load_psk(args.psk_file)
    hosts = [h.strip() for h in args.hosts.split(",") if h.strip()]

    if not hosts:
        logger.error("No hosts specified")
        sys.exit(1)

    logger.info(f"Sending '{args.action}' to {len(hosts)} host(s): {', '.join(hosts)}")

    results = await send_to_all_hosts(hosts, args.port, psk, args.action, args.timeout)

    # Summary
    successful = [h for h, (ok, _) in results.items() if ok]
    failed = [h for h, (ok, _) in results.items() if not ok]

    logger.info(f"Results: {len(successful)} succeeded, {len(failed)} failed")

    if successful:
        logger.info(f"  Successful: {', '.join(successful)}")
    if failed:
        logger.warning(f"  Failed: {', '.join(failed)}")

    if args.fail_fast and failed:
        sys.exit(1)

    # Exit 0 even if some hosts failed - they may just be unreachable
    sys.exit(0)


if __name__ == "__main__":
    asyncio.run(main())
