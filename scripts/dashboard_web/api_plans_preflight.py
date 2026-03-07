"""SSH resolution and rsync helpers for api_preflight_sse."""

import os
import re
import subprocess
import sys
import time
from pathlib import Path

if __package__ in (None, ""):
    sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
    from scripts.dashboard_web.api_mesh import send_wol
    from scripts.dashboard_web.api_plans import _ssh_run
else:
    from .api_mesh import send_wol
    from .api_plans import _ssh_run

_SSH_OPTS = ["-o", "ConnectTimeout=5", "-o", "BatchMode=yes"]


def ssh_check(dest: str) -> bool:
    try:
        return (
            subprocess.run(
                ["ssh", *_SSH_OPTS, dest, "echo ok"],
                capture_output=True,
                text=True,
                timeout=8,
            ).returncode
            == 0
        )
    except Exception:
        return False


def build_candidates(target: str, pc: dict | None) -> list:
    candidates = []
    if pc:
        if pc.get("ssh_alias"):
            candidates.append(("ssh_alias", pc["ssh_alias"]))
        if pc.get("tailscale_ip"):
            user = pc.get("user", "")
            candidates.append(
                ("tailscale_ip", f"{user + '@' if user else ''}{pc['tailscale_ip']}")
            )
    candidates.append(("raw", target))
    return candidates


def resolve_ssh_dest(target: str, pc: dict | None, handler) -> str | None:
    candidates = build_candidates(target, pc)
    for _, dest in candidates:
        if ssh_check(dest):
            return dest
    if not pc or not pc.get("mac_address"):
        return None
    handler._sse_send("checking", {"name": "SSH reachable — Wake-on-LAN"})
    for _ in range(2):
        send_wol(pc["mac_address"])
        time.sleep(3)
    for wait in [5, 10, 15]:
        time.sleep(wait)
        for _, dest in candidates:
            if ssh_check(dest):
                return dest
    return None


def check_rsync(handler, ssh_dest: str, target_os: str, _check) -> None:
    handler._sse_send("checking", {"name": "rsync"})
    try:
        subprocess.run(["rsync", "--version"], capture_output=True, timeout=5)
    except Exception:
        _check(
            "rsync",
            False,
            "rsync not found locally — install: brew install rsync / apt install rsync",
        )
        return
    try:
        r = _ssh_run(
            ssh_dest,
            "which rsync 2>/dev/null && echo RSYNC_OK || echo RSYNC_MISSING",
            timeout=8,
        )
        if "RSYNC_MISSING" in r.stdout:
            handler._sse_send("checking", {"name": "rsync — installing on remote"})
            install_cmd = (
                "sudo apt-get install -y rsync 2>/dev/null || sudo yum install -y rsync 2>/dev/null"
                if target_os == "linux"
                else "brew install rsync 2>/dev/null || true"
            )
            _ssh_run(ssh_dest, install_cmd, timeout=60)
            ok = (
                "RSYNC_OK"
                in _ssh_run(
                    ssh_dest,
                    "which rsync && echo RSYNC_OK || echo RSYNC_MISSING",
                    timeout=8,
                ).stdout
            )
            _check("rsync", ok, "was missing — installed on remote ✓")
        else:
            _check("rsync", True, "available on both sides ✓")
    except Exception:
        _check("rsync", True, "local ok, remote check skipped")


def sync_config(handler, ssh_dest: str, _check) -> None:
    handler._sse_send("checking", {"name": "Config rsync"})
    claude_home = str(Path.home() / ".claude") + "/"
    excl = str(Path.home() / ".claude" / "config" / "mesh-rsync-exclude.txt")
    excl_flag = ["--exclude-from", excl] if os.path.isfile(excl) else []
    ssh_e = "ssh -o ConnectTimeout=10 -o BatchMode=yes"
    try:
        dry = subprocess.run(
            [
                "rsync",
                "-az",
                "--delete",
                "--stats",
                "--dry-run",
                "-e",
                ssh_e,
                *excl_flag,
                claude_home,
                f"{ssh_dest}:~/.claude/",
            ],
            capture_output=True,
            text=True,
            timeout=30,
        )
        m = re.search(r"Number of regular files transferred:\s*(\d+)", dry.stdout)
        n_files = int(m.group(1)) if m else 0
        if n_files == 0:
            _check("Config rsync", True, "already in sync ✓")
            return
        handler._sse_send(
            "checking", {"name": f"Config rsync — syncing {n_files} files"}
        )
        sr = subprocess.run(
            [
                "rsync",
                "-az",
                "--delete",
                "-e",
                ssh_e,
                *excl_flag,
                claude_home,
                f"{ssh_dest}:~/.claude/",
            ],
            capture_output=True,
            text=True,
            timeout=120,
        )
        last_err = (
            sr.stderr.strip().split("\n")[-1][:60]
            if sr.stderr.strip()
            else f"exit {sr.returncode}"
        )
        _check(
            "Config rsync",
            sr.returncode == 0,
            (
                f"synced {n_files} files ✓"
                if sr.returncode == 0
                else f"rsync failed: {last_err}"
            ),
        )
    except Exception as e:
        _check("Config rsync", False, f"rsync error: {str(e)[:60]}")


def sync_db(handler, ssh_dest: str, _check) -> None:
    handler._sse_send("checking", {"name": "DB sync"})
    db_path = str(Path.home() / ".claude" / "data" / "dashboard.db")
    try:
        subprocess.run(
            ["sqlite3", db_path, "PRAGMA wal_checkpoint(TRUNCATE);"],
            capture_output=True,
            timeout=5,
        )
        r = subprocess.run(
            [
                "scp",
                "-o",
                "ConnectTimeout=10",
                "-o",
                "BatchMode=yes",
                db_path,
                f"{ssh_dest}:~/.claude/data/dashboard.db",
            ],
            capture_output=True,
            text=True,
            timeout=30,
        )
        _check(
            "DB sync",
            r.returncode == 0,
            (
                "dashboard.db transferred ✓"
                if r.returncode == 0
                else f"scp failed: {r.stderr.strip()[:60]}"
            ),
        )
    except Exception as e:
        _check("DB sync", False, f"DB transfer error: {str(e)[:60]}")
