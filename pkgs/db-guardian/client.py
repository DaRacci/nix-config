#!/usr/bin/env python3
"""
Database Guardian - WebSocket Client

This client runs on the database primary host and connects to guardian
servers running on client machines to send drain/undrain commands.

Usage:
    db-guardian-client --action drain --hosts nixai,nixdev,nixcloud
    db-guardian-client --action undrain --hosts nixai,nixdev,nixcloud

Connections are mutually authenticated TLS: the guardian is verified against the
DB Guardian intermediate CA and the client presents the coordinator certificate.
"""

from __future__ import annotations

import argparse
import asyncio
import json
import logging
import os
import ssl
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

import websockets

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)
logger = logging.getLogger(__name__)


class ProtocolError(ValueError):
    """Raised when the server responds with an invalid protocol payload."""


def create_client_context(
    ca_cert: str, client_cert: str, client_key: str
) -> ssl.SSLContext:
    """Build the coordinator mTLS context, verifying the guardian against the guardian CA."""
    context = ssl.create_default_context(cafile=ca_cert)
    context.load_cert_chain(certfile=client_cert, keyfile=client_key)
    return context


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
    host: str, port: int, context: ssl.SSLContext, action: str, timeout: float
) -> tuple[bool, str]:
    """Send a command to a single guardian server."""
    uri = f"wss://{host}:{port}"
    logger.info(f"Connecting to {uri}...")

    try:
        async with asyncio.timeout(timeout):
            async with websockets.connect(uri, ssl=context) as websocket:
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

    except TimeoutError:
        logger.error(f"[{host}] Connection timed out after {timeout}s")
        return False, f"Connection timed out after {timeout}s"
    except ConnectionRefusedError:
        logger.warning(f"[{host}] Connection refused (server may not be running)")
        return False, "Connection refused"
    except ssl.SSLCertVerificationError as exc:
        logger.error(f"[{host}] Certificate verification failed: {exc}")
        return False, f"Certificate verification failed: {exc}"
    except ssl.SSLError as exc:
        logger.error(f"[{host}] TLS error: {exc}")
        return False, f"TLS error: {exc}"
    except OSError as exc:
        logger.warning(f"[{host}] Network error: {exc}")
        return False, f"Network error: {exc}"
    except (ProtocolError, websockets.exceptions.WebSocketException) as exc:
        logger.error(f"[{host}] Communication error: {exc}")
        return False, f"Communication error: {exc}"


async def send_to_all_hosts(
    hosts: list[str],
    port: int,
    context: ssl.SSLContext,
    action: str,
    timeout: float,
) -> dict[str, tuple[bool, str]]:
    """Send a command to all hosts concurrently."""
    tasks = [send_command(host, port, context, action, timeout) for host in hosts]
    results = await asyncio.gather(*tasks)
    return dict(zip(hosts, results, strict=True))


