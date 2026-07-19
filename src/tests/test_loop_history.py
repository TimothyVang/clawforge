"""Unit tests for the cycle record + append-only audit history."""
from __future__ import annotations

import json
from unittest.mock import MagicMock

from clawforge import loop


def _config(tmp_path, json_output=False):
    cfg = MagicMock()
    cfg.json_snapshot_path = tmp_path / "latest-cycle.json"
    cfg.history_path = tmp_path / "cycle-history.jsonl"
    cfg.json_output = json_output
    cfg.ensure_dirs = lambda: tmp_path.mkdir(parents=True, exist_ok=True)
    return cfg


def _decision(reasoning="because"):
    return {"standup": "all good", "untriaged": 1, "latency_s": 2.5,
            "actions": [{"number": 1, "repo": "o/r", "label": "triage/ready",
                         "rationale": "r", "ready": True}],
            "reasoning": reasoning}


class TestCycleRecord:
    def test_record_includes_reasoning_trace(self):
        rec = loop._cycle_record(7, None, _decision("chain of thought"), None)
        assert rec["cycle"] == 7
        assert rec["reasoning"] == "chain of thought"

    def test_reasoning_truncated_to_2000(self):
        rec = loop._cycle_record(1, None, _decision("x" * 5000), None)
        assert len(rec["reasoning"]) == 2000

    def test_error_cycle_record(self):
        rec = loop._cycle_record(3, None, None, None, error="endpoint down")
        assert rec["error"] == "endpoint down"
        assert "reasoning" not in rec


class TestHistoryAppend:
    def test_snapshot_overwritten_but_history_appends(self, tmp_path):
        cfg = _config(tmp_path)
        loop._write_json_snapshot(cfg, loop._cycle_record(1, None, _decision("r1"), None))
        loop._write_json_snapshot(cfg, loop._cycle_record(2, None, _decision("r2"), None))

        latest = json.loads(cfg.json_snapshot_path.read_text())
        assert latest["cycle"] == 2  # latest view overwritten

        lines = [json.loads(l) for l in cfg.history_path.read_text().splitlines()]
        assert [l["cycle"] for l in lines] == [1, 2]  # history keeps both
        assert lines[0]["reasoning"] == "r1"  # earlier trace survives

    def test_history_lines_are_valid_json(self, tmp_path):
        cfg = _config(tmp_path)
        for i in range(3):
            loop._write_json_snapshot(cfg, loop._cycle_record(i, None, None, None))
        for line in cfg.history_path.read_text().splitlines():
            json.loads(line)  # raises if any line is malformed
