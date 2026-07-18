#!/usr/bin/env bash
# Rsync this folder to the Spark and bring the vLLM container up.
# Usage: SPARK_HOST=spark ./scripts/deploy-to-spark.sh
#   SPARK_HOST  ssh alias/host (default: spark ; use spark-ts for Tailscale)
#   SPARK_DIR   remote dir (default: ~/vllm-test)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SPARK_HOST="${SPARK_HOST:-spark}"
SPARK_DIR="${SPARK_DIR:-vllm-test}"   # relative to remote $HOME

echo "==> target: $SPARK_HOST:$SPARK_DIR"
# Preflight: is the Spark reachable?
if ! timeout 12 ssh -o BatchMode=yes -o ConnectTimeout=8 "$SPARK_HOST" 'echo ok' >/dev/null 2>&1; then
  echo "ERROR: cannot reach $SPARK_HOST over ssh. Check Tailscale/LAN and try SPARK_HOST=spark-ts." >&2
  exit 1
fi

echo "==> rsync (excluding .env and git/state)"
rsync -az --delete \
  --exclude '.env' --exclude '.git' --exclude '*.log' \
  "$ROOT/" "$SPARK_HOST:$SPARK_DIR/"

# If the remote has no .env, seed it from the example so the operator can fill it.
ssh "$SPARK_HOST" "cd $SPARK_DIR && [ -f .env ] || { cp .env.example .env; echo 'NOTE: created .env from example on the Spark — fill VLLM_IMAGE/MODEL before up'; }"

echo "==> docker compose up -d"
ssh "$SPARK_HOST" "cd $SPARK_DIR && docker compose --env-file .env up -d && docker compose ps"

echo "==> done. Tail logs:  ssh $SPARK_HOST 'cd $SPARK_DIR && docker compose logs -f vllm'"
