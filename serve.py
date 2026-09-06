#!/usr/bin/env python3
"""
Ledgerly's local static file server.

Plain `python3 -m http.server` lets the browser cache CSS and JS aggressively,
which means edits to your own copy of the app may not show up until you clear
the cache. This subclass adds no-store headers so a reload always shows the
current files.

It binds to 127.0.0.1 only: nothing else on your network can reach it. It
serves the app's HTML/CSS/JS and nothing else -- your ledger never passes
through it, because it lives in the browser's IndexedDB on this device.
"""
import http.server, socketserver, sys, os

PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 4173
os.chdir(os.path.dirname(os.path.abspath(__file__)))


class Handler(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header("Cache-Control", "no-store, must-revalidate")
        # This app never needs to be framed or sniffed.
        self.send_header("X-Content-Type-Options", "nosniff")
        self.send_header("X-Frame-Options", "DENY")
        self.send_header("Referrer-Policy", "no-referrer")
        super().end_headers()

    def log_message(self, fmt, *args):
        # Log only the request line, never query strings or anything else.
        sys.stderr.write("  %s\n" % (args[0] if args else ""))


class Server(socketserver.TCPServer):
    allow_reuse_address = True


with Server(("127.0.0.1", PORT), Handler) as httpd:
    httpd.serve_forever()
