"""Tests for agent organization snapshot helpers."""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent))

from lib.agent_organization import (  # noqa: E402
    build_agent_organization,
    infer_agent_role,
    resolve_execution_peer,
)


def test_infer_agent_role_uses_task_intent():
    assert infer_agent_role({"title": "Thor validation"}) == "validator"
    assert infer_agent_role({"title": "PR review comments"}) == "reviewer"
    assert infer_agent_role({"title": "Deploy production"}) == "deployer"
    assert infer_agent_role({"title": "Research retry pattern"}) == "researcher"
    assert infer_agent_role({"title": "Planner handoff"}) == "planner"
    assert infer_agent_role({"title": "Implement endpoint"}) == "executor"


def test_resolve_execution_peer_matches_local_and_fuzzy_hosts():
    host_to_peer = {"local": "m3max", "builder1": "builder-1"}
    assert resolve_execution_peer({}, {"execution_host": "local"}, host_to_peer) == "m3max"
    assert (
        resolve_execution_peer(
            {"executor_host": "builder-1.local"},
            {"execution_host": "local"},
            host_to_peer,
        )
        == "builder-1"
    )


def test_build_agent_organization_groups_units_and_tasks():
    mission_plans = [
        {
            "plan": {"id": 101, "execution_host": "local", "execution_peer": "m3max"},
            "tasks": [
                {
                    "task_id": "T1-01",
                    "title": "Implement endpoint",
                    "status": "in_progress",
                    "executor_agent": "copilot",
                    "executor_host": "local",
                    "model": "gpt-5.3-codex",
                },
                {
                    "task_id": "T1-02",
                    "title": "Thor validation",
                    "status": "submitted",
                    "executor_agent": "thor",
                    "executor_host": "builder-1",
                    "model": "claude-sonnet-4.6",
                },
                {
                    "task_id": "T1-03",
                    "title": "PR review comments",
                    "status": "blocked",
                    "executor_agent": "copilot",
                    "executor_host": "review-box",
                    "model": "gpt-5.4",
                },
            ],
        }
    ]
    peers = [
        {
            "peer_name": "m3max",
            "role": "coordinator",
            "is_local": True,
            "is_online": True,
            "cpu": 18,
            "mem_used_gb": 6,
            "mem_total_gb": 36,
            "plans": [{"id": 101}],
        },
        {
            "peer_name": "builder-1",
            "role": "worker",
            "is_online": True,
            "cpu": 44,
            "mem_used_gb": 8,
            "mem_total_gb": 16,
            "plans": [{"id": 101}],
        },
        {
            "peer_name": "review-box",
            "role": "worker",
            "is_online": False,
            "cpu": 0,
            "mem_used_gb": 0,
            "mem_total_gb": 16,
        },
    ]

    snapshot = build_agent_organization(mission_plans, peers)

    assert snapshot["summary"] == {
        "nodes_total": 3,
        "nodes_online": 2,
        "plans_active": 1,
        "agent_pods": 3,
        "live_tasks": 3,
    }
    assert snapshot["units"][0]["peer_name"] == "m3max"
    assert snapshot["units"][0]["node_role"] == "coordinator"
    assert snapshot["units"][1]["agent_pods"][0]["role"] == "validator"
    assert snapshot["units"][2]["active_tasks"][0]["role"] == "reviewer"


def test_server_registers_organization_route():
    server_src = (Path(__file__).parent.parent / "server.py").read_text(encoding="utf-8")
    assert '"/api/organization"' in server_src
