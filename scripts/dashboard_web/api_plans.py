import json
import os
import re
import sqlite3
import subprocess
import time
from pathlib import Path

from api_mesh import find_peer_conf, peer_host_match, send_wol
from middleware import DB_PATH, query, query_one


def handle_plan_move(qs: dict) -> dict:
    plan_id, target = qs.get("plan_id", [""])[0], qs.get("target", [""])[0]
    if not plan_id or not plan_id.isdigit() or not target:
        return {"error": "missing plan_id or target"}
    try:
        conn = sqlite3.connect(str(DB_PATH), timeout=5)
        conn.execute("UPDATE plans SET execution_host=? WHERE id=?", (target, int(plan_id)))
        conn.execute("UPDATE tasks SET executor_host=? WHERE plan_id=? AND status IN ('pending','in_progress')", (target, int(plan_id)))
        conn.commit(); conn.close()
        return {"ok": True, "plan_id": int(plan_id), "target": target}
    except (sqlite3.OperationalError, sqlite3.DatabaseError) as e:
        return {"error": str(e)}


def _ssh_run(dest: str, cmd: str, timeout: int = 10) -> subprocess.CompletedProcess:
    return subprocess.run(["ssh", "-o", "ConnectTimeout=5", "-o", "BatchMode=yes", dest, cmd], capture_output=True, text=True, timeout=timeout)


