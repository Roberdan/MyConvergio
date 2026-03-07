import os
import sqlite3
import subprocess
import sys
from pathlib import Path

if __package__ in (None, ""):
    sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
    from scripts.dashboard_web.api_mesh import find_peer_conf, local_peer_name
    from scripts.dashboard_web.api_plans_checks import (
        check_cli_tools,
        check_disk,
        check_heartbeat,
    )
    from scripts.dashboard_web.api_plans_preflight import (
        build_candidates,
        check_rsync,
        resolve_ssh_dest,
        sync_config,
        sync_db,
    )
    from scripts.dashboard_web.lib.sse import run_command_sse
    from scripts.dashboard_web.middleware import DB_PATH, query_one
else:
    from .api_mesh import find_peer_conf, local_peer_name
    from .api_plans_checks import check_cli_tools, check_disk, check_heartbeat
    from .api_plans_preflight import (
        build_candidates,
        check_rsync,
        resolve_ssh_dest,
        sync_config,
        sync_db,
    )
    from .lib.sse import run_command_sse
    from .middleware import DB_PATH, query_one


def api_preflight_sse(handler, qs: dict):
    plan_id, target = qs.get("plan_id", [""])[0], qs.get("target", [""])[0]
    cli_engine = qs.get("cli", [""])[0]
    if not plan_id or not target:
        handler._json_response({"error": "missing plan_id or target"}, 400)
        return
    all_ok = True
    handler._start_sse()
    handler._sse_send(
        "start", {"plan_id": plan_id, "target": target, "total_checks": 9}
    )

    def _check(name: str, ok: bool, detail: str, blocking: bool = True):
        nonlocal all_ok
        if not ok and blocking:
            all_ok = False
        handler._sse_send(
            "check", {"name": name, "ok": ok, "detail": detail, "blocking": blocking}
        )

    pc = find_peer_conf(target)
    handler._sse_send("checking", {"name": "SSH reachable"})
    candidates = build_candidates(target, pc)
    ssh_dest = resolve_ssh_dest(target, pc, handler)
    if not ssh_dest:
        _check("SSH reachable", False, "all candidates unreachable")
        handler._sse_send("done", {"ok": False})
        return
    label = next((l for l, d in candidates if d == ssh_dest), "?")
    _check("SSH reachable", True, f"{target} via {ssh_dest} ({label}) ✓")
    check_rsync(handler, ssh_dest, pc.get("os", "unknown") if pc else "unknown", _check)

    handler._sse_send("checking", {"name": "Plan status"})
    plan = query_one(
        "SELECT id,name,status,execution_host FROM plans WHERE id=?", (int(plan_id),)
    )
    if not plan:
        _check("Plan status", False, "Not found in DB")
        handler._sse_send("done", {"ok": False})
        return
    active = plan["status"] in ("todo", "doing")
    _check(
        "Plan status",
        active,
        f"#{plan_id} is '{plan['status']}'"
        + ("" if active else " — must be todo/doing"),
    )

    check_heartbeat(handler, ssh_dest, target, _check, query_one)
    sync_config(handler, ssh_dest, _check)
    sync_db(handler, ssh_dest, _check)

    engine = cli_engine or (pc.get("default_engine") if pc else "") or "copilot"
    check_cli_tools(handler, ssh_dest, engine, _check)
    check_disk(handler, ssh_dest, _check)
    handler._sse_send("done", {"ok": all_ok})


