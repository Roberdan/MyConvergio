import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent))

from lib.live_runtime import build_live_system_snapshot  # noqa: E402


def test_live_runtime_prefers_telemetry_runs_and_handoffs():
    snapshot = build_live_system_snapshot(
        mission_plans=[],
        peers=[
            {"peer_name": "m3max", "role": "coordinator", "is_online": True, "cpu": 10},
            {"peer_name": "builder-1", "role": "worker", "is_online": True, "cpu": 40},
        ],
        agent_runs=[
            {
                "id": 1,
                "plan_id": 42,
                "wave_id": "W1",
                "task_id": "T1",
                "agent_name": "planner",
                "agent_role": "planner",
                "model": "claude-opus-4.6",
                "peer_name": "m3max",
                "status": "running",
                "started_at": "2026-03-07 09:00:00",
                "last_heartbeat": "2026-03-07 09:00:01",
                "current_task": "T1",
            },
            {
                "id": 2,
                "plan_id": 42,
                "wave_id": "W1",
                "task_id": "T2",
                "agent_name": "executor",
                "agent_role": "executor",
                "model": "gpt-5.3-codex",
                "peer_name": "builder-1",
                "status": "handoff",
                "started_at": "2026-03-07 09:00:00",
                "last_heartbeat": "2026-03-07 09:00:02",
                "current_task": "T2",
            },
        ],
        task_events=[
            {
                "id": 7,
                "plan_id": 42,
                "task_id": "T2",
                "event_type": "handoff_requested",
                "message": "planner delegated T2",
                "source_agent": "planner",
                "target_agent": "executor",
                "peer_name": "builder-1",
                "created_at": "2026-03-07 09:00:03",
            }
        ],
        handoffs=[
            {
                "from_run_id": 1,
                "to_run_id": 2,
                "handoff_kind": "delegate",
                "status": "proposed",
                "task_id": "T2",
            }
        ],
    )

    assert snapshot["summary"]["active_runs"] == 2
    assert snapshot["summary"]["open_handoffs"] == 1
    assert any(edge["kind"] == "delegate" for edge in snapshot["synapses"])
    assert snapshot["recent_events"][0]["event_type"] == "handoff_requested"


def test_live_runtime_falls_back_to_mission_tasks():
    snapshot = build_live_system_snapshot(
        mission_plans=[
            {
                "plan": {"id": 9, "execution_host": "local", "execution_peer": "m3max"},
                "tasks": [
                    {
                        "task_id": "T9-01",
                        "title": "Implement feature",
                        "status": "in_progress",
                        "executor_agent": "copilot",
                        "executor_host": "local",
                        "model": "gpt-5.4",
                        "wave_id": "W1",
                    }
                ],
            }
        ],
        peers=[{"peer_name": "m3max", "role": "coordinator", "is_local": True, "is_online": True, "cpu": 5}],
        agent_runs=[],
        task_events=[],
        handoffs=[],
    )

    assert snapshot["summary"]["active_runs"] == 1
    assert snapshot["run_nodes"][0]["source"] == "mission"
    assert snapshot["synapses"][0]["source"] == "peer:m3max"


def test_server_registers_live_system_route():
    server_src = (Path(__file__).parent.parent / "server.py").read_text(encoding="utf-8")
    assert '"/api/live-system"' in server_src
