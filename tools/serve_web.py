import http.server
import socketserver
import os
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', 'build', 'web'))
PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 8080


class Handler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=ROOT, **kwargs)

    def end_headers(self):
        # Godot Web exports that request cross-origin isolation need these.
        self.send_header('Cross-Origin-Opener-Policy', 'same-origin')
        self.send_header('Cross-Origin-Embedder-Policy', 'require-corp')
        self.send_header('Cross-Origin-Resource-Policy', 'cross-origin')
        self.send_header('Cache-Control', 'no-store')
        super().end_headers()


with socketserver.TCPServer(('127.0.0.1', PORT), Handler) as httpd:
    print(f'Serving {ROOT} at http://127.0.0.1:{PORT}/index.html')
    httpd.serve_forever()
