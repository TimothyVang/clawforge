#!/usr/bin/env bash
# Serve DeepSeek-V4-Flash via the prebuilt vLLM-Moet GB10 image. Binds 127.0.0.1:8010.
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; MODELS="$DIR/models"
[ -d "$MODELS/DeepSeek-V4-Flash" ] || { echo "checkpoint missing — run ./download.sh"; exit 1; }
[ -f "$MODELS/ds4-planes.moet2pf" ] || { echo "plane file missing — run ./download.sh"; exit 1; }
docker rm -f vllm-moet >/dev/null 2>&1 || true
docker run -d --name vllm-moet --restart unless-stopped --gpus all --network host --ipc host --shm-size 64g \
  -v "$MODELS/DeepSeek-V4-Flash:/workspace/models/DeepSeek-V4-Flash:ro" \
  -v "$MODELS/ds4-planes.moet2pf:/workspace/models/ds4-planes.moet2pf:ro" \
  vllm-moet-gb10:v024
echo "serving on 127.0.0.1:8010 (guarded boot needs >=104 GiB free). Watch: docker logs -f vllm-moet"
