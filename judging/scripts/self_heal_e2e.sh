#!/usr/bin/env bash
# self_heal_e2e.sh — judge-runnable E2E self-healing demonstration.
#
# HONESTY CONTRACT (also embedded in the result JSON):
# - Controlled, judge-reproducible fault injection — transparently labeled.
#   This proves clawforge's four recovery controls end-to-end; it does NOT
#   claim organic-fault proof.
# - The stub HTTP server is fault TRANSPORT only (429s / connection refusal);
#   clawforge's real sense→decide→client→act→persist code runs unmodified.
# - Stub scenarios sense a labeled read-only `gh` fixture (one untriaged issue)
#   so a real triage decision runs deterministically offline; without it the
#   agent short-circuits and never calls the model. The optional S0 scenario
#   uses the real endpoint + real gh reads when reachable.
# - S4 recovery semantics: a corrupt ledger recovers to FRESH state (cycle
#   counter resets by design) — recovery, not restoration.
#
# Scenarios (3 iterations each + negative control):
#   S1 endpoint death -> recovery      S2 429 storm absorbed by backoff
#   S3 kill -9 -> ledger survival      S4 corrupt ledger -> fresh-state recovery
#   NC negative control (no fault -> all four signatures asserted ABSENT)
#   S0 live endpoint happy-path (auto-detected; SKIPPED when unreachable)
#
# All state/evidence stays under judging/ (never touches .generated/ or the
# running clawforge service). Exit 0 = every attempted scenario PASSed.
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
RUN_ID="$(date -u +%Y%m%dT%H%M%SZ)"
RUN="$ROOT/judging/runs/$RUN_ID"
CANARY="shc-${RUN_ID}-$(od -An -tx4 -N4 /dev/urandom | tr -d ' \n')"
ITERS=3

mkdir -p "$RUN"/{logs,state,artifacts,reports,home,bin,tmp/pycache} "$ROOT/judging/latest"

# Safety guard: refuse to run if any state path resolves into production state.
case "$RUN" in
  *".generated"*) echo "FATAL: run dir resolves into .generated/ — aborting" >&2; exit 2 ;;
esac

# Captured BEFORE the HOME override so S0-live keeps real gh auth.
REAL_GH_TOKEN="$(gh auth token 2>/dev/null || true)"

log() { printf '[self_heal_e2e] %s\n' "$*"; }

# ---------------------------------------------------------------- gh fixture
write_gh_shim() {
  cat > "$RUN/bin/gh" <<PYEOF
#!/usr/bin/env python3
"""Read-only gh FIXTURE for the self-heal harness (stub scenarios only).
Serves exactly one untriaged issue in the fixture watched repo so a real
triage decision runs offline. Everything else fails -> callers' documented
fallbacks. Labeled sense_mode=fixture in the harness result."""
import json, sys
a = sys.argv[1:]
def out(x): print(json.dumps(x)); sys.exit(0)
if len(a) >= 2 and a[0] == "issue" and a[1] == "list":
    repo = a[a.index("--repo") + 1] if "--repo" in a else ""
    state = a[a.index("--state") + 1] if "--state" in a else "open"
    if repo == "fixture/demo" and state == "open":
        out([{"number": 101,
              "title": "[fixture ${CANARY}] verify heartbeat triage",
              "labels": [],
              "body": "deterministic sense fixture for the self-heal harness",
              "url": "https://example.invalid/fixture/demo/issues/101"}])
    out([])
if len(a) >= 2 and a[0] == "pr" and a[1] == "list":
    out([])
sys.exit(1)
PYEOF
  chmod +x "$RUN/bin/gh"
}

