"""Mesh Handoff Core — shared primitives for mesh_handoff*.py modules."""

import json
import os
import re
import subprocess
import sys
import time
from pathlib import Path

DB_PATH = Path.home() / ".claude" / "data" / "dashboard.db"
CLAUDE_HOME = Path.home() / ".claude"
LOCK_DIR = CLAUDE_HOME / "data" / "locks"
EXCLUDE_FILE = CLAUDE_HOME / "config" / "mesh-rsync-exclude.txt"
SSH_OPTS = [
    "-o",
    "ConnectTimeout=10",
    "-o",
    "BatchMode=yes",
    "-o",
    "StrictHostKeyChecking=accept-new",
]


def _sql(query: str, db: str | None = None) -> str:
    """Run sqlite3 query. Returns pipe-delimited rows."""
    import sqlite3 as _sqlite3

    db = db or str(DB_PATH)
    try:
        conn = _sqlite3.connect(db, timeout=5)
        conn.execute("PRAGMA journal_mode=WAL;")
        cur = conn.execute(query)
        if query.strip().upper().startswith("SELECT"):
            rows = cur.fetchall()
            conn.close()
            return "\n".join(
                "|".join(str(c) if c is not None else "" for c in r) for r in rows
            )
        else:
            conn.commit()
            conn.close()
            return ""
    except Exception:
        return ""


def _ssh(dest: str, cmd: str, timeout: int = 15) -> subprocess.CompletedProcess:
    """Run cmd on dest via SSH. Uses lib/ssh.py ssh_run when available."""
    try:
        sys.path.insert(0, str(Path(__file__).parent / "lib"))
        from ssh import ssh_run

        return ssh_run(dest, cmd, timeout=timeout)
    except ImportError:
        return subprocess.run(
            ["ssh"] + SSH_OPTS + [dest, cmd],
            capture_output=True,
            text=True,
            timeout=timeout,
        )


def _rsync(
    src: str, dest_remote: str, delete: bool = False, timeout: int = 120
) -> tuple[bool, str]:
    """rsync with optional --delete. Returns (ok, detail)."""
    cmd = ["rsync", "-az", "--stats", "-e", "ssh " + " ".join(SSH_OPTS)]
    if delete:
        cmd.append("--delete")
    if EXCLUDE_FILE.is_file():
        cmd += ["--exclude-from", str(EXCLUDE_FILE)]
    cmd += [src, dest_remote]
    try:
        r = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
        m = re.search(r"Number of regular files transferred:\s*(\d+)", r.stdout)
        n = int(m.group(1)) if m else 0
        if r.returncode == 0:
            return True, f"{n} files synced"
        return False, f"rsync exit {r.returncode}: {r.stderr.strip()[:80]}"
    except subprocess.TimeoutExpired:
        return False, "rsync timed out"
    except OSError as e:
        return False, str(e)[:80]


def acquire_lock(plan_id: int, peer: str, ttl: int = 600) -> tuple[bool, str]:
    """Acquire delegation lock. Returns (ok, holder_info)."""
    LOCK_DIR.mkdir(parents=True, exist_ok=True)
    lock_file = LOCK_DIR / f"delegate-{plan_id}.lock"
    now = time.time()
    if lock_file.exists():
        try:
            data = json.loads(lock_file.read_text())
            age = now - data.get("ts", 0)
            if age < ttl:
                return False, f"locked by {data.get('peer')} {int(age)}s ago"
        except (json.JSONDecodeError, KeyError):
            pass

    lock_file.write_text(json.dumps({"peer": peer, "ts": now, "pid": os.getpid()}))
    return True, "acquired"


def release_lock(plan_id: int):
    lock_file = LOCK_DIR / f"delegate-{plan_id}.lock"
    lock_file.unlink(missing_ok=True)


def get_execution_host(plan_id: int) -> str:
    """Who currently owns this plan's code. Empty = no one (coordinator)."""
    return _sql(f"SELECT COALESCE(execution_host,'') FROM plans WHERE id={plan_id};")


