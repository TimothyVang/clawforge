#!/usr/bin/env bash
# Open a persistent local->Spark tunnel so the clawforge app (on the dev box) can
# reach the vLLM endpoint at http://localhost:PORT/v1.
# The Spark is only reachable via the guac jump (baked into the `spark` ssh alias).
# Usage: ./scripts/tunnel.sh [PORT]   (default 8001)
set -euo pipefail
PORT="${1:-8001}"
SPARK_HOST="${SPARK_HOST:-spark}"

pkill -f "ssh.*${PORT}:localhost:${PORT}.* ${SPARK_HOST}" 2>/dev/null || true
echo "==> tunneling localhost:${PORT} -> ${SPARK_HOST}:localhost:${PORT} (via guac)"
exec ssh -N \
  -o ExitOnForwardFailure=yes -o ServerAliveInterval=30 -o ServerAliveCountMax=3 \
  -L "${PORT}:localhost:${PORT}" "${SPARK_HOST}"
# Then: export CLAWFORGE_MODEL_BASE_URL=http://localhost:${PORT}/v1