# Throwaway CA certificate with no private key, used only to exercise context building.
TEST_CA_PEM = """-----BEGIN CERTIFICATE-----
MIIDQDCCAiigAwIBAgIUJOy2j+KorV/AWYyS9FSsvu+mHzkwDQYJKoZIhvcNAQEL
BQAwJjEkMCIGA1UEAwwbREIgR3VhcmRpYW4gdGVzdCBmaXh0dXJlIENBMB4XDTI2
MTAzMTExNTA0N1oXDTM2MTAyODExNTA0N1owJjEkMCIGA1UEAwwbREIgR3VhcmRp
YW4gdGVzdCBmaXh0dXJlIENBMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKC
AQEA3OfLADpRKyahlYX0Y+3BjRmz5dxAoM4zAvpY0bcAMo9pPFXx1IcfC3U9Cz0j
qEK1CJd5rmaCRCdoKXLSgVo46z5okP8pvliwNKae+9afoua65lnA2ipoyKz4c5T9
b24VguuUeLMwHzfunNifBh5SWJnrsfR9PIeE+zuIM268VSzZJ6YMYJQpG53UJ5VM
tach3hgcthjf3iyM1xB5DT0j8zu2gftVaqsohYBHq56C8fBDoGn8sZMfLISZ+8oD
KMyRn73+lCblC5/6SK93YYYsiuTW9DfI0HzmyAaZfWRMhb8kUCM52btG5xIwcob5
nMBbLh3GwSVns4oD/KxqESULiQIDAQABo2YwZDAdBgNVHQ4EFgQUdYDSkDqL20ZM
bc7d72wqwMqCiqYwHwYDVR0jBBgwFoAUdYDSkDqL20ZMbc7d72wqwMqCiqYwEgYD
VR0TAQH/BAgwBgEB/wIBADAOBgNVHQ8BAf8EBAMCAQYwDQYJKoZIhvcNAQELBQAD
ggEBAEiTxbrkKlZkQOYQ0Hiz4Ubpav6y9SHSKRBDgw7ZLO/nJk8kM06rx48pI0F9
Uz3URUFUNFcctHEi4EwlySsZQZ7TTHeYwpjKTxp2EH+MBDUbnZNDMm3+zUHOe9+Q
mKrG5FS6kQkyee9zRppN1rKiibK617Yz+OuneH3QzUUvuguBVGN/dJSUqnf9xp1V
4u4OJH/0h6DTQ4K6XCqmrxrctm7jJ+hylAmA6IiyUstvgSFoNPcTmwwI0yUZyeMc
9gRup8JEUsz+uAHeej96B7JO6IFjt/Jbva2rW24yS8URZ0lfGz2hRj1aQE35Fj+5
uk8OEzAmYu95p883jCzP0nxahys=
-----END CERTIFICATE-----
"""


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
                decode_server_message("[]", "response")

        def test_decode_server_message_rejects_wrong_type(self) -> None:
            with self.assertRaisesRegex(ProtocolError, "Expected response type"):
                decode_server_message('{"type": "error"}', "response")

        def test_client_context_requires_certificate_verification(self) -> None:
            with tempfile.TemporaryDirectory() as directory:
                ca_cert = Path(directory) / "ca.pem"
                ca_cert.write_text(TEST_CA_PEM, encoding="ascii")
                client_cert = Path(directory) / "client.pem"
                client_key = Path(directory) / "client.key"
                context = mock.MagicMock(spec=ssl.SSLContext)

                with (
                    mock.patch.object(
                        ssl, "create_default_context", return_value=context
                    ) as create_default_context,
                    mock.patch.object(context, "load_cert_chain") as load_cert_chain,
                ):
                    created = create_client_context(
                        str(ca_cert), str(client_cert), str(client_key)
                    )

            self.assertIs(created, context)
            create_default_context.assert_called_once_with(cafile=str(ca_cert))
            load_cert_chain.assert_called_once_with(
                certfile=str(client_cert), keyfile=str(client_key)
            )

        def test_verification_cannot_be_disabled(self) -> None:
            with tempfile.TemporaryDirectory() as directory:
                ca_cert = Path(directory) / "ca.pem"
                ca_cert.write_text(TEST_CA_PEM, encoding="ascii")

                with mock.patch.object(ssl.SSLContext, "load_cert_chain"):
                    context = create_client_context(
                        str(ca_cert), "client.pem", "client.key"
                    )

            self.assertEqual(context.verify_mode, ssl.CERT_REQUIRED)
            self.assertIs(context.check_hostname, True)
            self.assertEqual(context.minimum_version, ssl.TLSVersion.TLSv1_2)

        def test_certificate_verification_failure_is_reported_separately(self) -> None:
            error = ssl.SSLCertVerificationError(
                1, "certificate verify failed: Hostname mismatch"
            )
            connection = mock.AsyncMock()
            connection.__aenter__.side_effect = error

            with mock.patch.object(websockets, "connect", return_value=connection):
                ok, message = asyncio.run(
                    send_command("nixcloud", 9876, ssl.SSLContext(), "drain", 5)
                )

            self.assertFalse(ok)
            self.assertIn("Certificate verification failed", message)

    suite = unittest.defaultTestLoader.loadTestsFromTestCase(GuardianClientTests)
    result = unittest.TextTestRunner(verbosity=2).run(suite)
    raise SystemExit(0 if result.wasSuccessful() else 1)


async def async_main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description="Database Guardian WebSocket Client")
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
        "--ca-cert",
        type=str,
        required=True,
        help="Path to the PEM certificate of the DB Guardian intermediate CA",
    )
    parser.add_argument(
        "--client-cert",
        type=str,
        required=True,
        help="Path to the PEM client certificate chain (leaf followed by intermediate)",
    )
    parser.add_argument(
        "--client-key",
        type=str,
        required=True,
        help="Path to the PEM client private key",
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

    hosts = [host.strip() for host in args.hosts.split(",") if host.strip()]
    if not hosts:
        logger.error("No hosts specified")
        return 1

    context = create_client_context(args.ca_cert, args.client_cert, args.client_key)

    logger.info(f"Sending '{args.action}' to {len(hosts)} host(s): {', '.join(hosts)}")

    results = await send_to_all_hosts(
        hosts, args.port, context, args.action, args.timeout
    )

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
