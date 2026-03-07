"""Plan health detection helpers for api_dashboard.py."""

import json
import time
from pathlib import Path

_MANUAL_KEYWORDS = (
    "manual test",
    "manual review",
    "manual deploy",
    "visual qa",
    "user acceptance",
    "manual approval",
)


def detect_plan_health(plan: dict, waves: list, tasks: list) -> list[dict]:
    """Detect health issues for a plan. Returns list of {severity, code, message}."""
    alerts = []
    if plan["status"] != "doing":
        return alerts
    done_count = plan.get("tasks_done") or 0
    total_count = plan.get("tasks_total") or 0
    blocked = [t for t in tasks if t["status"] == "blocked"]
    in_progress = [t for t in tasks if t["status"] == "in_progress"]
    pending = [t for t in tasks if t["status"] == "pending"]
    submitted = [t for t in tasks if t["status"] == "submitted"]

    if blocked:
        alerts.append(
            {
                "severity": "critical",
                "code": "blocked",
                "message": f"{len(blocked)} task bloccati: {', '.join(t['task_id'] for t in blocked[:3])}",
            }
        )

    if not in_progress and not submitted and done_count < total_count and pending:
        alerts.append(
            {
                "severity": "critical",
                "code": "stale",
                "message": f"Piano fermo: {len(pending)} task pending, nessuno in esecuzione",
            }
        )

    done_waves = [w for w in waves if w["status"] == "done"]
    pending_waves = [w for w in waves if w["status"] == "pending"]
    if done_waves and pending_waves:
        last_pending = pending_waves[0]
        wid = (last_pending.get("wave_id") or "").lower()
        wname = (last_pending.get("name") or "").lower()
        if any(k in wid + wname for k in ("deploy", "closure", "release", "prod")):
            alerts.append(
                {
                    "severity": "warning",
                    "code": "stuck_deploy",
                    "message": f"Wave deploy '{last_pending['wave_id']}' non partita ({len(done_waves)} wave completate)",
                }
            )

    manual_tasks = [
        t
        for t in pending
        if any(k in (t.get("title") or "").lower() for k in _MANUAL_KEYWORDS)
    ]
    if manual_tasks:
        alerts.append(
            {
                "severity": "warning",
                "code": "manual_required",
                "message": f"{len(manual_tasks)} task richiedono intervento: {', '.join(t['task_id'] for t in manual_tasks[:3])}",
            }
        )

    thor_stuck = [t for t in submitted if not t.get("validated_at")]
    if thor_stuck:
        alerts.append(
            {
                "severity": "warning",
                "code": "thor_stuck",
                "message": f"{len(thor_stuck)} task in attesa Thor: {', '.join(t['task_id'] for t in thor_stuck[:3])}",
            }
        )

    if total_count > 0:
        pct = round(100 * done_count / total_count)
        if pct >= 80 and pending and not in_progress and not submitted:
            alerts.append(
                {
                    "severity": "warning",
                    "code": "near_complete_stuck",
                    "message": f"{pct}% completato ma {len(pending)} task pending non avviati",
                }
            )

    snapshot = (
        Path.home()
        / ".claude"
        / "data"
        / "execution-preflight"
        / f"plan-{plan['id']}.json"
    )
    if snapshot.exists():
        try:
            data = json.loads(snapshot.read_text(encoding="utf-8"))
            age = int(time.time() - int(data.get("generated_epoch") or 0))
            warnings = set(data.get("warnings") or [])
            if age > 1800:
                alerts.append(
                    {
                        "severity": "warning",
                        "code": "preflight_stale",
                        "message": f"Execution preflight stale ({age // 60}m)",
                    }
                )
            if "dirty_worktree" in warnings or "gh_auth_not_ready" in warnings:
                alerts.append(
                    {
                        "severity": "critical",
                        "code": "preflight_blocked",
                        "message": "Execution readiness blocked: dirty worktree or GH auth not ready",
                    }
                )
            if "missing_troubleshooting" in warnings or "missing_ci_knowledge" in warnings:
                alerts.append(
                    {
                        "severity": "warning",
                        "code": "preflight_context",
                        "message": "Operational docs missing: troubleshooting or CI knowledge",
                    }
                )
        except Exception:
            alerts.append(
                {
                    "severity": "warning",
                    "code": "preflight_stale",
                    "message": "Execution preflight snapshot unreadable",
                }
            )
    else:
        alerts.append(
            {
                "severity": "warning",
                "code": "preflight_missing",
                "message": "Execution preflight snapshot missing",
            }
        )

    return alerts
