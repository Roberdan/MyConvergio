import os
import shlex
import subprocess
from pathlib import Path

_TERMINAL_ALLOWED_CMDS = {
    "ls", "cat", "head", "tail", "grep", "find", "df", "du", "free", "uptime", "ps", "top", "uname", "hostname", "whoami", "date", "wc", "sort", "uniq", "echo", "pwd", "id", "which", "file", "stat", "mount", "env", "printenv", "journalctl", "systemctl", "docker", "git", "sqlite3", "python3", "python", "node", "npm", "npx", "pip", "plan-db.sh", "plan-db-safe.sh", "git-digest.sh", "diff-digest.sh", "test-digest.sh", "build-digest.sh", "service-digest.sh", "db-digest.sh", "mesh-sync-all.sh", "mesh-heartbeat.sh", "mesh-auth-sync.sh", "mesh-load-query.sh", "copilot-worker.sh", "claude", "copilot", "ssh", "scp", "rsync", "ping", "curl", "wget", "dig", "nslookup", "brew", "apt", "htop", "lsof", "netstat", "ss", "ip",
}


def handle_terminal(qs: dict, safe_name) -> dict:
    cmd = qs.get("cmd", [""])[0]
    peer = qs.get("peer", [""])[0]
    if not cmd:
        return {"output": "", "exit_code": 1}
    try:
        args = shlex.split(cmd)
    except ValueError as e:
        return {"output": f"Invalid command syntax: {e}", "exit_code": 1}
    if not args:
        return {"output": "", "exit_code": 1}
    base_cmd = Path(args[0]).name
    if base_cmd not in _TERMINAL_ALLOWED_CMDS:
        return {"output": f"Command not allowed: {base_cmd}", "exit_code": 1}
    if peer and peer != "local":
        if not safe_name.match(peer):
            return {"output": "Invalid peer name", "exit_code": 1}
        args = ["ssh", peer] + args
    try:
        r = subprocess.run(args, capture_output=True, text=True, timeout=60, env={**os.environ, "PATH": "/opt/homebrew/bin:/usr/local/bin:" + os.environ.get("PATH", "")})
        return {"output": (r.stdout + r.stderr)[:10000], "exit_code": r.returncode}
    except subprocess.TimeoutExpired:
        return {"output": "Timeout (60s)", "exit_code": 1}
    except FileNotFoundError:
        return {"output": f"Command not found: {args[0]}", "exit_code": 1}
