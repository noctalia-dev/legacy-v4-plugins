#!/usr/bin/env sh
# Run the Hermes bridge on a server so a remote Noctalia client (client-only mode)
# can drive it over an SSH tunnel.
#
# Usage:
#   ./hermes-bridge-serve.sh [port]        # default port 19777
#
# The bridge binds to 127.0.0.1 only. Reach it from the client with an SSH tunnel:
#   ssh -L <port>:127.0.0.1:<port> <user>@<server>
# then in the plugin: enable "Client-only mode", host 127.0.0.1, port <port>,
# and paste the token printed below.
set -eu

PORT="${1:-19777}"
DIR="$(cd "$(dirname "$0")" && pwd)"
TOKEN_FILE="${XDG_CACHE_HOME:-$HOME/.cache}/noctalia-hermes/bridge.token"

# Start fresh so the token printed matches the running bridge.
rm -f "$TOKEN_FILE" 2>/dev/null || true

echo "Starting Hermes bridge on 127.0.0.1:$PORT ..."
trap 'kill "$BRIDGE_PID" 2>/dev/null || true' INT TERM EXIT
python3 "$DIR/hermes_bridge.py" --host 127.0.0.1 --port "$PORT" &
BRIDGE_PID=$!

# Wait for the bridge to generate its token.
i=0
while [ ! -f "$TOKEN_FILE" ] && [ "$i" -lt 100 ]; do
  if ! kill -0 "$BRIDGE_PID" 2>/dev/null; then
    echo "Error: Bridge process $BRIDGE_PID exited during startup." >&2
    exit 1
  fi
  sleep 0.1
  i=$((i + 1))
done

echo
echo "Bridge PID : $BRIDGE_PID"
echo "Port       : $PORT"
if [ -f "$TOKEN_FILE" ]; then
  echo "Token      : $(cat "$TOKEN_FILE")"
else
  echo "Token      : (not generated yet — check $TOKEN_FILE)"
fi
echo
echo "On the client run:"
echo "  ssh -L $PORT:127.0.0.1:$PORT <user>@<server>"
echo
echo "Press Ctrl+C to stop the bridge."
wait "$BRIDGE_PID"