# ---------------------------------------------------------------- verifier
write_verifier() {
  cat > "$RUN/bin/verify.py" <<'PYEOF'
"""Shared scenario verifier. Appends structured check results to the trace
JSONL and a per-iteration summary line to scenario-checks.jsonl."""
import json, sys
from datetime import datetime, timezone
from pathlib import Path

scenario, iteration, state_dir, run_dir, canary = sys.argv[1:6]
state = Path(state_dir); run = Path(run_dir)
checks = []

def check(name, expected, observed, ok):
    checks.append({"name": name, "expected": expected,
                   "observed": str(observed)[:300], "ok": bool(ok)})

def jsonl(p):
    return [json.loads(l) for l in p.read_text().splitlines()] if p.exists() else []

hist = jsonl(state / "cycle-history.jsonl")
reqs = [r for r in jsonl(state / "model-requests.jsonl")]
chat = [r for r in reqs if r["method"] == "POST" and not r["warmup"]]
logtxt = (state / "clawforge.log").read_text() if (state / "clawforge.log").exists() else ""
ledger = json.loads((state / "ledger.json").read_text()) if (state / "ledger.json").exists() else {}
errors = [r.get("error") for r in hist]

if scenario == "s1":
    check("three_cycles", "3 history records", len(hist), len(hist) == 3)
    seq_ok = (len(errors) == 3 and errors[0] is None and errors[2] is None
              and errors[1] is not None and "endpoint unreachable" in str(errors[1]))
    check("error_sequence", "null -> 'endpoint unreachable' -> null", errors, seq_ok)
    check("recovery_log_line", "exactly 1 MODEL FAILURE (recovering)",
          logtxt.count("MODEL FAILURE (recovering)"),
          logtxt.count("MODEL FAILURE (recovering)") == 1)
    ok_recs = [r for r in hist if r.get("error") is None]
    can_ok = all(canary in (r.get("standup") or "") for r in ok_recs) and len(ok_recs) == 2
    check("canary_in_ok_records", "canary in standup of both ok records", len(ok_recs), can_ok)
    err_rec = next((r for r in hist if r.get("error")), {})
    check("canary_absent_in_error_record", "no standup/canary in error record",
          err_rec.get("standup"), canary not in str(err_rec.get("standup") or ""))
elif scenario == "s2":
    check("one_cycle", "1 history record", len(hist), len(hist) == 1)
    check("no_error", "error == null", errors, errors == [None])
    statuses = [r["status"] for r in chat]
    check("server_status_sequence", "[429, 429, 200]", statuses, statuses == [429, 429, 200])
    gap_ok = False
    if len(chat) >= 2:
        t = [datetime.fromisoformat(r["ts"]) for r in chat[:2]]
        gap_ok = (t[1] - t[0]).total_seconds() >= 0.9
    check("retry_after_honored", ">=0.9s between first two 429s", "measured", gap_ok)
    lat = hist[0].get("latency_s", 0) if hist else 0
    check("backoff_inside_cycle", "latency_s >= 1.5", lat, lat >= 1.5)
    check("not_exhausted", "'retries exhausted' absent from log",
          "retries exhausted" in logtxt, "retries exhausted" not in logtxt)
elif scenario == "s3":
    before = json.loads((state / "ledger.before.json").read_text())
    # The SIGKILL'd process writes NO stop line; the graceful --once restart
    # writes exactly one, and it must appear only AFTER the second start.
    starts = logtxt.count("start model=")
    stops = logtxt.count("stopped after")
    second_start = logtxt.find("start model=", logtxt.find("start model=") + 1)
    stop_pos = logtxt.find("stopped after")
    check("sigkill_discontinuity",
          "2 starts, 1 stop, stop only after the restart's start",
          [starts, stops],
          starts == 2 and stops == 1 and second_start != -1 and stop_pos > second_start)
    check("ledger_continuity", f"cycles {before['cycles']} -> {before['cycles']+1}, no reset",
          ledger.get("cycles"), ledger.get("cycles") == before["cycles"] + 1)
    check("no_duplicate_actions", "acted keys identical across kill",
          sorted(ledger.get("acted", {})), sorted(ledger.get("acted", {})) == sorted(before.get("acted", {})))
    cyc = [r["cycle"] for r in hist]
    check("history_monotonic", "cycle numbers strictly increasing across kill",
          cyc, cyc == sorted(set(cyc)) and len(cyc) >= 2)
    post = hist[-1] if hist else {}
    check("post_restart_no_reapply", "applied == [] after restart",
          post.get("applied"), post.get("applied") == [])
elif scenario == "s4":
    check("survived_corruption", "process exit 0 handled by harness; ledger parses",
          bool(ledger), bool(ledger))
    check("fresh_state_reset", "cycles == 1 (fresh-state recovery, by design)",
          ledger.get("cycles"), ledger.get("cycles") == 1)
    cyc = [r["cycle"] for r in hist]
    check("history_survives", "history shows [1, 2, 1] — durable across ledger rebuild",
          cyc, cyc == [1, 2, 1])
    check("log_appends", "3 process starts in one continuous log",
          logtxt.count("start model="), logtxt.count("start model=") == 3)
elif scenario == "nc":
    check("no_errors", "all errors null", errors, all(e is None for e in errors) and len(hist) == 3)
    check("no_failure_lines", "0 MODEL FAILURE lines",
          logtxt.count("MODEL FAILURE"), "MODEL FAILURE" not in logtxt)
    statuses = [r["status"] for r in chat]
    check("all_200", "no non-200 chat responses", statuses, all(s == 200 for s in statuses))
    check("no_reset", "ledger cycles == 3", ledger.get("cycles"), ledger.get("cycles") == 3)
    cyc = [r["cycle"] for r in hist]
    check("monotonic", "[1,2,3]", cyc, cyc == [1, 2, 3])
elif scenario == "s0":
    check("live_cycle_completed", "1 history record written", len(hist), len(hist) == 1)

ok = all(c["ok"] for c in checks)
ts = datetime.now(timezone.utc).isoformat()
with open(run / "artifacts" / "self_heal_trace.jsonl", "a") as f:
    for c in checks:
        f.write(json.dumps({"ts": ts, "scenario": scenario, "iteration": int(iteration), **c}) + "\n")

# Copy evidence files into artifacts/<scenario>/iter<i>/
dest = run / "artifacts" / scenario / f"iter{iteration}"
dest.mkdir(parents=True, exist_ok=True)
for name in ["cycle-history.jsonl", "clawforge.log", "ledger.json",
             "ledger.before.json", "ledger.corrupt.txt", "model-requests.jsonl",
             "server.json", "latest-cycle.json"]:
    src = state / name
    if src.exists():
        (dest / name).write_bytes(src.read_bytes())

with open(run / "reports" / "scenario-checks.jsonl", "a") as f:
    f.write(json.dumps({"scenario": scenario, "iteration": int(iteration), "ok": ok,
                        "checks": checks, "state_dir": str(state),
                        "artifacts_dir": str(dest)}) + "\n")
print(("PASS" if ok else "FAIL: " + "; ".join(c["name"] for c in checks if not c["ok"])))
sys.exit(0 if ok else 1)
PYEOF
}