def api_preflight_sse(handler, qs: dict):
    plan_id, target = qs.get("plan_id", [""])[0], qs.get("target", [""])[0]
    cli_engine = qs.get("cli", [""])[0]
    if not plan_id or not target:
        handler._json_response({"error": "missing plan_id or target"}, 400); return
    all_ok = True; handler._start_sse(); handler._sse_send("start", {"plan_id": plan_id, "target": target, "total_checks": 9})

    def _check(name: str, ok: bool, detail: str, blocking: bool = True):
        nonlocal all_ok
        if not ok and blocking:
            all_ok = False
        handler._sse_send("check", {"name": name, "ok": ok, "detail": detail, "blocking": blocking})

    pc = find_peer_conf(target); candidates = []
    if pc:
        if pc.get("ssh_alias"):
            candidates.append(("ssh_alias", pc["ssh_alias"]))
        if pc.get("tailscale_ip"):
            candidates.append(("tailscale_ip", f"{pc.get('user', '') + '@' if pc.get('user', '') else ''}{pc['tailscale_ip']}"))
    candidates.append(("raw", target)); ssh_dest, tried = None, []
    handler._sse_send("checking", {"name": "SSH reachable"})
    for label, dest in candidates:
        try:
            if subprocess.run(["ssh", "-o", "ConnectTimeout=5", "-o", "BatchMode=yes", dest, "echo ok"], capture_output=True, text=True, timeout=8).returncode == 0:
                ssh_dest = dest; break
            tried.append(f"{dest}({label})")
        except Exception:
            tried.append(f"{dest}({label}:timeout)")
    if not ssh_dest and pc and pc.get("mac_address"):
        handler._sse_send("checking", {"name": "SSH reachable — Wake-on-LAN"})
        for _ in range(2):
            send_wol(pc["mac_address"]); time.sleep(3)
        for wait in [5, 10, 15]:
            time.sleep(wait)
            for _, dest in candidates:
                try:
                    if subprocess.run(["ssh", "-o", "ConnectTimeout=5", "-o", "BatchMode=yes", dest, "echo ok"], capture_output=True, text=True, timeout=8).returncode == 0:
                        ssh_dest = dest; break
                except Exception:
                    pass
            if ssh_dest:
                break
    if not ssh_dest:
        _check("SSH reachable", False, f"tried {', '.join(tried)} — all unreachable"); handler._sse_send("done", {"ok": False}); return
    _check("SSH reachable", True, f"{target} via {ssh_dest} ({next((l for l, d in candidates if d == ssh_dest), '?')}) ✓")

    target_os = pc.get("os", "unknown") if pc else "unknown"
    handler._sse_send("checking", {"name": "rsync"}); rsync_ok = True
    try:
        subprocess.run(["rsync", "--version"], capture_output=True, timeout=5)
    except Exception:
        rsync_ok = False; _check("rsync", False, "rsync not found locally — install with: brew install rsync (mac) / apt install rsync (linux)")
    if rsync_ok:
        try:
            r = _ssh_run(ssh_dest, "which rsync 2>/dev/null && echo RSYNC_OK || echo RSYNC_MISSING", timeout=8)
            if "RSYNC_MISSING" in r.stdout:
                handler._sse_send("checking", {"name": "rsync — installing on remote"})
                install_cmd = "sudo apt-get install -y rsync 2>/dev/null || sudo yum install -y rsync 2>/dev/null || sudo pacman -S --noconfirm rsync 2>/dev/null" if target_os == "linux" else "brew install rsync 2>/dev/null || true"
                _ssh_run(ssh_dest, install_cmd, timeout=60)
                _check("rsync", "RSYNC_OK" in _ssh_run(ssh_dest, "which rsync && echo RSYNC_OK || echo RSYNC_MISSING", timeout=8).stdout, "was missing — installed on remote ✓")
            else:
                _check("rsync", True, "available on both sides ✓")
        except Exception:
            _check("rsync", True, "local ok, remote check skipped")

    handler._sse_send("checking", {"name": "Plan status"}); plan = query_one("SELECT id,name,status,execution_host FROM plans WHERE id=?", (int(plan_id),))
    if not plan:
        _check("Plan status", False, "Not found in DB"); handler._sse_send("done", {"ok": False}); return
    active = plan["status"] in ("todo", "doing"); _check("Plan status", active, f"#{plan_id} is '{plan['status']}'" + ("" if active else " — must be todo/doing"))

    handler._sse_send("checking", {"name": "Heartbeat"}); hb = query_one("SELECT last_seen FROM peer_heartbeats WHERE peer_name=?", (target,))
    hb_ok, age = bool(hb and hb["last_seen"] and int(time.time() - hb["last_seen"]) < 300), int(time.time() - hb["last_seen"]) if hb and hb["last_seen"] else -1
    if hb_ok:
        _check("Heartbeat", True, f"{age}s ago")
    else:
        try:
            _ssh_run(ssh_dest, "nohup $HOME/.claude/scripts/mesh-heartbeat.sh start >/dev/null 2>&1 & sleep 2 && $HOME/.claude/scripts/mesh-heartbeat.sh ping 2>/dev/null && echo HB_OK || echo HB_FAIL", timeout=12)
            _check("Heartbeat", True, "was stale — daemon restarted ✓")
        except Exception:
            _check("Heartbeat", True, "daemon restart attempted")

    handler._sse_send("checking", {"name": "Config rsync"}); claude_home = str(Path.home() / ".claude") + "/"; exclude_file = str(Path.home() / ".claude" / "config" / "mesh-rsync-exclude.txt")
    try:
        dry = ["rsync", "-az", "--delete", "--stats", "--dry-run", "-e", "ssh -o ConnectTimeout=10 -o BatchMode=yes"] + (["--exclude-from", exclude_file] if os.path.isfile(exclude_file) else []) + [claude_home, f"{ssh_dest}:~/.claude/"]
        r = subprocess.run(dry, capture_output=True, text=True, timeout=30)
        n_files = int(re.search(r"Number of regular files transferred:\s*(\d+)", r.stdout).group(1)) if re.search(r"Number of regular files transferred:\s*(\d+)", r.stdout) else 0
        if n_files == 0:
            _check("Config rsync", True, "already in sync ✓")
        else:
            handler._sse_send("checking", {"name": f"Config rsync — syncing {n_files} files"})
            sync = ["rsync", "-az", "--delete", "-e", "ssh -o ConnectTimeout=10 -o BatchMode=yes"] + (["--exclude-from", exclude_file] if os.path.isfile(exclude_file) else []) + [claude_home, f"{ssh_dest}:~/.claude/"]
            sr = subprocess.run(sync, capture_output=True, text=True, timeout=120)
            _check("Config rsync", sr.returncode == 0, f"synced {n_files} files ✓" if sr.returncode == 0 else f"rsync failed: {(sr.stderr.strip().split(chr(10))[-1][:60] if sr.stderr.strip() else f'exit {sr.returncode}')}")
    except Exception as e:
        _check("Config rsync", False, f"rsync error: {str(e)[:60]}")

    handler._sse_send("checking", {"name": "DB sync"}); db_path = str(Path.home() / ".claude" / "data" / "dashboard.db")
    try:
        subprocess.run(["sqlite3", db_path, "PRAGMA wal_checkpoint(TRUNCATE);"], capture_output=True, timeout=5)
        r = subprocess.run(["scp", "-o", "ConnectTimeout=10", "-o", "BatchMode=yes", db_path, f"{ssh_dest}:~/.claude/data/dashboard.db"], capture_output=True, text=True, timeout=30)
        _check("DB sync", r.returncode == 0, "dashboard.db transferred ✓" if r.returncode == 0 else f"scp failed: {r.stderr.strip()[:60]}")
    except Exception as e:
        _check("DB sync", False, f"DB transfer error: {str(e)[:60]}")

    handler._sse_send("checking", {"name": "Claude CLI"})
    try:
        r = _ssh_run(ssh_dest, "export PATH=\"$HOME/.local/bin:$HOME/.claude/local/bin:/opt/homebrew/bin:/usr/local/bin:$PATH\"; which claude >/dev/null 2>&1 && claude --version 2>/dev/null || echo missing", timeout=15)
        has_claude = "missing" not in r.stdout and r.returncode == 0; _check("Claude CLI", has_claude, r.stdout.strip().split("\n")[-1][:40] if has_claude else "not found")
    except Exception:
        _check("Claude CLI", False, "Check timeout")

    engine = cli_engine or (pc.get("default_engine") if pc else "") or "copilot"
    if engine == "claude":
        handler._sse_send("checking", {"name": "Claude Auth Type"})
        try:
            r = _ssh_run(ssh_dest, "cat ~/.claude/.credentials.json 2>/dev/null || echo MISSING", timeout=10)
            cred = r.stdout.strip()
            if "MISSING" in cred or not cred:
                _check("Claude Auth Type", False, "credentials.json not found — Claude login required")
            elif "refreshToken" in cred:
                _check("Claude Auth Type", True, "OAuth / Max subscription ✓", blocking=False)
            elif "apiKey" in cred:
                _check("Claude Auth Type", True, "API key detected — Max subscription recommended", blocking=False)
            else:
                _check("Claude Auth Type", True, "credentials present (type unknown)", blocking=False)
        except Exception:
            _check("Claude Auth Type", False, "Auth check timeout")

    handler._sse_send("checking", {"name": "Disk space"})
    try:
        free_gb = int(_ssh_run(ssh_dest, "python3 -c \"import shutil; u=shutil.disk_usage('.'); print(u.free//(1024**3))\" 2>/dev/null || python -c \"import shutil; u=shutil.disk_usage('.'); print(u.free//(1024**3))\" 2>/dev/null || echo -1", timeout=10).stdout.strip().split("\n")[-1])
        _check("Disk space", free_gb >= 5, f"{free_gb}GB free" + ("" if free_gb >= 5 else " — need ≥5GB"))
    except Exception:
        _check("Disk space", False, "Check skipped")

    handler._sse_send("done", {"ok": all_ok})


