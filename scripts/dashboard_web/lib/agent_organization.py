"""Agent organization snapshot builder for the dashboard."""

from __future__ import annotations

from collections import Counter
import re

_ACTIVE_STATUSES = {"in_progress", "submitted", "blocked"}


def _normalize_host(host: str) -> str:
    return (
        (host or "local")
        .lower()
        .replace("-", "")
        .replace("_", "")
        .replace(".lan", "")
        .replace(".local", "")
    )


def resolve_execution_peer(task: dict, plan: dict, host_to_peer: dict[str, str]) -> str:
    """Map executor_host / execution_host to a peer name."""
    raw = (
        task.get("executor_host")
        or plan.get("execution_peer")
        or plan.get("execution_host")
        or "local"
    )
    if raw in host_to_peer:
        return host_to_peer[raw]
    norm = _normalize_host(raw)
    for host, peer in host_to_peer.items():
        lhs = _normalize_host(host)
        if lhs == norm or lhs in norm or norm in lhs:
            return peer
    return raw or "local"


def infer_agent_role(task: dict) -> str:
    """Infer a live role for display purposes from task metadata."""
    text = " ".join(
        [
            task.get("task_id", ""),
            task.get("title", ""),
            task.get("executor_agent", ""),
            task.get("model", ""),
        ]
    ).lower()
    words = set(re.findall(r"[a-z0-9]+", text))
    if {"thor", "validate", "validator", "qa"} & words:
        return "validator"
    if {"review", "approve"} & words or "pullrequest" in words or "pr" in words:
        return "reviewer"
    if {"deploy", "release", "ship", "rollout", "production", "prod"} & words:
        return "deployer"
    if any(token in text for token in ("research", "analy", "investigat", "spike")):
        return "researcher"
    if {"plan", "planner"} & words or "orchestr" in text:
        return "planner"
    return "executor"


def build_agent_organization(mission_plans: list[dict], peers: list[dict]) -> dict:
    """Build a dashboard-friendly organization snapshot."""
    host_to_peer: dict[str, str] = {}
    peer_index: dict[str, dict] = {}
    for peer in peers:
        peer_name = peer.get("peer_name", "unknown")
        peer_index[peer_name] = peer
        host_to_peer[peer_name] = peer_name
        if peer.get("dns_name"):
            host_to_peer[peer["dns_name"]] = peer_name
        if peer.get("is_local"):
            host_to_peer["local"] = peer_name

    units: dict[str, dict] = {}

    def ensure_unit(peer_name: str) -> dict:
        if peer_name not in units:
            peer = peer_index.get(peer_name, {})
            units[peer_name] = {
                "peer_name": peer_name,
                "node_role": peer.get("role", "worker"),
                "is_online": peer.get("is_online", True),
                "cpu": peer.get("cpu", 0),
                "mem_used_gb": peer.get("mem_used_gb", 0),
                "mem_total_gb": peer.get("mem_total_gb", 0),
                "plan_ids": set(),
                "role_counts": Counter(),
                "agent_pods": {},
                "active_tasks": [],
            }
        return units[peer_name]

    for mission in mission_plans:
        plan = mission.get("plan", {})
        for task in mission.get("tasks", []):
            if task.get("status") not in _ACTIVE_STATUSES:
                continue
            peer_name = resolve_execution_peer(task, plan, host_to_peer)
            unit = ensure_unit(peer_name)
            role = infer_agent_role(task)
            pod_key = f"{task.get('executor_agent') or 'unassigned'}|{task.get('model') or ''}|{role}"
            unit["plan_ids"].add(plan.get("id"))
            unit["role_counts"][role] += 1
            pod = unit["agent_pods"].setdefault(
                pod_key,
                {
                    "agent": task.get("executor_agent") or "unassigned",
                    "model": task.get("model") or "",
                    "role": role,
                    "task_count": 0,
                },
            )
            pod["task_count"] += 1
            unit["active_tasks"].append(
                {
                    "plan_id": plan.get("id"),
                    "task_id": task.get("task_id") or "—",
                    "title": task.get("title") or "",
                    "status": task.get("status") or "pending",
                    "agent": task.get("executor_agent") or "unassigned",
                    "model": task.get("model") or "",
                    "role": role,
                }
            )

    for peer in peers:
        if peer.get("plans"):
            unit = ensure_unit(peer.get("peer_name", "unknown"))
            for plan in peer["plans"]:
                unit["plan_ids"].add(plan.get("id"))

    ordered_units = sorted(
        units.values(),
        key=lambda unit: (
            0 if unit["node_role"] == "coordinator" else 1,
            -len(unit["active_tasks"]),
            unit["peer_name"],
        ),
    )

    for unit in ordered_units:
        unit["plan_ids"] = sorted(pid for pid in unit["plan_ids"] if pid is not None)
        unit["role_counts"] = dict(unit["role_counts"])
        unit["agent_pods"] = sorted(
            unit["agent_pods"].values(),
            key=lambda pod: (-pod["task_count"], pod["role"], pod["agent"]),
        )
        unit["active_tasks"] = sorted(
            unit["active_tasks"],
            key=lambda task: (task["plan_id"] or 0, task["task_id"]),
        )

    return {
        "summary": {
            "nodes_total": len(ordered_units),
            "nodes_online": sum(1 for unit in ordered_units if unit["is_online"]),
            "plans_active": len(
                {
                    task["plan_id"]
                    for unit in ordered_units
                    for task in unit["active_tasks"]
                    if task["plan_id"] is not None
                }
            ),
            "agent_pods": sum(len(unit["agent_pods"]) for unit in ordered_units),
            "live_tasks": sum(len(unit["active_tasks"]) for unit in ordered_units),
        },
        "units": ordered_units,
    }
