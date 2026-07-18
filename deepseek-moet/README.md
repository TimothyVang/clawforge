# deepseek-moet — DeepSeek-V4-Flash on the DGX Spark (self-contained)

Serves **DeepSeek-V4-Flash (159B)** on this Spark (GB10) via 9prodhi/vLLM-Moet's
2-bit plane-file tier. The `vllm-moet-gb10:v024` image is already built.

## Steps
    ./download.sh      # ~221 GiB: 149 GiB checkpoint + 72.6 GiB plane file
    ./run.sh           # serve on 127.0.0.1:8010 (OpenAI + Anthropic APIs)
    docker logs -f vllm-moet

## Wire clawforge to it (from the dev box, via the guac tunnel)
    ssh -N -L 8010:localhost:8010 spark &
    export CLAWFORGE_MODEL_BASE_URL=http://localhost:8010/v1
    export CLAWFORGE_MODEL=deepseek-v4-flash

## Notes
- ~16.6 tok/s decode (29.8 with MTP k=2); guarded boot refuses <104 GiB free mem.
- Image is `derived-from-verified` (native path verified upstream; container boot may
  need tuning). Downloads need no HF token.