# ---------------------------------------------------------------- helpers
PORT=""; STUB_PID=""

agent_env() {  # $1 = state dir; echoes env assignments for `env`
  echo "HOME=$RUN/home PATH=$RUN/bin:$PATH PYTHONPATH=. PYTHONPYCACHEPREFIX=$RUN/tmp/pycache \
CLAWFORGE_STATE_DIR=$1 CLAWFORGE_MODEL_BASE_URL=http://127.0.0.1:$PORT/v1 \
CLAWFORGE_MODEL=clawforge-stub CLAWFORGE_MODEL_API_KEY=EMPTY CLAWFORGE_MODEL_TIMEOUT=10 \
CLAWFORGE_MODEL_MAX_RETRIES=3 CLAWFORGE_MODEL_RETRY_BASE=0.2 CLAWFORGE_MODEL_RETRY_CAP=2 \
CLAWFORGE_INTERVAL=1 CLAWFORGE_MAX_CYCLES=0 CLAWFORGE_DRY_RUN=1 CLAWFORGE_DISPATCH=0 \
CLAWFORGE_REPO=fixture/demo CLAWFORGE_WORK_REPO=fixture/demo-work CLAWFORGE_TRACK_REPOS= \
CLAWFORGE_OWNER=fixture DISCORD_BOT_TOKEN= CLAWFORGE_DISCORD_CHANNEL="
}

start_stub() {  # $1 state dir, rest: extra server args
  local sd="$1"; shift
  python3 "$ROOT/judging/scripts/mock_model_server.py" \
    --state-dir "$sd" --canary "$CANARY" "$@" >>"$RUN/logs/stub.log" 2>&1 &
  STUB_PID=$!
  for _ in $(seq 1 50); do
    [ -f "$sd/server.json" ] && break
    sleep 0.1
  done
  PORT=$(python3 -c "import json,sys;print(json.load(open('$sd/server.json'))['port'])")
}

