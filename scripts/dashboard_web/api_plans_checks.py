"""Service check helpers for api_preflight_sse (heartbeat, CLI, disk, auth)."""

import sys
import time
from pathlib import Path

if __package__ in (None, ""):
    sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
    from scripts.dashboard_web.api_plans import _ssh_run
else:
    from .api_plans import _ssh_run


def check_heartbeat(handler, ssh_dest: str, target: str, _check, query_one_fn) -> None:
    handler._sse_send("checking", {"name": "Heartbeat"})
    hb = query_one_fn(
        "SELECT last_seen FROM peer_heartbeats WHERE peer_name=?", (target,)
    )
    age = int(time.time() - hb["last_seen"]) if hb and hb["last_seen"] else -1
    if hb and hb["last_seen"] and age < 300:
        _check("Heartbeat", True, f"{age}s ago")
        return
    try:
        _ssh_run(
            ssh_dest,
            "nohup $HOME/.claude/scripts/mesh-heartbeat.sh start >/dev/null 2>&1 & sleep 2 && $HOME/.claude/scripts/mesh-heartbeat.sh ping 2>/dev/null && echo HB_OK || echo HB_FAIL",
            timeout=12,
        )
        _check("Heartbeat", True, "was stale — daemon restarted ✓")
    except Exception:
        _check("Heartbeat", True, "daemon restart attempted")


def check_auth(handler, ssh_dest: str, _check) -> None:
    handler._sse_send("checking", {"name": "Claude Auth Type"})
    try:
        r = _ssh_run(
            ssh_dest,
            "cat ~/.claude/.credentials.json 2>/dev/null || echo MISSING",
            timeout=10,
        )
        cred = r.stdout.strip()
        if "MISSING" in cred or not cred:
            _check(
                "Claude Auth Type",
                False,
                "credentials.json not found — Claude login required",
            )
        elif "refreshToken" in cred:
            _check(
                "Claude Auth Type", True, "OAuth / Max subscription ✓", blocking=False
            )
        elif "apiKey" in cred:
            _check(
                "Claude Auth Type",
                True,
                "API key detected — Max subscription recommended",
                blocking=False,
            )
        else:
            _check(
                "Claude Auth Type",
                True,
                "credentials present (type unknown)",
                blocking=False,
            )
    except Exception:
        _check("Claude Auth Type", False, "Auth check timeout")


def check_cli_tools(handler, ssh_dest: str, engine: str, _check) -> None:
    handler._sse_send("checking", {"name": "Claude CLI"})
    try:
        r = _ssh_run(
            ssh_dest,
            'export PATH="$HOME/.local/bin:$HOME/.claude/local/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"; which claude >/dev/null 2>&1 && claude --version 2>/dev/null || echo missing',
            timeout=15,
        )
        has_claude = "missing" not in r.stdout and r.returncode == 0
        _check(
            "Claude CLI",
            has_claude,
            r.stdout.strip().split("\n")[-1][:40] if has_claude else "not found",
        )
    except Exception:
        _check("Claude CLI", False, "Check timeout")
    handler._sse_send("checking", {"name": "Copilot CLI"})
    try:
        r = _ssh_run(
            ssh_dest,
            'export PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"; (command -v copilot >/dev/null 2>&1 && copilot --version 2>/dev/null) || (gh copilot --version >/dev/null 2>&1 && echo "gh-extension") || echo missing',
            timeout=10,
        )
        has_copilot = "missing" not in r.stdout and r.returncode == 0
        _check(
            "Copilot CLI",
            has_copilot,
            r.stdout.strip().split("\n")[-1][:40] if has_copilot else "not found",
        )
    except Exception:
        _check("Copilot CLI", False, "Check timeout")
    if engine == "claude":
        check_auth(handler, ssh_dest, _check)


def check_disk(handler, ssh_dest: str, _check) -> None:
    handler._sse_send("checking", {"name": "Disk space"})
    try:
        free_gb = int(
            _ssh_run(
                ssh_dest,
                "python3 -c \"import shutil; u=shutil.disk_usage('.'); print(u.free//(1024**3))\" 2>/dev/null || echo -1",
                timeout=10,
            )
            .stdout.strip()
            .split("\n")[-1]
        )
        _check(
            "Disk space",
            free_gb >= 5,
            f"{free_gb}GB free" + ("" if free_gb >= 5 else " — need >=5GB"),
        )
    except Exception:
        _check("Disk space", False, "Check skipped")
