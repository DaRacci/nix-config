import socket
from http.server import HTTPServer


def make_server(address: str, port: int, handler: type) -> HTTPServer:
    if ":" not in address:
        return HTTPServer((address, port), handler)

    class IPv6HTTPServer(HTTPServer):
        address_family = socket.AF_INET6

        def server_bind(self) -> None:
            self.socket.setsockopt(socket.IPPROTO_IPV6, socket.IPV6_V6ONLY, 0)
            super().server_bind()

    return IPv6HTTPServer((address, port), handler)
