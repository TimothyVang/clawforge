# Clawforge — Submission

**Track:** Recursive Intelligence · **Bounties:** vLLM validated on GB10, not the live brain today (+ NemoClaw, see status)
**Repo:** https://github.com/TimothyVang/clawforge (public)

## Write-up (≈220 words)

**Problem.** Small teams drown in project-management glue: triaging issues,
chasing stale work, writing standups, and turning "ready" tickets into code. It's
constant, low-leverage, and never done on time.

**Who it helps.** Any small engineering team (like ours, building *tickytalky*)
that wants an always-on teammate handling the PM busywork on GitHub.

**Solution.** Clawforge is a **Claw Agent** — a heartbeat-driven autonomous project
manager. On every cycle, with no human prompt, it **senses** open issues/PRs,
**reasons** with a self-hosted LLM, and **acts**: it triages and labels issues,
writes a standup, and — for issues it judges ready — **dispatches a coding step
that opens a real pull request**. State persists in a ledger, so it survives
restarts and never repeats work. Model failures become a logged recovery event,
not a crash.

**What's non-obvious.** The brain is **self-hosted on an NVIDIA DGX Spark (GB10
Blackwell)** — today NVIDIA's own Nemotron-3-Nano-4B (Q4_K_M) served via Ollama on
the Spark, reached over an ssh tunnel. We separately validated **vLLM 0.14 on the
GB10** (`vllm-test/`), and the whole agent reasons through one swappable
OpenAI-compatible seam, so switching the brain (Ollama → vLLM → DeepSeek) is a
one-line env change.

**Impact.** A team wakes up to a triaged backlog, a standup, and draft PRs waiting
for review — work that happened autonomously overnight.

## Verified evidence (each line labeled for what it shows)
- Live brain: `clawforge.log` start lines show `model=nemotron-claw
  base_url=http://127.0.0.1:11434/v1` — Nemotron on the Spark's Ollama via tunnel.
- Separate validation (not the agent's live path): vLLM 0.14 on the DGX Spark
  GB10, ~57 tok/s (`vllm-test/`).
- Autonomous triage (live): cycle 294 triaged 3 fresh `tickytalky` issues in one
  cycle (`untriaged=3 applied=3`, model latency 3.01s, Discord posted).
- Full delegation (live, n=2): clawforge opened **davidbramante/tickytalky#2**
  (README) and **tickytalky#8** (CONTRIBUTING.md, cycle 295) — real PRs, never
  auto-merged.
- Persistence: ledger at 295+ lifetime heartbeat cycles across many process
  restarts; zero repeated actions. (Most heartbeats are idle-by-design — the model
  is only called when there is untriaged work; idle cycles log `latency=0.0s`.)
- Failure recovery (controlled fault test, not organic): a deliberately dead
  endpoint produced `MODEL FAILURE (recovering)` and the next cycle recovered.

## Demo runbook (for the Loom — show the loop live)
```bash
# The brain endpoint comes from src/.env (auto-loaded): the Spark's Ollama tunnel
# on 127.0.0.1:11434 (systemd user unit clawforge-ollama.service keeps it up).
export GITHUB_TOKEN=$(gh auth token)
# fresh input, then watch the autonomous cycle
gh issue create --repo davidbramante/tickytalky --title "Add a --help example" --body "well scoped"
cd projects/clawforge/src && PYTHONPATH=. CLAWFORGE_DISPATCH=1 python3 -m clawforge --once
cat ../.generated/clawforge/latest-cycle.md   # standup + decisions + reasoning trace
cat ../.generated/clawforge/latest-cycle.json # same record, machine-readable
```
No Spark? Point `CLAWFORGE_MODEL_BASE_URL` at any OpenAI-compatible
`/v1/chat/completions` endpoint (OpenAI, a local Ollama, vLLM anywhere) — the
agent is endpoint-agnostic by design; judges can reproduce the loop without our
hardware.

## Sponsor tech — honest status
- **DGX Spark (confirmed, load-bearing):** the agent's live brain runs on the
  Spark — NVIDIA Nemotron-3-Nano-4B via Ollama, over the `clawforge-ollama`
  tunnel. The agent does not reason without it (or a substitute endpoint).
- **vLLM (validated on GB10, drop-in, not the live path today):** vLLM 0.14
  brought up on the Spark (~57 tok/s, `vllm-test/`); switching the brain to it is
  one env var (`CLAWFORGE_MODEL_BASE_URL`). We do not claim the live agent is
  currently vLLM-served.
- **NemoClaw (architected, not yet wired live):** the swappable client can route to
  a NemoClaw-managed endpoint via `base_url` (NemoClaw is a model-agnostic sandbox/
  router). A live NemoClaw sandbox is the remaining stretch; we do **not** claim it
  runs yet.
- **DeepSeek-V4-Flash headline (stretch):** vLLM-Moet GB10 build to serve the 159B
  MoE model; the small model is the working stand-in, swappable in one env var.

## Still needed for final submission (human)
- Record the 2–5 min **Loom** using the runbook above (show the loop live).
- Submit the project form on the hackathon Notion page before **Sun 11:00 AM CST**.
- Optional: bring DeepSeek-V4-Flash up on the Spark; wire the live NemoClaw sandbox.
