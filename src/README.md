# clawforge — autonomous AI project-manager agent (a "Claw Agent")

A heartbeat-driven agent that runs a software team's GitHub without being prompted.
Each cycle it **senses** open issues/PRs, **reasons** with a self-hosted model
(any OpenAI-compatible endpoint — today NVIDIA Nemotron-3-Nano-4B via Ollama on a
DGX Spark; vLLM validated and drop-in), and **acts** — triaging issues,
(optionally) posting a standup, and dispatching coding sub-agents. State persists
across restarts.

## The three Claw pillars (all demonstrated)
- **Proactively autonomous** — acts (labels/triage) every cycle with no human message.
- **Heartbeat-driven** — wakes on an interval (time/state), not a prompt.
- **Persistent with context** — a JSON ledger survives restarts; no work is redone.

## Architecture
```
loop.py        heartbeat: warmup -> [sense -> decide -> act -> persist] -> sleep
  sense.py     read open issues/PRs via `gh` (GitHub = tracker of record)
  decide.py    prompt the model -> validated triage decisions + reasoning trace
  client.py    swappable OpenAI-compatible client (vLLM / NemoClaw / any endpoint)
  act.py       apply labels (idempotent), post standup, ledger-guarded
  ledger.py    persistent acted-on store + cycle counter
  discord.py   optional standup post (skipped without a bot token)
```
The **brain** is any OpenAI-compatible endpoint — the live setup is NVIDIA
Nemotron-3-Nano-4B via Ollama on a DGX Spark (tunnel on `127.0.0.1:11434`, see
`src/.env`); vLLM was validated on the same GB10 (`../vllm-test/`) and drops in.
Switching models is one env var (`CLAWFORGE_MODEL_BASE_URL`).

## Quick start
```bash
# 1. Point at a model endpoint (defaults come from src/.env — the Spark's
#    Ollama tunnel; any OpenAI-compatible /v1 endpoint works)
export CLAWFORGE_MODEL_BASE_URL=http://127.0.0.1:11434/v1
export CLAWFORGE_MODEL=nemotron-claw
export GITHUB_TOKEN=$(gh auth token)          # GitHub auth for actions

# 2. Run one cycle (safe: --dry-run reasons but applies nothing)
cd src && PYTHONPATH=. python3 -m clawforge --once --dry-run

# 3. Run the live heartbeat (applies triage labels)
PYTHONPATH=. python3 -m clawforge --interval 60
```
Requires Python 3.10+, `requests`, and the `gh` CLI authenticated.

## Reproduce the demo
```bash
gh issue create --repo <owner>/<repo> --title "Add a --version flag" --body "well scoped"
PYTHONPATH=. python3 -m clawforge --once     # watch it label the issue autonomously
cat .generated/clawforge/latest-cycle.md      # standup + decisions + reasoning trace
cat .generated/clawforge/ledger.json          # persisted state (survives restart)
```

## Config (env)
| Var | Default | Meaning |
|-----|---------|---------|
| `CLAWFORGE_MODEL_BASE_URL` | `http://localhost:8001/v1` | OpenAI-compatible endpoint |
| `CLAWFORGE_MODEL` | `clawforge-brain` | served model name |
| `CLAWFORGE_REPO` | `clawforge` | watched repo (owner from `CLAWFORGE_OWNER`) |
| `CLAWFORGE_WORK_REPO` | `tickytalky` | dispatch target repo |
| `CLAWFORGE_INTERVAL` | `60` | seconds between cycles (see [Heartbeat interval](#heartbeat-interval)) |
| `CLAWFORGE_DRY_RUN` | `0` | `1` = reason only, no writes |
| `DISCORD_BOT_TOKEN` / `CLAWFORGE_DISCORD_CHANNEL` | unset | optional standup post |

## Heartbeat interval
Clawforge is **heartbeat-driven**: it wakes on a fixed interval and runs one
sense -> decide -> act cycle each time, rather than waiting for a prompt. That
interval is the beat of the agent, controlled by `CLAWFORGE_INTERVAL`.

- **Default:** `60` seconds between the end of one cycle and the start of the next.
- **Set it via env:** `export CLAWFORGE_INTERVAL=120` (cycles every 2 minutes).
- **Set it via CLI:** `python3 -m clawforge --interval 120`. The flag simply
  exports `CLAWFORGE_INTERVAL` before config is read, so the CLI value wins over
  a value already in the environment or `.env`.
- **Units:** whole seconds (integer). Smaller = more responsive but more model
  calls and GitHub API traffic; larger = cheaper and calmer.

```bash
# Heartbeat every 30s (live, applies triage labels)
PYTHONPATH=. python3 -m clawforge --interval 30
```

The interval only governs the **gap between cycles** in a continuous run. To run a
single cycle and exit immediately (ignoring the interval entirely — useful for
cron, CI, or the demo), pass `--once`:

```bash
PYTHONPATH=. python3 -m clawforge --once          # one cycle, no sleep
```

You can also cap a continuous run to a fixed number of cycles with
`CLAWFORGE_MAX_CYCLES` (`0` = run forever, the default).

## Known limitations
- Triage quality tracks model size; the small dev model (Qwen2.5-1.5B) occasionally
  mislabels nuance (e.g. "blocked" vs "ready"). Swap to a larger model / DeepSeek via
  one env var. The pipeline is model-agnostic.
- Coder-dispatch (issue -> PR on the work repo) is the stretch phase.
- The endpoint must be reachable (local tunnel to the Spark).