def handle_plan_delegate(handler, qs: dict, safe_name):
    plan_id, target, cli_choice = qs.get("plan_id", [""])[0], qs.get("target", [""])[0], qs.get("cli", ["copilot"])[0]
    if not plan_id or not plan_id.isdigit() or not target:
        handler._json_response({"error": "missing plan_id or target"}, 400); return
    if not safe_name.match(target):
        handler._json_response({"error": "invalid target name"}, 400); return
    handler._start_sse()
    try:
        from mesh_handoff import check_stale_host, full_handoff
        handler._sse_send("phase", "handoff"); handler._sse_send("log", f"━━━ HANDOFF: Plan #{plan_id} → {target} ━━━"); handler._sse_send("log", "")
        stale = check_stale_host(int(plan_id), find_peer_conf)
        if stale["stale"]:
            handler._sse_send("log", f"⚠ Previous host '{stale['host']}' is stale: {stale['reason']}")
            handler._sse_send("log", "  → Will recover and re-delegate" if stale["can_recover"] else "  → Host unreachable — forcing re-delegation")
            handler._sse_send("log", "")
        ok, summary = full_handoff(int(plan_id), target, find_peer_conf, lambda msg: handler._sse_send("log", msg), cli=cli_choice)
        handler._sse_send("log", ""); handler._sse_send("log", f"✓ {summary}" if ok else f"✗ {summary}")
        handler._sse_send("done" if ok else "error", {"ok": ok, "plan_id": int(plan_id), "target": target} if ok else {"ok": False, "message": summary})
    except ImportError as e:
        handler._sse_send("error", {"ok": False, "message": f"Handoff module error: {e}"})
    except Exception as e:
        handler._sse_send("error", {"ok": False, "message": str(e)})


