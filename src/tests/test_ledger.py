"""Unit tests for the ledger — idempotence and restart survival."""
from __future__ import annotations

from unittest.mock import MagicMock

from clawforge.ledger import Ledger


def _config(tmp_path):
    cfg = MagicMock()
    cfg.ledger_path = tmp_path / "ledger.json"
    cfg.ensure_dirs = lambda: tmp_path.mkdir(parents=True, exist_ok=True)
    return cfg


class TestLedger:
    def test_fresh_ledger_has_no_actions(self, tmp_path):
        led = Ledger(_config(tmp_path))
        assert not led.has_acted("triage:o/r#1")
        assert led.cycles == 0

    def test_record_makes_has_acted_true(self, tmp_path):
        led = Ledger(_config(tmp_path))
        led.record("dispatch:o/r#1", "pr-url")
        assert led.has_acted("dispatch:o/r#1")

    def test_state_survives_restart(self, tmp_path):
        cfg = _config(tmp_path)
        led = Ledger(cfg)
        led.record("triage:o/r#1")
        led.bump_cycle()
        led.save()
        # Simulate a process restart: brand-new instance, same path.
        led2 = Ledger(cfg)
        assert led2.has_acted("triage:o/r#1")
        assert led2.cycles == 1
        assert not led2.has_acted("triage:o/r#2")

    def test_cycle_counter_monotonic(self, tmp_path):
        led = Ledger(_config(tmp_path))
        assert [led.bump_cycle() for _ in range(3)] == [1, 2, 3]

    def test_corrupt_ledger_file_recovers_empty(self, tmp_path):
        cfg = _config(tmp_path)
        cfg.ledger_path.parent.mkdir(parents=True, exist_ok=True)
        cfg.ledger_path.write_text("{not json")
        led = Ledger(cfg)
        assert led.cycles == 0
        assert not led.has_acted("anything")
