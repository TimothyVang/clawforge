# Clawforge — Judging Guide

**Event:** [AITX Community × NVIDIA Claw Agent Hackathon](https://common-scooter-829.notion.site/AITX-Community-x-NVIDIA-Claw-Agent-Hackathon-39d1e636288e803abcf9e24f6c039bcc)  
**Project:** Clawforge  
**Location:** Antler VC — 800 Brazos St Suite 340 (in person)  
**Dates:** July 17–19, 2026  
**Code freeze / submissions due:** Sunday, July 19 — **11:00 AM CST**  
**Judging window:** Sunday ~12:00 PM–3:00 PM  
**Contact:** team@aitxcommunity.com  

> Source: official Notion page (extracted for team use). Philosophy: **real, working systems** — not slide decks or thin API wrappers.

## Evidence-first judge prompt (canonical)

| File | Role |
|------|------|
| [`../judging/PROMPT.md`](../judging/PROMPT.md) | Full canonical prompt (`BEGIN` … `END JUDGING PROMPT`) |
| [`../judging/README.md`](../judging/README.md) | Local harness layout |
| [`../JUDGING.md`](../JUDGING.md) | Quick card + how to invoke the prompt |

**Standards:** never guess or pass without direct evidence; video is orientation only; trace findings to logs/tool execution; distinguish real hallucination controls from lucky runs; all judge-only state under `judging/`.

---

## 1. What judges are looking for (Claw Agent definition)

A **Claw Agent** is any AI system that is:

| Pillar | Meaning | Clawforge self-check |
|--------|---------|----------------------|
| **Proactively autonomous** | Initiates work, monitors conditions, schedules subtasks, recovers from interruptions, coordinates multi-step workflows with limited human supervision | Does it act without a human message every time? |
| **Heartbeat-driven** | Operates on a loop: wakes on an interval, checks a task list, evaluates what needs action, then acts **or** waits for the next cycle. Trigger is **time/state**, not only a prompt | Is there a real wake/loop (cron, worker, timer)? |
| **Persistent with context** | Owns workspace, memory, files, config, and session history across tasks | Does state survive restarts and multiple cycles? |

If the demo is only “chat UI → one LLM call → reply,” it will score poorly on Claw-ness and technical depth.

---

## 2. Scoring breakdown (100 points total)

### 2.1 Technical Execution & Completeness — **30 pts**

| Points | Criterion | How to score | Clawforge evidence to prepare |
|--------|-----------|--------------|-------------------------------|
| **15** | **Completeness** | Core workflow finishes end-to-end without crashing | Live demo path; E2E script; happy path + one failure recovery |
| **15** | **Technical depth** | Real engineering (pipeline, multi-step agent, tools, state) — not a basic wrapper | Architecture diagram; modules; tools/MCP; loops; logs |

**Judge prompts (what they may ask):**

- “Show the core loop running without you typing prompts.”
- “What happens when a step fails mid-workflow?”
- “Where is the complex pipeline vs. one API call?”

**Internal target:** ≥ 24/30

---

### 2.2 Use of Sponsor Technology — **30 pts**

| Points | Criterion | How to score | Clawforge evidence to prepare |
|--------|-----------|--------------|-------------------------------|
| **15** | **The Stack** | Sponsor tools/APIs used **meaningfully** (not name-dropped) | Actual integration points in code + demo |
| **15** | **The “Why”** | Team can explain **why** that tech was the right choice | 30-second verbal “why this stack” |

**Sponsor / bounty-aligned tech (from official page):**

| Theme | Examples to consider |
|-------|----------------------|
| Inference / agents | **vLLM**, **Nemotron**, **NemoClaw + Open Shell** |
| Data / platform | Red Hat live data track; Supabase credits |
| Security | HiddenLayer runtime security track |
| Hosting / tooling | Featherless AI, Apify |

**Judge prompts:**

- “Where exactly does [sponsor tech] run in the critical path?”
- “What would break if you swapped it for a generic API?”

**Internal target:** ≥ 24/30 — pick **one primary sponsor tech** and make it load-bearing.

---

### 2.3 Value & Impact — **20 pts**

| Points | Criterion | How to score | Clawforge evidence to prepare |
|--------|-----------|--------------|-------------------------------|
| **10** | **Insight quality** | Output is non-obvious and useful | Demo shows a result a human wouldn’t get in 30s of clicking |
| **10** | **Usability** | A real user could act on this tomorrow | Clear UX/CLI; README quick start; realistic persona |

**Judge prompts:**

- “Who uses this Monday morning, and what do they do with the output?”
- “What’s non-obvious about what the agent produced?”

**Internal target:** ≥ 16/20

---

### 2.4 The “Frontier” Factor — **20 pts**

| Points | Criterion | How to score | Clawforge evidence to prepare |
|--------|-----------|--------------|-------------------------------|
| **10** | **Creativity** | Novel combination of tools/data | One “only we did X” moment in the Loom |
| **10** | **Performance** | Optimized for speed or scale | Latency numbers, batching, caching, concurrency |

**Judge prompts:**

- “What’s the cleverest part of the system?”
- “How fast is a full cycle? What did you optimize?”

**Internal target:** ≥ 14/20

---

## 3. Scorecard (print / fill during dry-run)

| Category | Max | Self-score | Judge notes |
|----------|-----|------------|-------------|
| Completeness | 15 | | |
| Technical depth | 15 | | |
| Sponsor stack use | 15 | | |
| Sponsor “why” | 15 | | |
| Insight quality | 10 | | |
| Usability | 10 | | |
| Creativity | 10 | | |
| Performance | 10 | | |
| **Total** | **100** | **/100** | |

**Ship bar:** aim for **≥ 70** before code freeze; **≥ 80** if chasing track/bounty wins.

---

## 4. Tracks & bounties (pick & label clearly)

### Tracks (select one primary)

| Track | Focus (from official list) | Clawforge fit notes |
|-------|----------------------------|---------------------|
| **Recursive Intelligence** | Agents that improve / loop / re-plan | Heartbeat + task list + multi-step recovery |
| **Red Hat Live Data** | Live / streaming / operational data | Wire a live data source into the agent loop |
| **Integrating Runtime Security by HiddenLayer** | Runtime security in the agent path | Security checks inside the loop, not a slide |

### Bounties (optional; stack with track if honest)

| Bounty | What to prove in demo |
|--------|------------------------|
| **Best Use of vLLM** | Inference path through vLLM; why not only a hosted chat API |
| **Best Use of NemoClaw + Open Shell** | NemoClaw / Open Shell in the critical agent loop |
| **Best Use of Nemotron** | Nemotron model role is clear and necessary |
| **Most Commercializable Hack** | Persona + paid pain + path to revenue in write-up |

**Decision (fill before submit):**

- Primary track: `________________________`
- Bounties claimed: `________________________`

---

## 5. Submission checklist (required)

**Due: July 19, 2026 — 11:00 AM CST**  
Submit via the official form linked on the Notion page (“SUBMIT YOUR PROJECT!”).

### Required items

| # | Item | Owner | Status | Link / notes |
|---|------|-------|--------|--------------|
| 1 | Project title & team name | | [ ] | **Clawforge** · Team: `____________` |
| 2 | Track selected | | [ ] | |
| 3 | **2–5 min Loom video** (must be recorded **with Loom**) — show the **core loop live** | | [ ] | loom.com/… |
| 4 | **Public** repo link | | [ ] | github.com/…/clawforge |
| 5 | README with all sections below | | [ ] | |
| 6 | Deployed URL **or** short screen capture of working app | | [ ] | |
| 7 | Team roster (names, roles, contacts) | | [ ] | |
| 8 | Short write-up **150–300 words**: problem → who it helps → solution → impact | | [ ] | |

### README must include

- [ ] **Quick start** (commands to run)
- [ ] **Tech stack** & architecture diagram (simple is fine)
- [ ] **How to reproduce the demo** (env vars, API keys, sample `.env`)
- [ ] **Datasets / synthetic data** used + provenance
- [ ] **Known limitations** & next steps

### Loom rules (from official checklist)

- **Must** be recorded with **Loom**
- **2–5 minutes**
- Show the **core loop live** (heartbeat / autonomous cycle preferred over pure click-tour)

---

## 6. Demo day flow (Sunday)

| Time (CST) | Block |
|------------|--------|
| 10:00 AM | Office opens |
| **11:00 AM** | **Code freeze — submissions due** |
| 11:30 AM | Hackers due back / station setup |
| 11:30 AM – 2:00 PM | Hack fair station setup |
| 12:00 PM – 2:00 PM | Developer roundtables |
| **12:00 PM – 3:00 PM** | **Judging** |
| 2:00 PM – 4:00 PM | Hack fair & public voting |
| 4:00 PM – 5:00 PM | Finale: keynote, awards, winner demos |

### 60-second pitch skeleton

1. **Problem** (10s) — who hurts and why  
2. **Claw loop** (20s) — wake → check → act → persist (show it)  
3. **Sponsor tech** (15s) — where it runs + why  
4. **Impact** (10s) — non-obvious output a user would use tomorrow  
5. **Ask / bounty** (5s) — track + what you want judges to remember  

---

## 7. Clawforge judging prep checklist (team internal)

### Product / agent

- [ ] Heartbeat or scheduled loop is **visible** in demo (logs, UI tick, or terminal)
- [ ] Persistent memory/workspace survives a restart mid-demo
- [ ] At least one multi-step workflow with recovery
- [ ] Not demotable as “wrapper around ChatGPT”

### Sponsor story

- [ ] One primary sponsor technology in the critical path
- [ ] 3-bullet “why this stack” practiced by every teammate
- [ ] Fallback path if network fails (still show architecture)

### Submission package

- [ ] Public repo + complete README
- [ ] Loom recorded on Loom (not OBS-only upload)
- [ ] Write-up 150–300 words
- [ ] Team roster complete
- [ ] Track + bounty labels match the build

### Dry runs

- [ ] Full demo cold start in **&lt; 3 minutes** setup
- [ ] Full demo story in **≤ 5 minutes** (matches Loom)
- [ ] Self-score on section 3 scorecard ≥ 70

---

## 8. Suggested write-up template (150–300 words)

**Problem.** …  
**Who it helps.** …  
**Solution (Clawforge).** Heartbeat-driven agent that …  
**How it works.** Loop: wake → … → act → persist. Stack: … (sponsor tech: … because …).  
**Impact.** …  
**Limits & next.** …  

---

## 9. Credits / platform benefits (optional leverage)

From the official page (use if helpful to the build):

| Partner | Benefit |
|---------|---------|
| Featherless AI | $25 hosting credits |
| Supabase | $25 platform credits |
| Apify | $50 platform usage |

---

## 10. Links

| Resource | URL |
|----------|-----|
| Official hackathon Notion | https://common-scooter-829.notion.site/AITX-Community-x-NVIDIA-Claw-Agent-Hackathon-39d1e636288e803abcf9e24f6c039bcc |
| Clawforge folder | `~/Desktop/hackathon/projects/clawforge/` |
| Team ops / Discord mesh | `~/Desktop/hackathon/projects/team-ops/` |
| Discord | https://discord.gg/9FFySeV8B |
| Questions | team@aitxcommunity.com |

---

*This file is a team working document derived from the public hackathon Notion page for Clawforge prep. Official rules and submission form on Notion remain authoritative if anything conflicts.*
