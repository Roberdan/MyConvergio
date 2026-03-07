"""Tests for plan health preflight alerts."""

import json
import os
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent))

from lib.plan_health import detect_plan_health  # noqa: E402


def _base_plan():
    return {"id": 55, "status": "doing", "tasks_done": 0, "tasks_total": 2}


def test_detect_plan_health_reports_missing_preflight(monkeypatch, tmp_path):
    monkeypatch.setenv("HOME", str(tmp_path))
    alerts = detect_plan_health(
        _base_plan(),
        [{"wave_id": "W1", "name": "Core", "status": "in_progress"}],
        [{"task_id": "T1-01", "title": "Work", "status": "in_progress"}],
    )
    assert any(alert["code"] == "preflight_missing" for alert in alerts)


def test_detect_plan_health_reports_blocked_and_context(monkeypatch, tmp_path):
    monkeypatch.setenv("HOME", str(tmp_path))
    snapshot_dir = tmp_path / ".claude" / "data" / "execution-preflight"
    snapshot_dir.mkdir(parents=True)
    snapshot = {
        "generated_epoch": 4102444800,
        "warnings": ["dirty_worktree", "missing_troubleshooting"],
    }
    (snapshot_dir / "plan-55.json").write_text(json.dumps(snapshot), encoding="utf-8")

    alerts = detect_plan_health(
        _base_plan(),
        [{"wave_id": "W1", "name": "Core", "status": "in_progress"}],
        [{"task_id": "T1-01", "title": "Work", "status": "in_progress"}],
    )

    assert any(alert["code"] == "preflight_blocked" for alert in alerts)
    assert any(alert["code"] == "preflight_context" for alert in alerts)
