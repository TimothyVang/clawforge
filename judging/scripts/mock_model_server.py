"""Fault-transport stub for the self-healing E2E harness.

HONESTY CONTRACT: this server exists ONLY to inject transport-level faults
(connection refusal is done by stopping it; HTTP 429 by --mode fail_429) so the
harness can test clawforge's REAL error-handling code paths end-to-end. It never
stands in for model quality: harness results label every scenario that used it
with endpoint_mode="stub". Warmup-shaped requests (max_tokens <= 8) are exempt
from the fault schedule so the loop's warmup() cannot consume the fault budget;
each such request is logged with "warmup": true.

Every request is appended to <state-dir>/model-requests.jsonl — the server-side
evidence (status sequence, timestamps) the harness asserts on.
"""
from __future__ import annotations

import argparse
import json
import threading
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

WARMUP_MAX_TOKENS = 8

ARGS: argparse.Namespace
LOCK = threading.Lock()
STATE = {"fails_served": 0, "seq": 0}


def _ts() -> str:
    return datetime.now(timezone.utc).isoformat()


def _log_request(method: str, path: str, status: int, warmup: bool) -> None:
    with LOCK:
        STATE["seq"] += 1
        rec = {"ts": _ts(), "method": method, "path": path, "status": status,
               "warmup": warmup, "seq": STATE["seq"]}
        with open(Path(ARGS.state_dir) / "model-requests.jsonl", "a") as f:
            f.write(json.dumps(rec) + "\n")


def _ok_payload(warmup: bool) -> dict:
    if warmup:
        content = "ok"
        reasoning = ""
    else:
        standup = f"{ARGS.canary} stub standup: heartbeat verified"
        actions = []
        if ARGS.actions:
            actions = [{"id": 1, "label": "triage/question",
                        "rationale": "fixture issue needs clarification",
                        "ready": False}]
        content = json.dumps({"standup": standup, "actions": actions})
        reasoning = f"stub decision trace {ARGS.canary}: triage fixture issue"
    return {
        "id": "chatcmpl-stub",
        "object": "chat.completion",
        "model": "clawforge-stub",
        "choices": [{"index": 0, "finish_reason": "stop",
                     "message": {"role": "assistant", "content": content,
                                 "reasoning_content": reasoning}}],
        "usage": {"prompt_tokens": 0, "completion_tokens": 0, "total_tokens": 0},
    }


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *args) -> None:  # silence default stderr noise
        pass

    def _send_json(self, status: int, body: dict, headers: dict | None = None) -> None:
        data = json.dumps(body).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data)))
        for k, v in (headers or {}).items():
            self.send_header(k, v)
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self) -> None:
        if self.path.rstrip("/").endswith("/models"):
            _log_request("GET", self.path, 200, False)
            self._send_json(200, {"object": "list",
                                  "data": [{"id": "clawforge-stub", "owned_by": "stub"}]})
        else:
            _log_request("GET", self.path, 404, False)
            self._send_json(404, {"error": "not found"})

    def do_POST(self) -> None:
        length = int(self.headers.get("Content-Length", "0"))
        try:
            payload = json.loads(self.rfile.read(length) or b"{}")
        except ValueError:
            payload = {}
        warmup = payload.get("max_tokens", 999) <= WARMUP_MAX_TOKENS

        if not warmup and ARGS.mode == "fail_429":
            with LOCK:
                inject = STATE["fails_served"] < ARGS.fail_count
                if inject:
                    STATE["fails_served"] += 1
            if inject:
                _log_request("POST", self.path, 429, warmup)
                self._send_json(429, {"error": {"message": "stub rate limit (injected)",
                                                "type": "rate_limit_exceeded"}},
                                headers={"Retry-After": str(ARGS.retry_after)})
                return

        _log_request("POST", self.path, 200, warmup)
        self._send_json(200, _ok_payload(warmup))


def main() -> None:
    global ARGS
    p = argparse.ArgumentParser(description="fault-transport stub (see module docstring)")
    p.add_argument("--state-dir", required=True)
    p.add_argument("--mode", choices=["ok", "fail_429"], default="ok")
    p.add_argument("--fail-count", type=int, default=2)
    p.add_argument("--retry-after", type=float, default=1.0)
    p.add_argument("--canary", required=True)
    p.add_argument("--actions", type=int, choices=[0, 1], default=0)
    p.add_argument("--port", type=int, default=0)
    ARGS = p.parse_args()

    Path(ARGS.state_dir).mkdir(parents=True, exist_ok=True)
    server = ThreadingHTTPServer(("127.0.0.1", ARGS.port), Handler)
    # Handshake file written only after a successful bind (race-free startup).
    handshake = {"port": server.server_address[1], "pid": __import__("os").getpid(),
                 "mode": ARGS.mode, "fail_count": ARGS.fail_count,
                 "retry_after": ARGS.retry_after, "canary": ARGS.canary}
    (Path(ARGS.state_dir) / "server.json").write_text(json.dumps(handshake, indent=2))
    server.serve_forever()


if __name__ == "__main__":
    main()