def detect_sync_source(plan_id: int, target: str, find_peer: callable) -> dict:
    """Determine sync direction. Returns dict: source, ssh_source, ssh_target, worktree, needs_stop, needs_stash."""
    host = get_execution_host(plan_id)
    worktree = _sql(f"SELECT COALESCE(worktree_path,'') FROM plans WHERE id={plan_id};")
    local_hostname = subprocess.run(
        ["hostname", "-s"], capture_output=True, text=True, timeout=5
    ).stdout.strip()

    pc_target = find_peer(target)
    ssh_target = pc_target.get("ssh_alias", target) if pc_target else target

    if (
        not host
        or host == local_hostname
        or host.lower().startswith(local_hostname.lower())
    ):
        return {
            "source": "coordinator",
            "ssh_source": None,
            "ssh_target": ssh_target,
            "worktree": worktree,
            "needs_stop": False,
            "needs_stash": False,
        }

    target_names = [target]
    if pc_target:
        target_names += [pc_target.get("ssh_alias", ""), pc_target.get("dns_name", "")]
    if any(host.lower() in n.lower() for n in target_names if n):
        return {
            "source": "same_node",
            "ssh_source": ssh_target,
            "ssh_target": ssh_target,
            "worktree": worktree,
            "needs_stop": False,
            "needs_stash": False,
        }

    all_peers = _parse_all_peers(find_peer)
    ssh_source = None
    for name, pc in all_peers.items():
        hostnames = [name, pc.get("ssh_alias", ""), pc.get("dns_name", "")]
        if any(host.lower() in h.lower() for h in hostnames if h):
            ssh_source = pc.get("ssh_alias", name)
            break

    plan_status = _sql(f"SELECT status FROM plans WHERE id={plan_id};")
    has_in_progress = _sql(
        f"SELECT COUNT(*) FROM tasks WHERE plan_id={plan_id} "
        f"AND status='in_progress';"
    )

    return {
        "source": f"worker:{host}",
        "ssh_source": ssh_source,
        "ssh_target": ssh_target,
        "worktree": worktree,
        "needs_stop": plan_status == "doing" and int(has_in_progress or 0) > 0,
        "needs_stash": True,
    }


def _parse_all_peers(find_peer: callable) -> dict:
    """Build {name: conf} from peers.conf via the find_peer helper."""
    peers = {}
    conf_path = CLAUDE_HOME / "config" / "peers.conf"
    if not conf_path.exists():
        return peers
    current = None
    for line in conf_path.read_text().splitlines():
        line = line.split("#")[0].strip()
        if not line:
            continue
        if line.startswith("[") and line.endswith("]"):
            current = line[1:-1]
            peers[current] = {"peer_name": current}
        elif current and "=" in line:
            k, v = line.split("=", 1)
            peers[current][k.strip()] = v.strip()
    return peers


_CLI_MAP = {
    "copilot": "copilot --yolo",
    "claude": "claude --dangerously-skip-permissions --model sonnet",
    "opencode": "opencode",
}
_CLI_DETECT = {
    "copilot": "(command -v copilot>/dev/null 2>&1&&echo copilot)||(gh copilot --version>/dev/null 2>&1&&echo gh-copilot)||echo MISSING",
    "claude": "command -v claude>/dev/null 2>&1&&echo claude||echo MISSING",
    "opencode": "command -v opencode>/dev/null 2>&1&&echo opencode||echo MISSING",
}
_PATH_EXPORT = 'export PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"'


def resolve_cli(cli: str, ssh_target: str, log) -> str:
    """Detect which CLI is available on target. Returns resolved command string."""
    cli_cmd = _CLI_MAP.get(cli, cli)
    try:
        detect = _CLI_DETECT.get(
            cli,
            f"command -v {cli_cmd.split()[0]}>/dev/null 2>&1&&echo FOUND||echo MISSING",
        )
        r = _ssh(ssh_target, f"{_PATH_EXPORT}; {detect}", timeout=8)
        result = r.stdout.strip().split("\n")[-1]
        if result == "gh-copilot":
            log("  → copilot detected as gh extension")
            return "gh copilot -p"
        if result != "MISSING":
            return cli_cmd
        log(f"  Warning: {cli} not found on target — trying fallback")
        for fb in ["copilot", "claude", "opencode"]:
            det = _CLI_DETECT.get(
                fb, f"command -v {fb}>/dev/null 2>&1&&echo {fb}||echo MISSING"
            )
            r2 = _ssh(ssh_target, f"{_PATH_EXPORT}; {det}", timeout=8)
            fb_result = r2.stdout.strip().split("\n")[-1]
            if fb_result != "MISSING":
                log(f"  → Using {fb} ({fb_result}) instead")
                return (
                    "gh copilot -p"
                    if fb_result == "gh-copilot"
                    else _CLI_MAP.get(fb, fb)
                )
    except Exception:
        pass
    return ""
