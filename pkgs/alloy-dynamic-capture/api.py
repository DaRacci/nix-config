#!/usr/bin/env python3

import argparse
import json
import ssl
import subprocess
from http.server import BaseHTTPRequestHandler, HTTPServer


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--listen-address", required=True)
    parser.add_argument("--port", required=True, type=int)

    parser.add_argument("--default-ttl", required=True, type=int)
    parser.add_argument("--max-ttl", required=True, type=int)

    parser.add_argument("--ctl", required=True)
    parser.add_argument("--ctl-state-file", required=True)
    parser.add_argument("--ctl-never-match-regex", required=True)
    parser.add_argument("--ctl-default-ttl", required=True, type=int)
    parser.add_argument("--ctl-max-ttl", required=True, type=int)

    parser.add_argument("--ca-cert", required=True)
    parser.add_argument("--server-cert", required=True)
    parser.add_argument("--server-key", required=True)
    parser.add_argument("--allowed-cn", action="append", default=[])

    return parser.parse_args()


args = parse_args()
allowed_cns = set(args.allowed_cn)


def peer_common_name(cert):
    if not cert:
        return None

    for rdn in cert.get("subject", []):
        for key, value in rdn:
            if key == "commonName":
                return value

    return None


def run_ctl(*subcommand):
    command = [
        args.ctl,
        "--state-file",
        args.ctl_state_file,
        "--never-match-regex",
        args.ctl_never_match_regex,
        "--default-ttl",
        str(args.ctl_default_ttl),
        "--max-ttl",
        str(args.ctl_max_ttl),
    ]
    command.extend(subcommand)

    proc = subprocess.run(command, capture_output=True, text=True, check=False)

    if proc.returncode != 0:
        return False, proc.stderr.strip() or proc.stdout.strip() or "command failed"

    out = proc.stdout.strip()

    if not out:
        return True, {}

    try:
        return True, json.loads(out)
    except json.JSONDecodeError:
        return True, {"raw": out}


class Handler(BaseHTTPRequestHandler):
    def _write_json(self, code, payload):
        body = json.dumps(payload).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _authorize(self):
        if not allowed_cns:
            return True, None

        cert = self.connection.getpeercert()
        cn = peer_common_name(cert)

        if cn in allowed_cns:
            return True, cn

        return False, cn

    def do_GET(self):
        ok, cn = self._authorize()
        if not ok:
            self._write_json(
                403, {"error": "unauthorised client certificate", "cn": cn}
            )
            return

        if self.path != "/status":
            self._write_json(404, {"error": "not found"})
            return

        success, result = run_ctl("status")
        if not success:
            self._write_json(500, {"error": result})
            return

        self._write_json(200, result)

    def do_POST(self):
        ok, cn = self._authorize()
        if not ok:
            self._write_json(
                403, {"error": "unauthorised client certificate", "cn": cn}
            )
            return

        if self.path != "/capture":
            self._write_json(404, {"error": "not found"})
            return

        length = int(self.headers.get("Content-Length", "0"))
        raw = self.rfile.read(length) if length > 0 else b"{}"

        try:
            payload = json.loads(raw.decode("utf-8"))
        except (UnicodeDecodeError, json.JSONDecodeError):
            self._write_json(400, {"error": "invalid JSON payload"})
            return

        action = payload.get("action")
        if action is None and "enabled" in payload:
            action = (
                "enable_extra_capture"
                if payload.get("enabled")
                else "disable_extra_capture"
            )

        if action not in {"enable_extra_capture", "disable_extra_capture", "status"}:
            self._write_json(
                400,
                {
                    "error": "action must be one of: enable_extra_capture, disable_extra_capture, status"
                },
            )
            return

        if action == "status":
            success, result = run_ctl("status")
            if not success:
                self._write_json(500, {"error": result})
                return

            self._write_json(200, result)
            return

        if action == "disable_extra_capture":
            success, result = run_ctl("disable")
            if not success:
                self._write_json(500, {"error": result})
                return

            self._write_json(200, result)
            return

        ttl = payload.get("ttl_seconds", args.default_ttl)

        try:
            ttl = int(ttl)
        except (TypeError, ValueError):
            self._write_json(400, {"error": "ttl_seconds must be an integer"})
            return

        if ttl < 1 or ttl > args.max_ttl:
            self._write_json(
                400,
                {"error": f"ttl_seconds must be between 1 and {args.max_ttl}"},
            )
            return

        success, result = run_ctl("enable", str(ttl))
        if not success:
            self._write_json(500, {"error": result})
            return

        self._write_json(200, result)

    def log_message(self, format, *args):
        super().log_message(format, *args)


def main():
    server = HTTPServer((args.listen_address, args.port), Handler)

    context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    context.minimum_version = ssl.TLSVersion.TLSv1_2
    context.verify_mode = ssl.CERT_REQUIRED
    context.load_cert_chain(certfile=args.server_cert, keyfile=args.server_key)
    context.load_verify_locations(cafile=args.ca_cert)

    server.socket = context.wrap_socket(server.socket, server_side=True)
    server.serve_forever()


if __name__ == "__main__":
    main()
