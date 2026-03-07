import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent))


def test_reconcile_progress_uses_tasks_as_source_of_truth():
    from api_dashboard import _reconcile_progress

    plan = {"id": 1, "tasks_done": 99, "tasks_total": 99}
    waves = [
        {"wave_id": "W1", "tasks_done": 10, "tasks_total": 10},
        {"wave_id": "W2", "tasks_done": 5, "tasks_total": 5},
    ]
    tasks = [
        {"task_id": "T1", "wave_id": "W1", "status": "done"},
        {"task_id": "T2", "wave_id": "W1", "status": "in_progress"},
        {"task_id": "T3", "wave_id": "W2", "status": "done"},
    ]

    normalized_plan, normalized_waves = _reconcile_progress(plan, waves, tasks)

    assert normalized_plan["tasks_done"] == 2
    assert normalized_plan["tasks_total"] == 3
    assert normalized_waves == [
        {"wave_id": "W1", "tasks_done": 1, "tasks_total": 2},
        {"wave_id": "W2", "tasks_done": 1, "tasks_total": 1},
    ]


def test_remote_process_query_uses_task_counts():
    from lib import mesh_helpers

    assert "COUNT(*) FROM tasks tx WHERE tx.plan_id=p.id AND tx.status=''done''" in mesh_helpers._REMOTE_PROCS_CMD
    assert "COUNT(*) FROM tasks tx WHERE tx.plan_id=p.id" in mesh_helpers._REMOTE_PROCS_CMD


def test_merge_task_tokens_backfills_from_attributed_usage(monkeypatch):
    from api_dashboard import _merge_task_tokens

    def fake_query(sql, _params=()):
        if "FROM token_usage" in sql:
            return [{"task_id": "T1-01", "tokens": 4200}]
        if "FROM delegation_log" in sql:
            return []
        return []

    monkeypatch.setattr("api_dashboard.query", fake_query)
    tasks = [
        {"id": 101, "task_id": "T1-01", "tokens": 0},
        {"id": 102, "task_id": "T1-02", "tokens": 185},
    ]

    merged = _merge_task_tokens(10, tasks)

    assert merged[0]["tokens"] == 4200
    assert merged[1]["tokens"] == 185


def test_merge_task_tokens_backfills_from_delegation_log(monkeypatch):
    from api_dashboard import _merge_task_tokens

    def fake_query(sql, _params=()):
        if "FROM token_usage" in sql:
            return []
        if "FROM delegation_log" in sql:
            return [{"task_db_id": 101, "tokens": 3600}]
        return []

    monkeypatch.setattr("api_dashboard.query", fake_query)
    tasks = [{"id": 101, "task_id": "T1-01", "tokens": 0}]

    merged = _merge_task_tokens(10, tasks)

    assert merged[0]["tokens"] == 3600
