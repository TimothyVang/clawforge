"""Unit tests for decide.py — JSON extraction and id-mapped triage decisions."""
from __future__ import annotations

from unittest.mock import MagicMock

from clawforge import decide


class TestExtractJson:
    def test_plain_object(self):
        assert decide._extract_json('{"a": 1}') == {"a": 1}

    def test_fenced_json(self):
        assert decide._extract_json('```json\n{"a": 1}\n```') == {"a": 1}

    def test_think_block_with_braces_is_stripped(self):
        text = '<think>maybe {"wrong": true}? hmm</think>{"a": 2}'
        assert decide._extract_json(text) == {"a": 2}

    def test_prose_around_object(self):
        assert decide._extract_json('Sure! Here it is: {"a": 3} hope that helps') == {"a": 3}

    def test_no_json_returns_none(self):
        assert decide._extract_json("no json here") is None

    def test_malformed_json_returns_none(self):
        assert decide._extract_json('{"a": unclosed') is None


def _state(issues, work_issues=()):
    # Mirrors sense.read_state's shape: multi-repo "watched" groups + work repo.
    return {
        "repo": "o/watched",
        "work_repo": "o/work",
        "watched": [{"repo": "o/watched", "open": list(issues), "closed": []}],
        "issues": list(issues),
        "work_issues": list(work_issues),
        "counts": {"issues": len(issues), "work_issues": len(work_issues), "prs": 0},
    }


def _issue(number, title="t", labels=()):
    return {"number": number, "title": title, "body": "",
            "labels": [{"name": n} for n in labels]}


def _client_returning(content, reasoning="", latency=1.0):
    client = MagicMock()
    res = MagicMock()
    res.content = content
    res.reasoning = reasoning
    res.latency_s = latency
    client.chat.return_value = res
    return client


class TestDecide:
    def test_no_untriaged_short_circuits_without_model_call(self):
        client = MagicMock()
        state = _state([_issue(1, labels=["triage/ready"])])
        out = decide.decide(client, state)
        assert out["untriaged"] == 0
        assert out["actions"] == []
        assert out["latency_s"] == 0.0
        client.chat.assert_not_called()

    def test_bracket_id_maps_to_real_issue_number(self):
        # Model answers with 1-based list ids, not real issue numbers.
        client = _client_returning(
            '{"standup":"ok","actions":[{"id":1,"label":"triage/ready",'
            '"rationale":"clear","ready":true}]}'
        )
        state = _state([_issue(42, "real number is 42")])
        out = decide.decide(client, state)
        assert out["actions"] == [{
            "number": 42, "repo": "o/watched", "label": "triage/ready",
            "rationale": "clear", "ready": True,
        }]

    def test_out_of_range_and_duplicate_ids_dropped(self):
        client = _client_returning(
            '{"standup":"s","actions":['
            '{"id":7,"label":"triage/ready","ready":true},'
            '{"id":1,"label":"triage/ready","ready":true},'
            '{"id":1,"label":"triage/blocked"}]}'
        )
        out = decide.decide(client, _state([_issue(5)]))
        assert [a["number"] for a in out["actions"]] == [5]

    def test_invalid_label_dropped(self):
        client = _client_returning(
            '{"standup":"s","actions":[{"id":1,"label":"triage/nonsense"}]}'
        )
        out = decide.decide(client, _state([_issue(5)]))
        assert out["actions"] == []

    def test_ready_only_true_for_ready_label(self):
        client = _client_returning(
            '{"standup":"s","actions":[{"id":1,"label":"triage/blocked","ready":true}]}'
        )
        out = decide.decide(client, _state([_issue(5)]))
        assert out["actions"][0]["ready"] is False

    def test_garbage_model_output_yields_no_actions(self):
        client = _client_returning("I cannot answer that.")
        out = decide.decide(client, _state([_issue(5)]))
        assert out["actions"] == []
        assert out["untriaged"] == 1