stop_stub() { [ -n "$STUB_PID" ] && kill "$STUB_PID" 2>/dev/null; wait "$STUB_PID" 2>/dev/null; STUB_PID=""; }

CMD_LOG="$RUN/reports/commands.jsonl"
cycle() {  # $1 name, $2 state dir, $3 extra flags (e.g. "--once")
  local name="$1" sd="$2" flags="${3:---once}"
  local t0=$SECONDS
  ( cd "$ROOT/src" && env $(agent_env "$sd") python3 -m clawforge $flags --dry-run --json ) \
    >"$RUN/logs/$name.out" 2>"$RUN/logs/$name.err"
  local rc=$?
  python3 - "$name" "$rc" "$((SECONDS - t0))" "$RUN/logs/$name.out" <<'PY' >> "$CMD_LOG"
import json, sys
print(json.dumps({"command": f"clawforge cycle {sys.argv[1]}", "exit_code": int(sys.argv[2]),
                  "duration_seconds": int(sys.argv[3]), "stdout_path": sys.argv[4],
                  "stderr_path": sys.argv[4].replace(".out", ".err")}))
PY
  return "$rc"
}

declare -A PASSED FAILED
verdict_note() { PASSED[$1]=${PASSED[$1]:-0}; FAILED[$1]=${FAILED[$1]:-0}; }

run_verify() {  # $1 scenario, $2 iter, $3 state dir
  verdict_note "$1"
  if python3 "$RUN/bin/verify.py" "$1" "$2" "$3" "$RUN" "$CANARY" >>"$RUN/logs/verify-$1-$2.log" 2>&1; then
    PASSED[$1]=$((PASSED[$1] + 1)); log "$1 iter$2: PASS"
  else
    FAILED[$1]=$((FAILED[$1] + 1)); log "$1 iter$2: FAIL ($(tail -1 "$RUN/logs/verify-$1-$2.log"))"
  fi
}

# ---------------------------------------------------------------- scenarios
s1() {  # endpoint death -> recovery
  for i in $(seq 1 $ITERS); do
    local sd="$RUN/state/s1/iter$i"; mkdir -p "$sd"
    start_stub "$sd" --mode ok
    cycle "s1-i$i-a" "$sd"
    local keep_port=$PORT
    stop_stub                       # the fault: endpoint dies
    cycle "s1-i$i-b" "$sd" || true  # error cycle (rc still 0 — recovery by design)
    start_stub "$sd" --mode ok --port "$keep_port"   # endpoint returns, same port
    cycle "s1-i$i-c" "$sd"
    stop_stub
    run_verify s1 "$i" "$sd"
  done
}

s2() {  # 429 storm absorbed inside one cycle
  for i in $(seq 1 $ITERS); do
    local sd="$RUN/state/s2/iter$i"; mkdir -p "$sd"
    start_stub "$sd" --mode fail_429 --fail-count 2 --retry-after 1
    cycle "s2-i$i" "$sd"
    stop_stub
    run_verify s2 "$i" "$sd"
  done
}

s3() {  # kill -9 mid-run -> ledger survival + idempotency
  for i in $(seq 1 $ITERS); do
    local sd="$RUN/state/s3/iter$i"; mkdir -p "$sd"
    start_stub "$sd" --mode ok --actions 1
    # exec makes the backgrounded subshell BECOME the python process, so
    # $! is the agent's PID and kill -9 hits the agent, not a wrapper shell.
    ( cd "$ROOT/src" && exec env $(agent_env "$sd") python3 -m clawforge --dry-run --json ) \
      >"$RUN/logs/s3-i$i-loop.out" 2>&1 &
    local agent_pid=$!
    for _ in $(seq 1 300); do  # wait for >=2 history lines (<=30s)
      [ -f "$sd/cycle-history.jsonl" ] && [ "$(wc -l < "$sd/cycle-history.jsonl")" -ge 2 ] && break
      sleep 0.1
    done
    kill -9 "$agent_pid" 2>/dev/null; wait "$agent_pid" 2>/dev/null
    cp "$sd/ledger.json" "$sd/ledger.before.json"
    cycle "s3-i$i-restart" "$sd"
    stop_stub
    run_verify s3 "$i" "$sd"
  done
}

