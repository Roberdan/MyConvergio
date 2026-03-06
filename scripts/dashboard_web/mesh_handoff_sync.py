"""Mesh Handoff Sync — DB pull/push, reverse sync, file sync, crash recovery."""

import os
import subprocess
import time
from pathlib import Path

from mesh_handoff_core import (
    CLAUDE_HOME,
    DB_PATH,
    SSH_OPTS,
    _parse_all_peers,
    _rsync,
    _sql,
    _ssh,
    get_execution_host,
)


def pull_db_from_peer(
    ssh_dest: str, plan_ids: list[int], timeout: int = 60
) -> tuple[bool, str]:
    """Pull dashboard.db from remote peer and merge task statuses (status-upgrade only)."""
    import tempfile

    tmp = tempfile.mktemp(suffix=".db")
    try:
        _ssh(
            ssh_dest,
            "sqlite3 ~/.claude/data/dashboard.db 'PRAGMA wal_checkpoint(TRUNCATE);'",
            timeout=10,
        )
        r = subprocess.run(
            [
                "scp",
                "-o",
                "ConnectTimeout=10",
                "-o",
                "BatchMode=yes",
                f"{ssh_dest}:~/.claude/data/dashboard.db",
                tmp,
            ],
            capture_output=True,
            text=True,
            timeout=timeout,
        )
        if r.returncode != 0:
            return False, f"scp failed: {r.stderr.strip()[:60]}"
        for pid in plan_ids:
            _merge_plan_status(pid, tmp)
        return True, f"{len(plan_ids)} plan(s) synced from {ssh_dest}"
    except subprocess.TimeoutExpired:
        return False, f"timeout ({timeout}s)"
    except Exception as e:
        return False, str(e)[:60]
    finally:
        if os.path.exists(tmp):
            os.unlink(tmp)


def reverse_sync(ssh_source: str, plan_id: int, log: callable) -> tuple[bool, str]:
    """Pull completed work FROM worker back to coordinator."""
    worktree = _sql(f"SELECT COALESCE(worktree_path,'') FROM plans WHERE id={plan_id};")
    if worktree:
        wt_local = worktree.replace("~", str(Path.home()))
        log(f"▶ Pulling worktree from {ssh_source}")
        ok, detail = _rsync(f"{ssh_source}:{worktree}/", f"{wt_local}/", delete=False)
        log(f"  → {detail}")
    log(f"▶ Pulling DB from {ssh_source}")
    ok, detail = pull_db_from_peer(ssh_source, [plan_id])
    log(f"  → {detail}")
    local_host = subprocess.run(
        ["hostname", "-s"], capture_output=True, text=True, timeout=5
    ).stdout.strip()
    _sql(f"UPDATE plans SET execution_host='{local_host}' WHERE id={plan_id};")
    log("  ✓ execution_host returned to coordinator")
    return True, "reverse sync complete"


def _merge_plan_status(plan_id: int, remote_db: str):
    """Merge task/wave statuses from remote DB into local (status-upgrade only)."""
    import sqlite3 as _sqlite3

    rank = {
        "pending": 0,
        "in_progress": 1,
        "blocked": 1,
        "submitted": 2,
        "done": 3,
        "skipped": 3,
    }
    remote = _sqlite3.connect(remote_db, timeout=5)
    remote.row_factory = _sqlite3.Row
    local = _sqlite3.connect(str(DB_PATH), timeout=10)
    local.execute("PRAGMA journal_mode=WAL;")
    try:
        rows = remote.execute(
            "SELECT id,status,completed_at,validated_at,validated_by FROM tasks WHERE plan_id=?",
            (plan_id,),
        ).fetchall()
        for rt in rows:
            tid, r_status = rt["id"], rt["status"]
            lr = local.execute("SELECT status FROM tasks WHERE id=?", (tid,)).fetchone()
            if not lr:
                continue
            l_status = lr[0]
            if rank.get(r_status, 0) <= rank.get(l_status, 0):
                continue
            if r_status == "done" and l_status not in ("submitted", "done"):
                local.execute("UPDATE tasks SET status='submitted' WHERE id=?", (tid,))
            sets, vals = ["status=?"], [r_status]
            for col in ("completed_at", "validated_at"):
                if rt[col]:
                    sets.append(f"{col}=?")
                    vals.append(rt[col])
            if r_status == "done":
                sets.append("validated_by=?")
                vals.append(rt["validated_by"] or "forced-admin")
            vals.append(tid)
            local.execute(f"UPDATE tasks SET {','.join(sets)} WHERE id=?", vals)
        local.execute(
            "UPDATE waves SET tasks_done=(SELECT COUNT(*) FROM tasks WHERE wave_id_fk=waves.id AND status='done') WHERE plan_id=?",
            (plan_id,),
        )
        local.execute(
            "UPDATE plans SET tasks_done=(SELECT COUNT(*) FROM tasks WHERE plan_id=? AND status='done') WHERE id=?",
            (plan_id, plan_id),
        )
        local.commit()
    finally:
        remote.close()
        local.close()


