"""Mesh Handoff — plan delegation between nodes. Public API: full_handoff, check_stale_host, pull_db_from_peer."""

import time

from mesh_handoff_core import (
    acquire_lock,
    detect_sync_source,
    release_lock,
    resolve_cli,
    _sql,
    _ssh,
)
from mesh_handoff_sync import (
    check_stale_host,
    pull_db_from_peer,
    reverse_sync,
    sync_files_to_target,
)


def stop_remote_execution(
    ssh_dest: str, plan_id: int, worktree: str
) -> tuple[bool, str]:
    """Stop execution on remote node. Stash WIP, kill tmux session."""
    steps = []
    sn, wn = "Convergio", f"plan-{plan_id}"
    try:
        r = _ssh(
            ssh_dest,
            f"tmux has-session -t {sn} 2>/dev/null "
            f"&& tmux list-windows -t {sn} -F '#{{window_name}}' 2>/dev/null "
            f"| grep -q '{wn}' && tmux send-keys -t {sn}:{wn} C-c 2>/dev/null "
            f"&& sleep 2 && tmux kill-window -t {sn}:{wn} 2>/dev/null "
            f"&& echo KILLED || echo NO_WINDOW",
            timeout=10,
        )
        steps.append(
            f"tmux window '{wn}' killed"
            if "KILLED" in r.stdout
            else "no active plan window in tmux"
        )
    except Exception:
        steps.append("tmux check failed (non-blocking)")
    wt = worktree.replace("~", "$HOME")
    if wt:
        try:
            r = _ssh(
                ssh_dest,
                f"cd {wt} 2>/dev/null && git add -A 2>/dev/null && "
                f"git stash push -m 'mesh-handoff-{plan_id}-{int(time.time())}' "
                f"2>/dev/null && echo STASHED || echo CLEAN",
                timeout=15,
            )
            steps.append("WIP stashed" if "STASHED" in r.stdout else "worktree clean")
        except Exception:
            steps.append("stash failed (may lose uncommitted work)")
    try:
        _ssh(
            ssh_dest,
            f"sqlite3 ~/.claude/data/dashboard.db '.timeout 5000' "
            f"\"UPDATE tasks SET status='pending' WHERE status='in_progress' AND plan_id={plan_id};\"",
            timeout=10,
        )
        steps.append("in_progress tasks reset to pending")
    except Exception:
        steps.append("task reset failed")
    return True, "; ".join(steps)


def full_handoff(
    plan_id: int, target: str, find_peer: callable, log: callable, cli: str = "copilot"
) -> tuple[bool, str]:
    """Complete handoff protocol. log(msg) called for SSE streaming."""
    ok, detail = acquire_lock(plan_id, target)
    if not ok:
        return False, f"Lock failed: {detail}"
    log("🔒 Delegation lock acquired")
    try:
        return _do_handoff(plan_id, target, find_peer, log, cli=cli)
    finally:
        release_lock(plan_id)
        log("🔓 Lock released")


def _do_handoff(
    plan_id: int, target: str, find_peer: callable, log: callable, cli: str = "copilot"
) -> tuple[bool, str]:
    """Inner handoff logic (lock already held)."""
    info = detect_sync_source(plan_id, target, find_peer)
    ssh_target = info["ssh_target"]
    log(f"📍 Source: {info['source']}  Target: {ssh_target}")
    if info["worktree"]:
        log(f"📍 Worktree: {info['worktree']}")

    if info["source"] == "same_node":
        log("✓ Plan already on target node — skipping transfer")
        has_ip = _sql(
            f"SELECT COUNT(*) FROM tasks WHERE plan_id={plan_id} AND status='in_progress';"
        )
        plan_status = _sql(f"SELECT status FROM plans WHERE id={plan_id};")
        if plan_status in ("todo", "doing") and int(has_ip or 0) == 0:
            _launch_on_target(plan_id, target, ssh_target, info, log, cli)
            return True, f"Plan #{plan_id} launched on {target}"
        return True, "already running on target"

    if info["needs_stop"] and info["ssh_source"]:
        log(f"⏸ Stopping execution on {info['source']}…")
        ok, detail = stop_remote_execution(
            info["ssh_source"], plan_id, info["worktree"]
        )
        log(f"  → {detail}")
        if not ok:
            return False, f"Failed to stop: {detail}"

    log(f"▶ Verifying SSH to {ssh_target}")
    try:
        r = _ssh(ssh_target, "echo ok", timeout=8)
        if r.returncode != 0:
            return False, f"SSH to {ssh_target} failed"
    except Exception as e:
        return False, f"SSH error: {e}"
    log("  ✓ Connected")
    try:
        _ssh(ssh_target, "mkdir -p ~/.claude/data ~/.claude/config", timeout=8)
    except Exception:
        pass

    ok, err = sync_files_to_target(info, ssh_target, target, plan_id, log)
    if not ok:
        return False, err
    # Transfer ownership: set execution_host on both coordinator and target
    log(f"▶ Transferring ownership to {target}")
    try:
        _ssh(
            ssh_target,
            f"sqlite3 ~/.claude/data/dashboard.db '.timeout 5000' "
            f"\"UPDATE plans SET execution_host='{target}' WHERE id={plan_id}; "
            f"UPDATE tasks SET status='pending' WHERE status='in_progress' AND plan_id={plan_id};\"",
            timeout=10,
        )
    except Exception:
        pass
    _sql(f"UPDATE plans SET execution_host='{target}' WHERE id={plan_id};")
    _sql(
        f"UPDATE tasks SET status='pending' WHERE status='in_progress' AND plan_id={plan_id};"
    )
    log(f"  ✓ execution_host = {target}")
    _launch_on_target(plan_id, target, ssh_target, info, log, cli)
    return True, f"Plan #{plan_id} handed off to {target}"


def _launch_on_target(
    plan_id: int, target: str, ssh_target: str, info: dict, log, cli: str = "copilot"
):
    """Launch plan execution in a tmux window on the target node."""
    log(f"▶ Launching plan #{plan_id} on {target}")
    wn = f"plan-{plan_id}"
    work_dir = (
        _sql(f"SELECT COALESCE(worktree_path,'') FROM plans WHERE id={plan_id};")
        or "~/.claude"
    )
    if work_dir.startswith("~") and info.get("worktree"):
        try:
            r = _ssh(ssh_target, "echo $HOME", timeout=5)
            if r.stdout.strip():
                work_dir = work_dir.replace("~", r.stdout.strip())
        except Exception:
            pass
    cli_cmd = resolve_cli(cli, ssh_target, log)
    if not cli_cmd:
        log("  ⚠ No CLI found on target — plan transferred but needs manual /execute")
        return
    launch = (
        f"cd {work_dir} 2>/dev/null || cd ~/.claude; {cli_cmd} -p '/execute {plan_id}'"
    )
    try:
        _ssh(
            ssh_target,
            f"tmux new-session -A -d -s Convergio 2>/dev/null; "
            f"tmux new-window -t Convergio -n '{wn}'; sleep 0.5; "
            f"tmux send-keys -t Convergio:{wn} '{launch}' Enter",
            timeout=10,
        )
        r = _ssh(
            ssh_target,
            f"tmux list-windows -t Convergio -F '#{{window_name}}' 2>/dev/null",
            timeout=5,
        )
        if wn in r.stdout:
            log(f"  ✓ Convergio:{wn} → {cli_cmd}")
            log(f"  ✓ Working dir: {work_dir}")
        else:
            log("  ⚠ Window not confirmed — check with: tlm / tlx")
    except Exception as e:
        log(f"  ⚠ Launch failed: {str(e)[:60]}")
