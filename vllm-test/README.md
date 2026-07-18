# vllm-test — containerized vLLM endpoint for the DGX Spark

Self-contained, containerized **vLLM OpenAI-compatible endpoint** that becomes
clawforge's model brain. Build here, deploy to the **DGX Spark (GB10)**, expose over
Tailscale, and point the clawforge app at it via `CLAWFORGE_MODEL_BASE_URL`.

Two roles, same compose file (pick the image + model via `.env`):
- **Immediate endpoint** — a small model (e.g. 8B) on plain vLLM → dev + fallback,
  earns the **vLLM** bounty now.
- **Headline endpoint** — DeepSeek-V4-Flash via the **vLLM-Moet** GB10 image.

> ⚠️ **Hardware note (GB10 = arm64 + Blackwell SM120).** The stock
> `vllm/vllm-openai` image is x86-only. On the Spark you MUST set `VLLM_IMAGE` to an
> **arm64/GB10-capable** image — the vLLM-Moet `Dockerfile.gb10-v024` build for
> DeepSeek, or an arm64 vLLM build for a small model. This folder does not pin an
> image that is proven on GB10; confirm the image on the box first.

## Layout
```
vllm-test/
  docker-compose.yml   # the vLLM service (OpenAI API, GPU, host network)
  .env.example         # copy to .env, fill model/image/port
  scripts/
    deploy-to-spark.sh # rsync this folder to the Spark + docker compose up
    test-endpoint.sh   # curl /v1/models + a chat completion
```

## Deploy to the Spark
```bash
cp .env.example .env            # edit: VLLM_IMAGE, MODEL, PORT, MODELS_DIR
# from a machine that can reach the Spark (ssh alias `spark` / `spark-ts`):
SPARK_HOST=spark ./scripts/deploy-to-spark.sh
```
This rsyncs the folder to `~/vllm-test` on the Spark and runs `docker compose up -d`.
`.env` is NOT synced (secrets) — create it on the Spark, or the script copies
`.env.example` for you to fill there.

## Test the endpoint
```bash
# tailscale IP + port from your .env
./scripts/test-endpoint.sh http://localhost:8001
```
Expect `/v1/models` to list the served model and a chat completion to return.

## Wire into clawforge
```bash
export CLAWFORGE_MODEL_BASE_URL=http://localhost:8001/v1
export CLAWFORGE_MODEL=clawforge-brain      # = SERVED_NAME
export CLAWFORGE_MODEL_API_KEY=EMPTY        # vLLM ignores it unless --api-key set
```

## Status — CONFIRMED WORKING (2026-07-18)
- **vLLM runs on the DGX Spark GB10.** `vllm-node:latest` + vLLM 0.14 + CUDA 13.1
  serving `clawforge-brain` (Qwen2.5-1.5B) — **~57 tok/s** steady-state, coherent output.
  First request is a slow (~20s) JIT/autotune warmup; send a warmup call on startup.
- **Reachability:** the Spark's services bind LAN only and its tailnet ports don't
  route in, so reach it through a jump host. Configure a `spark` entry in your
  **local** `~/.ssh/config` (with `ProxyJump <your-jump-host>` if needed) — host
  details stay in your ssh config, NOT this public repo. Then the app uses a tunnel:
  ```bash
  ./scripts/tunnel.sh 8001      # localhost:8001 -> Spark:8001 (uses the `spark` alias)
  export CLAWFORGE_MODEL_BASE_URL=http://localhost:8001/v1
  ```
- **Next:** DeepSeek-V4-Flash via the vLLM-Moet GB10 image (headline) — swap
  `MODEL`/`VLLM_IMAGE` when built.
- Never commit Spark creds/ssh keys here; `.env` is gitignored.
