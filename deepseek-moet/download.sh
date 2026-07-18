#!/usr/bin/env bash
# Download DeepSeek-V4-Flash checkpoint (~149 GiB) + 2-bit plane file (72.6 GiB).
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; MODELS="$DIR/models"
export PATH="$HOME/.local/bin:$PATH" HF_HUB_ENABLE_HF_TRANSFER=1
mkdir -p "$MODELS"
echo "[1/2] checkpoint (149 GiB, 46 shards)…"
hf download deepseek-ai/DeepSeek-V4-Flash --revision 60d8d70770c6776ff598c94bb586a859a38244f1 --local-dir "$MODELS/DeepSeek-V4-Flash"
echo "[2/2] plane file (72.6 GiB)…"
hf download 9prodhi/DeepSeek-V4-Flash-moet2pf ds4-planes.moet2pf --local-dir "$MODELS"
echo "DONE. du:"; du -sh "$MODELS"/* 2>/dev/null
