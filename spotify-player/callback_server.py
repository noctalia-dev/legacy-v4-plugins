import sys
from http.server import HTTPServer, BaseHTTPRequestHandler
from urllib.parse import urlparse, parse_qs

port = int(sys.argv[1])

class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        code = parse_qs(urlparse(self.path).query).get("code", [None])[0]
        state = parse_qs(urlparse(self.path).query).get("state", [None])[0]
        error = parse_qs(urlparse(self.path).query).get("error", [None])[0]
        self.send_response(200)
        self.end_headers()
        self.wfile.write(b"You can close this tab now.")
        print(f"{code}:{state}:{error}", flush=True)
        sys.exit(0)
    def log_message(self, *args): pass

HTTPServer(("localhost", port), Handler).serve_forever()