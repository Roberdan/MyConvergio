"""Live orchestration snapshot builder for the dashboard."""

from __future__ import annotations

from collections import defaultdict
from datetime import datetime, timezone

ACTIVE_RUN_STATUSES = {"queued", "running", "waiting", "handoff", "validating", "blocked"}
TASK_STATUS_TO_RUN_STATUS = {
    "in_progress": "running",
    "submitted": "validating",
    "blocked": "blocked",
}


def _parse_ts(value: str | None) -> int | None:
    if not value:
        return None
    try:
        return int(datetime.fromisoformat(value.replace("Z", "+00:00")).timestamp())
    except ValueError:
        return None


def _normalize_peer(raw: str | None, peers: list[dict]) -> str:
    if not raw:
        return "local"
    norm = (
        raw.lower()
        .replace("-", "")
        .replace("_", "")
        .replace(".lan", "")
        .replace(".local", "")
    )
    for peer in peers:
        for candidate in (
            peer.get("peer_name"),
            peer.get("dns_name"),
            peer.get("ssh_alias"),
            "local" if peer.get("is_local") else None,
        ):
            if not candidate:
                continue
            lhs = (
                candidate.lower()
                .replace("-", "")
                .replace("_", "")
                .replace(".lan", "")
                .replace(".local", "")
            )
            if lhs == norm or lhs in norm or norm in lhs:
                return peer.get("peer_name", raw)
    return raw


def _run_label(run: dict) -> str:
    task_id = run.get("task_id") or run.get("current_task")
    if task_id:
        return f"{run.get('agent_name', 'agent')} · {task_id}"
    return run.get("agent_name") or "agent"


def build_live_system_snapshot(
    mission_plans: list[dict],
    peers: list[dict],
    agent_runs: list[dict],
    task_events: list[dict],
    handoffs: list[dict],
) -> dict:
    peer_nodes = []
    peer_index = {}
    for peer in peers:
        entry = {
            "id": f"peer:{peer.get('peer_name', 'unknown')}",
            "peer_name": peer.get("peer_name", "unknown"),
            "role": peer.get("role", "worker"),
            "is_online": bool(peer.get("is_online", True)),
            "cpu": peer.get("cpu", 0),
            "active_tasks": peer.get("active_tasks", 0),
        }
        peer_nodes.append(entry)
        peer_index[entry["peer_name"]] = entry

    run_nodes = []
    seen_run_ids: set[str] = set()
    for run in agent_runs:
        status = run.get("status") or "running"
        if status not in ACTIVE_RUN_STATUSES:
            continue
        run_id = f"run:{run.get('id')}"
        seen_run_ids.add(run_id)
        peer_name = _normalize_peer(run.get("peer_name"), peers)
        run_nodes.append(
            {
                "id": run_id,
                "label": _run_label(run),
                "agent_name": run.get("agent_name") or "agent",
                "role": run.get("agent_role") or "executor",
                "model": run.get("model") or "",
                "status": status,
                "peer_name": peer_name,
                "plan_id": run.get("plan_id"),
                "wave_id": run.get("wave_id"),
                "task_id": run.get("task_id"),
                "last_seen": _parse_ts(run.get("last_heartbeat")) or _parse_ts(run.get("started_at")),
                "source": "telemetry",
            }
        )

    if not run_nodes:
        for mission in mission_plans:
            plan = mission.get("plan", {})
            for task in mission.get("tasks", []):
                if task.get("status") not in TASK_STATUS_TO_RUN_STATUS:
                    continue
                run_nodes.append(
                    {
                        "id": f"task:{plan.get('id')}:{task.get('task_id')}",
                        "label": f"{task.get('executor_agent') or 'agent'} · {task.get('task_id')}",
                        "agent_name": task.get("executor_agent") or "agent",
                        "role": "validator" if task.get("status") == "submitted" else "executor",
                        "model": task.get("model") or "",
                        "status": TASK_STATUS_TO_RUN_STATUS[task["status"]],
                        "peer_name": _normalize_peer(
                            task.get("executor_host")
                            or plan.get("execution_peer")
                            or plan.get("execution_host"),
                            peers,
                        ),
                        "plan_id": plan.get("id"),
                        "wave_id": task.get("wave_id"),
                        "task_id": task.get("task_id"),
                        "last_seen": None,
                        "source": "mission",
                    }
                )

    synapses = []
    for run in run_nodes:
        synapses.append(
            {
                "source": f"peer:{run['peer_name']}",
                "target": run["id"],
                "kind": "assignment",
                "status": run["status"],
            }
        )

    for handoff in handoffs:
        source = f"run:{handoff.get('from_run_id')}"
        target = f"run:{handoff.get('to_run_id')}"
        if source in seen_run_ids or target in seen_run_ids:
            synapses.append(
                {
                    "source": source,
                    "target": target,
                    "kind": handoff.get("handoff_kind") or "delegate",
                    "status": handoff.get("status") or "proposed",
                    "task_id": handoff.get("task_id"),
                }
            )

    recent_events = []
    for event in task_events[:40]:
        recent_events.append(
            {
                "id": event.get("id"),
                "event_type": event.get("event_type") or "event",
                "status": event.get("status") or "",
                "message": event.get("message") or "",
                "source_agent": event.get("source_agent") or "",
                "target_agent": event.get("target_agent") or "",
                "plan_id": event.get("plan_id"),
                "task_id": event.get("task_id"),
                "peer_name": _normalize_peer(event.get("peer_name"), peers),
                "created_at": _parse_ts(event.get("created_at")),
            }
        )

    active_by_peer: dict[str, int] = defaultdict(int)
    for run in run_nodes:
        active_by_peer[run["peer_name"]] += 1
    for peer in peer_nodes:
        peer["active_runs"] = active_by_peer.get(peer["peer_name"], 0)

    return {
        "summary": {
            "peer_nodes": len(peer_nodes),
            "online_peers": sum(1 for peer in peer_nodes if peer["is_online"]),
            "active_runs": len(run_nodes),
            "open_handoffs": sum(
                1 for handoff in handoffs if handoff.get("status") not in {"accepted", "completed", "rejected"}
            ),
            "recent_events": len(recent_events),
        },
        "peer_nodes": peer_nodes,
        "run_nodes": run_nodes,
        "synapses": synapses,
        "recent_events": recent_events,
        "generated_at": int(datetime.now(tz=timezone.utc).timestamp()),
    }
