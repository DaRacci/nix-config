#!/usr/bin/env python3

import argparse
import json
import ssl
import urllib.error
import urllib.parse
import urllib.request
from http.server import BaseHTTPRequestHandler, HTTPServer


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--listen-address", required=True)
    parser.add_argument("--port", required=True, type=int)

    parser.add_argument("--default-ttl", required=True, type=int)
    parser.add_argument("--max-ttl", required=True, type=int)

    parser.add_argument("--dynamic-port", required=True, type=int)
    parser.add_argument("--dynamic-ca-cert", required=True)
    parser.add_argument("--dynamic-client-cert", required=True)
    parser.add_argument("--dynamic-client-key", required=True)

    parser.add_argument("--target", action="append", default=[])

    return parser.parse_args()


args = parse_args()
targets = set(args.target)


def parse_path(path):
    parsed = urllib.parse.urlparse(path)
    parts = [x for x in parsed.path.split("/") if x]

    if len(parts) != 3 or parts[0] != "capture":
        return None

    host = parts[1]
    action = parts[2]
    query = urllib.parse.parse_qs(parsed.query)

    return host, action, query


def relay_capture(host, action, ttl):
    payload = {"action": action}

    if action == "enable_extra_capture":
        payload["ttl_seconds"] = ttl

    context = ssl.create_default_context(cafile=args.dynamic_ca_cert)
    context.load_cert_chain(
        certfile=args.dynamic_client_cert, keyfile=args.dynamic_client_key
    )

    url = f"https://{host}:{args.dynamic_port}/capture"
    request = urllib.request.Request(
        url,
        data=json.dumps(payload).encode("utf-8"),
        method="POST",
        headers={"Content-Type": "application/json"},
    )

    with urllib.request.urlopen(request, context=context, timeout=15) as response:
        body = response.read()

    if not body:
        return {}

    return json.loads(body.decode("utf-8"))


class Handler(BaseHTTPRequestHandler):
    def _write_json(self, code, payload):
        body = json.dumps(payload).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_POST(self):
        parsed = parse_path(self.path)
        if parsed is None:
            self._write_json(404, {"error": "not found"})
            return

        host, action, query = parsed

        if host not in targets:
            self._write_json(400, {"error": f"unknown host: {host}"})
            return

        if action == "enable":
            ttl_raw = query.get("ttl", [str(args.default_ttl)])[0]

            try:
                ttl = int(ttl_raw)
            except ValueError:
                self._write_json(400, {"error": "ttl must be an integer"})
                return

            if ttl < 1 or ttl > args.max_ttl:
                self._write_json(
                    400, {"error": f"ttl must be between 1 and {args.max_ttl}"}
                )
                return

            relay_action = "enable_extra_capture"
        elif action == "disable":
            ttl = None
            relay_action = "disable_extra_capture"
        else:
            self._write_json(400, {"error": "action must be enable or disable"})
            return

        try:
            result = relay_capture(host, relay_action, ttl)
        except urllib.error.HTTPError as exc:
            body = exc.read().decode("utf-8")
            self._write_json(502, {"error": f"upstream HTTP {exc.code}", "body": body})
            return
        except urllib.error.URLError as exc:
            self._write_json(502, {"error": f"upstream request failed: {exc}"})
            return

        self._write_json(200, {"host": host, "result": result})

    def do_GET(self):
        if self.path != "/status":
            self._write_json(404, {"error": "not found"})
            return

        self._write_json(
            200,
            {
                "targets": sorted(targets),
                "default_ttl_seconds": args.default_ttl,
                "max_ttl_seconds": args.max_ttl,
            },
        )

    def log_message(self, format, *args):
        super().log_message(format, *args)


def main():
    server = HTTPServer((args.listen_address, args.port), Handler)
    server.serve_forever()


if __name__ == "__main__":
    main()