s4() {  # corrupt ledger -> fresh-state recovery
  for i in $(seq 1 $ITERS); do
    local sd="$RUN/state/s4/iter$i"; mkdir -p "$sd"
    start_stub "$sd" --mode ok
    cycle "s4-i$i-seed1" "$sd"
    cycle "s4-i$i-seed2" "$sd"
    cp "$sd/ledger.json" "$sd/ledger.before.json"
    printf 'garbage{{{not json' > "$sd/ledger.json"
    cp "$sd/ledger.json" "$sd/ledger.corrupt.txt"
    if ! cycle "s4-i$i-recover" "$sd"; then
      log "s4 iter$i: agent crashed on corrupt ledger (rc!=0)"
    fi
    stop_stub
    run_verify s4 "$i" "$sd"
  done
}

nc() {  # negative control: no fault injected
  local sd="$RUN/state/nc"; mkdir -p "$sd"
  start_stub "$sd" --mode ok
  cycle "nc-1" "$sd"; cycle "nc-2" "$sd"; cycle "nc-3" "$sd"
  stop_stub
  run_verify nc 1 "$sd"
}

S0_VERDICT="SKIPPED"; S0_REASON="endpoint unreachable"
s0_live() {  # optional real-endpoint happy path
  local base key
  base=$(cd "$ROOT/src" && python3 -c "from clawforge.config import Config; print(Config().base_url)")
  key=$(cd "$ROOT/src" && python3 -c "from clawforge.config import Config; print(Config().api_key)")
  if curl -sf -m 6 -H "Authorization: Bearer $key" -H "ngrok-skip-browser-warning: true" \
       "$base/models" >/dev/null 2>&1; then
    local sd="$RUN/state/s0-live-$CANARY"; mkdir -p "$sd"
    local t0=$SECONDS
    ( cd "$ROOT/src" && env HOME="$RUN/home" PYTHONPATH=. PYTHONPYCACHEPREFIX="$RUN/tmp/pycache" \
        GH_TOKEN="$REAL_GH_TOKEN" GITHUB_TOKEN="$REAL_GH_TOKEN" \
        CLAWFORGE_STATE_DIR="$sd" CLAWFORGE_DRY_RUN=1 CLAWFORGE_DISPATCH=0 \
        DISCORD_BOT_TOKEN= CLAWFORGE_DISCORD_CHANNEL= \
        python3 -m clawforge --once --dry-run --json ) \
      >"$RUN/logs/s0-live.out" 2>"$RUN/logs/s0-live.err"
    local rc=$?
    echo "{\"command\": \"clawforge cycle s0-live\", \"exit_code\": $rc, \"duration_seconds\": $((SECONDS - t0)), \"stdout_path\": \"$RUN/logs/s0-live.out\", \"stderr_path\": \"$RUN/logs/s0-live.err\"}" >> "$CMD_LOG"
    if [ "$rc" -eq 0 ] && python3 "$RUN/bin/verify.py" s0 1 "$sd" "$RUN" "$CANARY" >>"$RUN/logs/verify-s0-1.log" 2>&1; then
      S0_VERDICT="PASS"; S0_REASON=""
    else
      S0_VERDICT="FAIL"; S0_REASON="live cycle rc=$rc or verify failed"
    fi
  fi
  log "s0-live: $S0_VERDICT ${S0_REASON:+($S0_REASON)}"
}

# ---------------------------------------------------------------- main
log "run $RUN_ID canary=$CANARY"
write_gh_shim
write_verifier
s1; s2; s3; s4; nc; s0_live

# ---------------------------------------------------------------- result JSON
export RUN RUN_ID CANARY S0_VERDICT S0_REASON ROOT
python3 - <<'PY'
import json, os
from datetime import datetime, timezone
from pathlib import Path

run = Path(os.environ["RUN"]); root = Path(os.environ["ROOT"])
checks = [json.loads(l) for l in (run / "reports" / "scenario-checks.jsonl").read_text().splitlines()]
cmds = [json.loads(l) for l in (run / "reports" / "commands.jsonl").read_text().splitlines()]

