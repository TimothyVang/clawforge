#!/usr/bin/env bash
# judge_local.sh — minimal machine judging harness (smoke level).
#
# Runs the deterministic checks a judge can execute without our hardware and
# writes judging/latest/judge_result.json (+ a timestamped copy under
# judging/runs/). HONESTY CONTRACT: this script only records what it actually
# ran. It reports SMOKE_ONLY coverage and never emits a READY verdict — the
# full audit (judging/PROMPT.md) is an AI/human judge's job, not this script's.
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
RUN_ID="$(date -u +%Y%m%dT%H%M%SZ)"
LATEST="$ROOT/judging/latest"
RUN_DIR="$ROOT/judging/runs/$RUN_ID/reports"
LOG_DIR="$ROOT/judging/runs/$RUN_ID/logs"
mkdir -p "$LATEST" "$RUN_DIR" "$LOG_DIR"

declare -a CMDS EXITS DURS LOGS

run_check() {
  local name="$1"; shift
  local log="$LOG_DIR/$name.log"
  local t0=$SECONDS
  ( cd "$ROOT/src" && "$@" ) >"$log" 2>&1
  local rc=$?
  CMDS+=("$*"); EXITS+=("$rc"); DURS+=("$((SECONDS - t0))")
  LOGS+=("judging/runs/$RUN_ID/logs/$name.log")
  printf '[judge_local] %-16s exit=%d (%ss)\n' "$name" "$rc" "$((SECONDS - t0))"
  return "$rc"
}

FAIL=0

# 1. Unit tests (pure, no network or model endpoint needed).
run_check pytest env PYTHONPATH=. python3 -m pytest tests/ -q || FAIL=1
# 2. CLI surface.
run_check cli-version env PYTHONPATH=. python3 -m clawforge --version || FAIL=1
run_check cli-status env PYTHONPATH=. python3 -m clawforge --status || FAIL=1
# 3. One dry-run heartbeat cycle (needs a reachable model endpoint; a failure
#    here is recorded, not hidden — it means the brain endpoint is down).
run_check dry-run-cycle env PYTHONPATH=. python3 -m clawforge --once --dry-run || FAIL=1
# 4. Durable artifacts exist; cycle history (if present) is valid JSONL.
run_check artifacts env PYTHONPATH=. python3 -c '
import json, sys
from clawforge.config import Config
cfg = Config()
missing = [str(p) for p in (cfg.ledger_path, cfg.snapshot_path, cfg.json_snapshot_path)
           if not p.exists()]
if missing:
    sys.exit("missing artifacts: " + ", ".join(missing))
if cfg.history_path.exists():
    for line in cfg.history_path.read_text().splitlines():
        json.loads(line)
ledger = json.loads(cfg.ledger_path.read_text())
print("cycles=%s acted=%s" % (ledger["cycles"], len(ledger["acted"])))
' || FAIL=1

# Emit judge_result.json (honest smoke-level verdicts only).
export JL_CMDS="$(IFS=$'\x1e'; echo "${CMDS[*]:-}")"
export JL_EXITS="$(IFS=$'\x1e'; echo "${EXITS[*]:-}")"
export JL_DURS="$(IFS=$'\x1e'; echo "${DURS[*]:-}")"
export JL_LOGS="$(IFS=$'\x1e'; echo "${LOGS[*]:-}")"
python3 - "$RUN_ID" "$ROOT" "$FAIL" <<'PY'
import json, os, sys
from datetime import datetime, timezone

run_id, root, fail = sys.argv[1], sys.argv[2], sys.argv[3] == "1"
split = lambda k: os.environ.get(k, "").split("\x1e")
cmds, exits, durs, logs = split("JL_CMDS"), split("JL_EXITS"), split("JL_DURS"), split("JL_LOGS")
result = {
    "schema_version": "2.0",
    "run_id": run_id,
    "timestamp": datetime.now(timezone.utc).isoformat(),
    "mode": "HARNESS_ONLY",
    # This harness can only prove smoke level; deeper verdicts need a real judge.
    "overall_verdict": "NEEDS_FIXES" if fail else "NEEDS_FULL_E2E_REVIEW",
    "e2e_coverage_verdict": "SMOKE_ONLY",
    "ai_automation_e2e_verdict": "NOT_PROVEN",
    "staged_data_verdict": "E2E_NOT_PROVEN",
    "ready_blockers": (["one or more smoke checks failed — see commands_run"] if fail else []),
    "high_risk_non_blockers": [],
    "human_review_items": [
        "Full audit per judging/PROMPT.md (this file is machine smoke output only)",
        "Verify live autonomous PR chain: ledger key -> branch -> PR on the work repo",
    ],
    "commands_run": [
        {"command": c, "exit_code": int(e or 0), "duration_seconds": int(d or 0),
         "stdout_path": l, "stderr_path": l, "evidence_manifest_ids": []}
        for c, e, d, l in zip(cmds, exits, durs, logs) if c
    ],
    "claims": [],
    "workflows": [],
    "scenarios": [],
}
for path in (f"{root}/judging/latest/judge_result.json",
             f"{root}/judging/runs/{run_id}/reports/judge_result.json"):
    with open(path, "w") as f:
        json.dump(result, f, indent=2)
print(f"[judge_local] wrote judge_result.json (run {run_id}, fail={fail})")
PY

exit "$FAIL"
