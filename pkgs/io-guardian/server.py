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
import subprocess
import sys
from pathlib import Path

import websockets
from websockets.server import serve

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)
logger = logging.getLogger(__name__)

authenticated_clients: set = set()


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


def run_systemctl(action: str, unit: str) -> tuple[bool, str]:
    """Run a systemctl command and return success status and message."""
    try:
        result = subprocess.run(
            ["systemctl", "--wait", action, unit],
            capture_output=True,
            text=True,
            timeout=30,
        )
        if result.returncode == 0:
            return True, f"Successfully ran: systemctl {action} {unit}"
        else:
            return False, f"Failed: {result.stderr.strip() or result.stdout.strip()}"
    except subprocess.TimeoutExpired:
        return False, f"Timeout running: systemctl {action} {unit}"
    except Exception as e:
        return False, f"Error running systemctl: {e}"


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
    client_id = f"{websocket.remote_address[0]}:{websocket.remote_address[1]}"
    logger.info(f"New connection from {client_id}")

    is_authenticated = False

    try:
        async for raw_message in websocket:
            try:
                message = json.loads(raw_message)
            except json.JSONDecodeError:
                await websocket.send(
                    json.dumps({"type": "error", "message": "Invalid JSON"})
                )
                continue

            msg_type = message.get("type")

            # Handle authentication
            if msg_type == "auth":
                provided_key = message.get("key", "")
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

                if action == "drain":
                    success, msg = handle_drain()
                    await websocket.send(
                        json.dumps(
                            {
                                "type": "response",
                                "action": "drain",
                                "status": "ok" if success else "error",
                                "message": msg,
                            }
                        )
                    )

                elif action == "undrain":
                    success, msg = handle_undrain()
                    await websocket.send(
                        json.dumps(
                            {
                                "type": "response",
                                "action": "undrain",
                                "status": "ok" if success else "error",
                                "message": msg,
                            }
                        )
                    )

                elif action == "ping":
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
    except Exception as e:
        logger.error(f"Error handling client {client_id}: {e}")
    finally:
        authenticated_clients.discard(client_id)


async def main():
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

    args = parser.parse_args()

    if not args.psk_file:
        logger.error(
            "PSK file must be specified via --psk-file or GUARDIAN_PSK_FILE env var"
        )
        sys.exit(1)

    psk = load_psk(args.psk_file)
    logger.info(f"Loaded PSK from {args.psk_file}")

    async def handler(websocket):
        await handle_client(websocket, psk)

    logger.info(f"Starting IO Guardian server on {args.host}:{args.port}")

    async with serve(handler, args.host, args.port):
        await asyncio.Future()  # Run forever


if __name__ == "__main__":
    asyncio.run(main())