META = {
    "s1": ("endpoint death + recovery", "error null -> 'endpoint unreachable' -> null; one MODEL FAILURE (recovering) log line"),
    "s2": ("429 storm absorbed by backoff", "server [429,429,200] with Retry-After gap; cycle error==null, latency>=1.5s; never exhausts"),
    "s3": ("kill -9 + ledger survival", "log discontinuity (2 starts, 0 stops) + ledger continuity (cycles+1, identical acted keys, no re-apply)"),
    "s4": ("corrupt ledger -> fresh-state recovery", "exit 0 on garbage ledger; cycles reset to 1 BY DESIGN; history/log keep appending"),
    "nc": ("negative control (no fault)", "all four fault signatures asserted ABSENT"),
}
scenarios = []
overall_fail = False
for sid, (name, sig) in META.items():
    rows = [c for c in checks if c["scenario"] == sid]
    passed = sum(1 for r in rows if r["ok"]); failed = len(rows) - passed
    verdict = "PASS" if rows and failed == 0 else "FAIL"
    if verdict == "FAIL":
        overall_fail = True
    scenarios.append({
        "id": sid.upper(), "name": name,
        "endpoint_mode": "stub", "sense_mode": "fixture",
        "negative_control": sid == "nc",
        "iterations": len(rows), "passed": passed, "failed": failed,
        "verdict": verdict, "skipped_reason": None,
        "distinct_signature": sig,
        "canary_propagation": "in-band standup+reasoning",
        "evidence": [{"iteration": r["iteration"], "state_dir": r["state_dir"],
                      "artifacts_dir": r["artifacts_dir"], "checks": r["checks"]} for r in rows],
    })
s0v = os.environ["S0_VERDICT"]
if s0v == "FAIL":
    overall_fail = True
scenarios.append({
    "id": "S0", "name": "live endpoint happy path (optional)",
    "endpoint_mode": "live", "sense_mode": "live", "negative_control": False,
    "iterations": 1 if s0v != "SKIPPED" else 0,
    "passed": 1 if s0v == "PASS" else 0, "failed": 1 if s0v == "FAIL" else 0,
    "verdict": s0v, "skipped_reason": os.environ["S0_REASON"] or None,
    "distinct_signature": "real endpoint + real gh reads, dry-run, isolated state dir named by canary",
    "canary_propagation": "state-dir path",
    "evidence": [],
})
result = {
    "schema_version": "1.0",
    "harness": "self_heal_e2e",
    "run_id": os.environ["RUN_ID"],
    "timestamp": datetime.now(timezone.utc).isoformat(),
    "canary": os.environ["CANARY"],
    "overall_verdict": "FAIL" if overall_fail else "PASS",
    "honesty": {
        "fault_injection": "controlled, judge-reproducible, transparently labeled",
        "claim_scope": "proves the four recovery controls E2E under controlled fault injection; does NOT claim organic-fault proof",
        "stub_role": "stdlib HTTP server used only as fault transport for the model endpoint; warmup requests (max_tokens<=8) are fault-exempt and logged",
        "sense_fixture": "stub scenarios sense a labeled read-only gh fixture (one untriaged issue) so a real triage decision runs deterministically offline; live scenario uses real gh reads",
        "corrupt_recovery_semantics": "S4 recovery = fresh ledger state (cycle counter resets), not restoration",
    },
    "scenarios": scenarios,
    "commands_run": cmds,
    "trace_file": str(run / "artifacts" / "self_heal_trace.jsonl"),
}
for p in (root / "judging" / "latest" / "self_heal_result.json",
          run / "reports" / "self_heal_result.json"):
    p.write_text(json.dumps(result, indent=2) + "\n")
print(f"[self_heal_e2e] overall: {result['overall_verdict']} -> {root / 'judging' / 'latest' / 'self_heal_result.json'}")
PY

# Exit nonzero if any attempted scenario failed.
for sid in s1 s2 s3 s4 nc; do
  if [ "${FAILED[$sid]:-0}" -gt 0 ]; then exit 1; fi
done
[ "$S0_VERDICT" = "FAIL" ] && exit 1
exit 0
