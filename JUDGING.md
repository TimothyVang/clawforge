# Clawforge — Judging (quick view)

Full event guide: [docs/JUDGING.md](docs/JUDGING.md)  
**Canonical evidence-first judge prompt:** [judging/PROMPT.md](judging/PROMPT.md)  
Harness notes: [judging/README.md](judging/README.md)  
Machine harnesses: `bash judging/scripts/judge_local.sh` (smoke) · `bash judging/scripts/self_heal_e2e.sh` (self-healing E2E: 4 fault scenarios × 3 iterations + negative control → `judging/latest/self_heal_result.json`)

**Event:** AITX Community × NVIDIA Claw Agent Hackathon  
**Source:** https://common-scooter-829.notion.site/AITX-Community-x-NVIDIA-Claw-Agent-Hackathon-39d1e636288e803abcf9e24f6c039bcc  
**Code freeze:** Sun Jul 19 · **11:00 AM CST** · Judging ~12–3 PM  

---

## Judge this project (prompt)

Use the **final canonical** local judge prompt:

```text
judging/PROMPT.md
```

### How to run the judge agent

1. Open a **fresh** agent session (do not reuse a builder that just wrote the code without a clean pass).
2. Set working directory to the Clawforge repo root: `projects/clawforge/`.
3. Load **`judging/PROMPT.md`** as the system / primary instructions (from `BEGIN JUDGING PROMPT` through `END JUDGING PROMPT`).
4. Authorize mode explicitly:

```text
Operating mode: ASSESS_ONLY
Repository root: <path-to-clawforge>
Judge root: judging/
Budget: default
Find Evil competition mode: ACTIVE if judging Claw-style autonomy claims; otherwise INACTIVE
```

5. Optional repair (only if you explicitly allow code changes):

```text
Operating mode: REPAIR_MODE
You may edit project files only to fix READY blockers. Re-run a fresh judge pass after fixes.
```

### Evidence-first standard (do not weaken)

From the canonical prompt — non-negotiable:

| Rule | Meaning |
|------|---------|
| **No guess / no pass without evidence** | Never claim works without run + artifact |
| **Video is orientation only** | Loom orients; logs/tool traces prove |
| **Trace to execution** | Findings → code path + command + log/trace |
| **Hallucination controls ≠ lucky runs** | Prove controls; do not credit a one-off success |
| **No mock core behavior** | Stubs/canned/staged data are not production proof |
| **Judge state only under `judging/`** | No Desktop/tmp/home pollution as “proof” |
| **Fresh clone / portable** | Repo-relative commands; no builder machine secrets |

### Ready verdicts (from prompt)

Use only these next-action lines at the end of a judge report:

- `READY_FULL_E2E`
- `READY_WITH_NARROWED_CLAIMS`
- `NEEDS_FULL_E2E_REVIEW`
- `NEEDS_FIXES`
- `NOT_READY`
- `HUMAN_REVIEW_REQUIRED`

---

## Philosophy (hackathon)

Real, working systems — not slide decks or simple API wrappers.

## Claw Agent (must show)

1. **Proactively autonomous** — multi-step work with limited human supervision  
2. **Heartbeat-driven** — time/state loop, not only human prompts  
3. **Persistent context** — workspace, memory, files, history across tasks  

## Score (100) — event rubric

| Category | Pts |
|----------|-----|
| Technical execution & completeness | **30** (15 complete + 15 depth) |
| Use of sponsor technology | **30** (15 stack + 15 why) |
| Value & impact | **20** (10 insight + 10 usability) |
| “Frontier” factor | **20** (10 creativity + 10 performance) |

## Tracks

- Recursive Intelligence  
- Red Hat Live Data  
- Integrating Runtime Security by HiddenLayer  

## Bounties

- Best Use of vLLM  
- Best Use of NemoClaw + Open Shell  
- Best Use of Nemotron  
- Most Commercializable Hack  

## Submit (required)

- [ ] Project title & team name (**Clawforge**)  
- [ ] Track selected  
- [ ] 2–5 min **Loom** (core loop live; **must use Loom**)  
- [ ] **Public** repo + README (quick start, stack/diagram, repro/.env, data provenance, limitations)  
- [ ] Deployed URL or screen capture  
- [ ] Team roster  
- [ ] 150–300 word write-up (problem → who → solution → impact)  

Self-score: `docs/JUDGING.md` §3 · target **≥ 70** before freeze.

## Dual bar

| Bar | Doc |
|-----|-----|
| Event judges (100 pts + tracks) | this file + `docs/JUDGING.md` |
| Completeness / anti-fake / E2E / autonomy | **`judging/PROMPT.md`** |

A project can look good on the event scorecard and still be `NOT_READY` under the evidence-first prompt (or the reverse). Ship only when both bars are honest.
