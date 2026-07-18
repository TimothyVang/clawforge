#!/usr/bin/env bash
# Smoke-test the vLLM OpenAI endpoint.
# Usage: ./scripts/test-endpoint.sh [BASE_URL]
#   BASE_URL default: http://localhost:8001  (Spark Tailscale IP + PORT)
#   MODEL env: served-model-name (default clawforge-brain)
set -euo pipefail

BASE="${1:-http://localhost:8001}"
MODEL="${MODEL:-clawforge-brain}"

echo "==> GET $BASE/v1/models"
if ! curl -sf --max-time 8 "$BASE/v1/models"; then
  echo; echo "ERROR: endpoint not reachable at $BASE (is the container up + tailnet-exposed?)" >&2
  exit 1
fi
echo; echo

echo "==> POST $BASE/v1/chat/completions (model=$MODEL)"
curl -sf --max-time 60 "$BASE/v1/chat/completions" \
  -H 'Content-Type: application/json' \
  -d "{\"model\":\"$MODEL\",\"messages\":[{\"role\":\"user\",\"content\":\"Reply with exactly: ok\"}],\"max_tokens\":16}" \
  | (command -v jq >/dev/null && jq -r '.choices[0].message.content' || cat)
echo
echo "==> if you see a reply above, CLAWFORGE_MODEL_BASE_URL=$BASE/v1 is live."