def sync_files_to_target(
    info: dict, ssh_target: str, target: str, plan_id: int, log
) -> tuple[bool, str]:
    """Sync config/worktree/DB from source to target and remap paths."""
    if info["ssh_source"] and info["source"].startswith("worker:"):
        log(f"▶ Reverse sync: {info['source']} → coordinator")
        _, detail = _rsync(
            f"{info['ssh_source']}:{CLAUDE_HOME}/", f"{CLAUDE_HOME}/", delete=False
        )
        log(f"  → {detail}")
        if info["worktree"]:
            wt = info["worktree"].replace("~", str(Path.home()))
            log(f"▶ Pulling worktree from {info['source']}")
            _, detail = _rsync(f"{info['ssh_source']}:{wt}/", f"{wt}/", delete=False)
            log(f"  → {detail}")
    log(f"▶ Config rsync → {target}")
    ok, detail = _rsync(f"{CLAUDE_HOME}/", f"{ssh_target}:~/.claude/", delete=True)
    log(f"  → {detail}")
    if not ok:
        return False, f"Config rsync failed: {detail}"
    if info["worktree"]:
        wt_local = info["worktree"].replace("~", str(Path.home()))
        if os.path.isdir(wt_local):
            log(f"▶ Worktree rsync → {target}")
            ok, detail = _rsync(
                f"{wt_local}/", f"{ssh_target}:{info['worktree']}/", delete=False
            )
            log(f"  → {detail}")
            if not ok:
                log("  ⚠ Worktree sync partial — target may need git pull")
    log(f"▶ DB sync → {target}")
    try:
        subprocess.run(
            ["sqlite3", str(DB_PATH), "PRAGMA wal_checkpoint(TRUNCATE);"],
            capture_output=True,
            timeout=5,
        )
        r = subprocess.run(
            ["scp"]
            + SSH_OPTS
            + [str(DB_PATH), f"{ssh_target}:~/.claude/data/dashboard.db"],
            capture_output=True,
            text=True,
            timeout=30,
        )
        log(
            "  ✓ dashboard.db transferred"
            if r.returncode == 0
            else f"  ⚠ DB transfer failed: {r.stderr.strip()[:60]}"
        )
    except Exception as e:
        log(f"  ⚠ DB error: {str(e)[:60]}")
    log("▶ Remapping paths on target")
    local_home = str(Path.home())
    try:
        r = _ssh(ssh_target, "echo $HOME", timeout=5)
        remote_home = r.stdout.strip()
        if local_home != remote_home and remote_home:
            remap = (
                f"UPDATE plans SET worktree_path=REPLACE(worktree_path,'{local_home}','{remote_home}') "
                f"WHERE worktree_path LIKE '{local_home}%'; "
                f"UPDATE waves SET worktree_path=REPLACE(worktree_path,'{local_home}','{remote_home}') "
                f"WHERE worktree_path LIKE '{local_home}%';"
            )
            _ssh(
                ssh_target,
                f"sqlite3 ~/.claude/data/dashboard.db '.timeout 5000' \"{remap}\"",
                timeout=10,
            )
            log(f"  ✓ {local_home} → {remote_home}")
        else:
            log("  ✓ Same home dir — no remap needed")
    except Exception:
        log("  ⚠ Remap check failed (non-blocking)")
    return True, ""


def check_stale_host(
    plan_id: int, find_peer: callable, stale_threshold: int = 600
) -> dict:
    """Check if execution_host is stale (offline/crashed).

    Returns: {stale: bool, host: str, reason: str, can_recover: bool}
    """
    host = get_execution_host(plan_id)
    if not host:
        return {"stale": False, "host": "", "reason": "no host", "can_recover": True}
    last_seen = _sql(
        f"SELECT CAST(last_seen AS INTEGER) FROM peer_heartbeats WHERE peer_name='{host}';"
    )
    now = int(time.time())
    if last_seen:
        age = now - int(last_seen)
        if age < stale_threshold:
            return {
                "stale": False,
                "host": host,
                "reason": f"heartbeat {age}s ago",
                "can_recover": False,
            }
    peers = _parse_all_peers(find_peer)
    ssh_dest = None
    for name, pc in peers.items():
        hostnames = [name, pc.get("ssh_alias", ""), pc.get("dns_name", "")]
        if any(host.lower() in h.lower() for h in hostnames if h):
            ssh_dest = pc.get("ssh_alias", name)
            break
    if ssh_dest:
        try:
            r = _ssh(ssh_dest, "echo ok", timeout=8)
            if r.returncode == 0:
                return {
                    "stale": True,
                    "host": host,
                    "reason": "heartbeat stale but SSH ok",
                    "can_recover": True,
                    "ssh_dest": ssh_dest,
                }
        except Exception:
            pass
    return {
        "stale": True,
        "host": host,
        "reason": "heartbeat stale and SSH unreachable",
        "can_recover": False,
        "ssh_dest": ssh_dest,
    }