def handle_plan_delegate(handler, qs: dict, safe_name):
    plan_id, target, cli_choice = (
        qs.get("plan_id", [""])[0],
        qs.get("target", [""])[0],
        qs.get("cli", ["copilot"])[0],
    )
    if not plan_id or not plan_id.isdigit() or not target:
        handler._json_response({"error": "missing plan_id or target"}, 400)
        return
    if not safe_name.match(target):
        handler._json_response({"error": "invalid target name"}, 400)
        return
    handler._start_sse()
    try:
        from mesh_handoff import check_stale_host, full_handoff

        handler._sse_send("phase", {"name": "handoff"})
        handler._sse_send("log", f"━━━ HANDOFF: Plan #{plan_id} → {target} ━━━")
        handler._sse_send("log", "")
        stale = check_stale_host(int(plan_id), find_peer_conf)
        if stale["stale"]:
            handler._sse_send(
                "log", f"⚠ Previous host '{stale['host']}' is stale: {stale['reason']}"
            )
            handler._sse_send(
                "log",
                (
                    "  → Will recover and re-delegate"
                    if stale["can_recover"]
                    else "  → Host unreachable — forcing re-delegation"
                ),
            )
            handler._sse_send("log", "")
        ok, summary = full_handoff(
            int(plan_id),
            target,
            find_peer_conf,
            lambda msg: handler._sse_send("log", msg),
            cli=cli_choice,
        )
        handler._sse_send("log", "")
        handler._sse_send("log", f"✓ {summary}" if ok else f"✗ {summary}")
        handler._sse_send(
            "done" if ok else "error",
            (
                {"ok": ok, "plan_id": int(plan_id), "target": target}
                if ok
                else {"ok": False, "message": summary}
            ),
        )
    except ImportError as e:
        handler._sse_send(
            "error", {"ok": False, "message": f"Handoff module error: {e}"}
        )
    except Exception as e:
        handler._sse_send("error", {"ok": False, "message": str(e)})


def handle_plan_start_sse(handler, qs: dict):
    plan_id, cli, target, model = (
        qs.get("plan_id", [""])[0],
        qs.get("cli", ["copilot"])[0],
        qs.get("target", ["local"])[0],
        qs.get("model", ["gpt-5.3-codex"])[0],
    )
    if not plan_id or not plan_id.isdigit():
        handler._json_response({"error": "missing plan_id"}, 400)
        return
    handler._start_sse()
    handler._sse_send("log", f"▶ Starting plan #{plan_id} with {cli}")
    try:
        hostname = subprocess.run(
            ["hostname", "-s"], capture_output=True, text=True, timeout=5
        ).stdout.strip()
        with sqlite3.connect(str(DB_PATH), timeout=5) as conn:
            conn.execute(
                "UPDATE plans SET status='doing', execution_host=? WHERE id=? AND status IN ('todo','doing')",
                (target if target != "local" else hostname, int(plan_id)),
            )
        handler._sse_send(
            "log", f"✓ Plan claimed by {target if target != 'local' else hostname}"
        )
    except Exception as e:
        handler._sse_send("log", f"✗ DB update failed: {e}")
        handler._sse_send("done", {"ok": False, "message": str(e)})
        return
    scripts = Path.home() / ".claude" / "scripts"
    if __package__ in (None, ""):
        from scripts.dashboard_web.api_mesh import peer_host_match
    else:
        from .api_mesh import peer_host_match

    if target == "local" or peer_host_match(local_peer_name(), target):
        cmd = (
            f'claude --model sonnet -p "/execute {plan_id}"'
            if cli == "claude"
            else f'copilot -p "/execute {plan_id}" --model {model}'
        )
        handler._sse_send("log", f"▶ Running locally: {cmd}")
        run_command_sse(
            handler,
            cmd,
            timeout=600,
            env={
                **os.environ,
                "PATH": str(scripts)
                + ":/opt/homebrew/bin:/usr/local/bin:"
                + os.environ.get("PATH", ""),
            },
            cwd=str(Path.home() / ".claude"),
        )
    else:
        handler._sse_send("log", f"▶ Delegating to {target}")
        try:
            from mesh_handoff import full_handoff

            ok, summary = full_handoff(
                int(plan_id),
                target,
                find_peer_conf,
                lambda msg: handler._sse_send("log", msg),
                cli=cli,
            )
            handler._sse_send("done", {"ok": ok, "message": summary})
        except Exception as e:
            handler._sse_send("done", {"ok": False, "message": str(e)})
