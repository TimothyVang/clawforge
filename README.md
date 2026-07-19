# Clawforge

**An autonomous AI project-manager agent (a "Claw Agent").** It runs on a
heartbeat: every cycle, with no human prompt, it senses GitHub issues/PRs, reasons
with a self-hosted LLM on an **NVIDIA DGX Spark GB10** (today: NVIDIA
Nemotron-3-Nano-4B served via Ollama on the Spark; vLLM validated on the GB10 and
drop-in via one env var), and acts — triaging issues, writing standups, and
dispatching a coding step that **opens real PRs**.
State persists across restarts; model failures recover instead of crashing.

- **The agent:** [`src/`](src/) (Python) — `python -m clawforge`
- **The live brain:** NVIDIA Nemotron-3-Nano-4B (Q4_K_M) on the Spark's Ollama,
  reached over an ssh tunnel (`clawforge-ollama.service`, `127.0.0.1:11434`)
- **vLLM validation:** [`vllm-test/`](vllm-test/) — vLLM 0.14 brought up on the
  GB10 (~57 tok/s); a separate validation artifact, swappable in as the brain via
  `CLAWFORGE_MODEL_BASE_URL`
- **Submission + demo runbook:** [`docs/SUBMISSION.md`](docs/SUBMISSION.md)

*NVIDIA Claw Agent Hackathon — Recursive Intelligence track.*

| | |
|--|--|
| **Name** | Clawforge |
| **Folder** | `~/Desktop/hackathon/projects/clawforge/` |
| **Ops / PM** | [`team-ops/`](team-ops/) (in this repo) |
| **Discord** | [HACKATHON TEAM](https://discord.gg/9FFySeV8B) |
| **Browser** | CDP `http://127.0.0.1:9230` (reuse tabs, no spam) |
| **GitHub** | https://github.com/TimothyVang/clawforge (public) |
| **Hub** | [`HUB.md`](HUB.md) — code, PRs, project board, and how to get access |

## Judging

Hackathon rubric, scorecard, submission checklist, and evidence-first audit:

- **[JUDGING.md](JUDGING.md)** — quick view + how to run the judge prompt  
- **[docs/JUDGING.md](docs/JUDGING.md)** — full event judge prep (100-pt breakdown)  
- **[judging/PROMPT.md](judging/PROMPT.md)** — canonical evidence-first judge prompt  
- **[judging/README.md](judging/README.md)** — local harness layout

## Layout

```
clawforge/
  src/       # agent / product code
  docs/      # design, prompts, JUDGING.md
  scripts/   # project tooling
  JUDGING.md # quick judging card
```

## Related

- Team ops: [`team-ops/`](team-ops/)
- Hackathon sandbox: `~/Desktop/hackathon`

## Team mesh sync

```bash
./team-ops/scripts/teamsync.sh
```

Prompt for agents: `./team-ops/config/prompts/teamsync.md`

