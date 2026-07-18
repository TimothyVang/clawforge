# Clawforge — Submission

**Track:** Recursive Intelligence · **Bounties:** vLLM (+ NemoClaw, see status)
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

**What's non-obvious.** The brain is **DeepSeek-class inference served by vLLM on
an NVIDIA DGX Spark (GB10 Blackwell)** — we validated vLLM runs on this new
hardware and drive the whole agent through one swappable OpenAI-compatible seam,
so the model is a one-line change.

**Impact.** A team wakes up to a triaged backlog, a standup, and draft PRs waiting
for review — work that happened autonomously overnight.

## Verified evidence (all live, not staged)
- vLLM 0.14 on the DGX Spark GB10, ~57 tok/s (`vllm-test/`).
- Autonomous triage: clawforge labeled `clawforge#6→ready`, `#7→question`, `#11→ready`.
- Full delegation: clawforge opened **davidbramante/tickytalky#2** (drafted a README).
- Persistence: ledger survived 11 cycles across separate process restarts; zero re-triage.
- Failure recovery: dead endpoint → `MODEL FAILURE (recovering)` → next cycle recovered.

## Demo runbook (for the Loom — show the loop live)
```bash
# brain up + reachable (Spark GB10)
cd projects/clawforge/vllm-test && ./scripts/tunnel.sh 8001 &
export CLAWFORGE_MODEL_BASE_URL=http://localhost:8001/v1 GITHUB_TOKEN=$(gh auth token)
# fresh input, then watch the autonomous cycle
gh issue create --repo TimothyVang/clawforge --title "Add a --help example" --body "well scoped"
cd ../src && PYTHONPATH=. CLAWFORGE_DISPATCH=1 CLAWFORGE_WORK_REPO=davidbramante/tickytalky \
  python3 -m clawforge --once
cat .generated/clawforge/latest-cycle.md   # standup + decisions + reasoning trace
```

## Sponsor tech — honest status
- **vLLM (confirmed, load-bearing):** the brain is served by vLLM on the DGX Spark;
  the agent cannot run without it. Validated vLLM on GB10 Blackwell.
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