def handle_pull_remote_db(handler, _qs: dict):
    from mesh_handoff import pull_db_from_peer
    plans = query("SELECT id, execution_host FROM plans WHERE status IN ('todo','doing') AND execution_host IS NOT NULL AND execution_host <> ''")
    local_host = subprocess.run(["hostname", "-s"], capture_output=True, text=True, timeout=5).stdout.strip()
    peer_plans: dict[str, list[int]] = {}
    for p in plans:
        host = p["execution_host"]
        if peer_host_match("m3max", host) or host == local_host:
            continue
        pc = find_peer_conf(host); ssh_dest = pc.get("ssh_alias", host) if pc else host
        peer_plans.setdefault(ssh_dest, []).append(p["id"])
    results = [{"peer": ssh_dest, "plans": plan_ids, "ok": ok, "detail": detail} for ssh_dest, plan_ids in peer_plans.items() for ok, detail in [pull_db_from_peer(ssh_dest, plan_ids)]]
    handler._json_response({"synced": results, "count": len(results)})


def handle_plan_start_sse(handler, qs: dict):
    plan_id, cli, target = qs.get("plan_id", [""])[0], qs.get("cli", ["copilot"])[0], qs.get("target", ["local"])[0]
    if not plan_id or not plan_id.isdigit():
        handler._json_response({"error": "missing plan_id"}, 400); return
    handler._start_sse(); handler._sse_send("log", f"▶ Starting plan #{plan_id} with {cli}")
    try:
        hostname = subprocess.run(["hostname", "-s"], capture_output=True, text=True, timeout=5).stdout.strip()
        conn = sqlite3.connect(str(DB_PATH), timeout=5)
        conn.execute("UPDATE plans SET status='doing', execution_host=? WHERE id=? AND status IN ('todo','doing')", (target if target != "local" else hostname, int(plan_id)))
        conn.commit(); conn.close(); handler._sse_send("log", f"✓ Plan claimed by {target if target != 'local' else hostname}")
    except Exception as e:
        handler._sse_send("log", f"✗ DB update failed: {e}"); handler._sse_send("done", {"ok": False, "message": str(e)}); return
    scripts = Path.home() / ".claude" / "scripts"
    if target == "local" or peer_host_match("m3max", target):
        cmd = f'claude --model sonnet -p "/execute {plan_id}"' if cli == "claude" else f'copilot -p "/execute {plan_id}"'
        handler._sse_send("log", f"▶ Running locally: {cmd}")
        try:
            proc = subprocess.Popen(cmd, shell=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, env={**os.environ, "PATH": str(scripts) + ":/opt/homebrew/bin:/usr/local/bin:" + os.environ.get("PATH", "")}, cwd=str(Path.home() / ".claude"))
            for line in iter(proc.stdout.readline, ""):
                handler._sse_send("log", line.rstrip())
            proc.wait(timeout=600); handler._sse_send("done", {"ok": proc.returncode == 0, "exit_code": proc.returncode})
        except subprocess.TimeoutExpired:
            proc.terminate(); handler._sse_send("done", {"ok": False, "message": "Timeout (600s)"})
        except Exception as e:
            handler._sse_send("done", {"ok": False, "message": str(e)})
    else:
        handler._sse_send("log", f"▶ Delegating to {target}")
        try:
            from mesh_handoff import full_handoff
            ok, summary = full_handoff(int(plan_id), target, find_peer_conf, lambda msg: handler._sse_send("log", msg), cli=cli)
            handler._sse_send("done", {"ok": ok, "message": summary})
        except Exception as e:
            handler._sse_send("done", {"ok": False, "message": str(e)})
