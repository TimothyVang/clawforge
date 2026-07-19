"""Unit tests for the self-heal harness's fault-transport stub server.

Loaded by path from judging/scripts/ (skipped if absent) so judge_local.sh's
pytest step exercises the harness's own tooling.
"""
from __future__ import annotations

import importlib.util
import json
import sys
import threading
import types
import urllib.error
import urllib.request
from http.server import ThreadingHTTPServer
from pathlib import Path

import pytest

_SCRIPT = Path(__file__).resolve().parents[2] / "judging" / "scripts" / "mock_model_server.py"
if not _SCRIPT.exists():
    pytest.skip("mock_model_server.py not present", allow_module_level=True)

spec = importlib.util.spec_from_file_location("mock_model_server", _SCRIPT)
mms = importlib.util.module_from_spec(spec)
sys.modules["mock_model_server"] = mms
spec.loader.exec_module(mms)


@pytest.fixture
def server(tmp_path):
    """A live stub server in fail_429 mode (2 faults, Retry-After 0.5)."""
    mms.ARGS = types.SimpleNamespace(
        state_dir=str(tmp_path), mode="fail_429", fail_count=2,
        retry_after=0.5, canary="shc-unit-test", actions=0, port=0,
    )
    mms.STATE.update({"fails_served": 0, "seq": 0})
    srv = ThreadingHTTPServer(("127.0.0.1", 0), mms.Handler)
    t = threading.Thread(target=srv.serve_forever, daemon=True)
    t.start()
    yield srv, tmp_path
    srv.shutdown()


def _post(srv, body):
    url = f"http://127.0.0.1:{srv.server_address[1]}/v1/chat/completions"
    req = urllib.request.Request(url, data=json.dumps(body).encode(),
                                 headers={"Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=5) as resp:
            return resp.status, dict(resp.headers), json.loads(resp.read())
    except urllib.error.HTTPError as e:
        return e.code, dict(e.headers), json.loads(e.read() or b"{}")


class TestFaultSequencing:
    def test_serves_exactly_n_429s_then_200(self, server):
        srv, _ = server
        statuses = [_post(srv, {"max_tokens": 600})[0] for _ in range(4)]
        assert statuses == [429, 429, 200, 200]

    def test_retry_after_header_on_429(self, server):
        srv, _ = server
        status, headers, _ = _post(srv, {"max_tokens": 600})
        assert status == 429
        assert headers.get("Retry-After") == "0.5"


class TestCanaryEcho:
    def test_canary_in_content_and_reasoning(self, server):
        srv, _ = server
        for _ in range(2):  # burn the fault budget
            _post(srv, {"max_tokens": 600})
        _, _, body = _post(srv, {"max_tokens": 600})
        msg = body["choices"][0]["message"]
        assert "shc-unit-test" in msg["content"]
        assert "shc-unit-test" in msg["reasoning_content"]


class TestWarmupExemption:
    def test_warmup_bypasses_fault_schedule_and_is_logged(self, server):
        srv, tmp_path = server
        status, _, _ = _post(srv, {"max_tokens": 4})  # warmup-shaped
        assert status == 200  # even though fail budget is unspent
        recs = [json.loads(l) for l in (tmp_path / "model-requests.jsonl").read_text().splitlines()]
        assert recs[-1]["warmup"] is True and recs[-1]["status"] == 200


class TestRequestLog:
    def test_jsonl_lines_valid_with_expected_statuses(self, server):
        srv, tmp_path = server
        _post(srv, {"max_tokens": 600})
        _post(srv, {"max_tokens": 600})
        _post(srv, {"max_tokens": 600})
        recs = [json.loads(l) for l in (tmp_path / "model-requests.jsonl").read_text().splitlines()]
        assert [r["status"] for r in recs] == [429, 429, 200]
        assert [r["seq"] for r in recs] == [1, 2, 3]
