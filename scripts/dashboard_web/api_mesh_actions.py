"""SSE action handlers + power management for the mesh dashboard API.

Data/query helpers live in api_mesh.py. This module contains only
streaming (SSE) handlers and power-management actions.
"""

import os
import shlex
import time
from pathlib import Path

from api_mesh import find_peer_conf, send_wol
from lib.sse import run_command_sse
from lib.ssh import ssh_ok


_SCRIPTS = Path.home() / ".claude" / "scripts"


def _scripts_env() -> dict[str, str]:
    return {
        **os.environ,
        "PATH": str(_SCRIPTS)
        + ":/opt/homebrew/bin:/usr/local/bin:"
        + os.environ.get("PATH", ""),
    }


def handle_power_action_sse(handler, action: str, peer: str) -> None:
    handler._start_sse()
    pc = find_peer_conf(peer)
    if not pc:
        handler._sse_send("log", f"✗ Peer '{peer}' not found in peers.conf")
        handler._sse_send("done", {"ok": False, "message": "Peer not found"})
        return
    ssh_dest = pc.get("ssh_alias", peer)
    if action == "wake":
        _handle_wake(handler, peer, pc, ssh_dest)
    else:
        _handle_reboot(handler, peer, pc, ssh_dest)


def _handle_wake(handler, peer: str, pc: dict, ssh_dest: str) -> None:
    mac = pc.get("mac_address", "")
    handler._sse_send("log", f"▶ Wake-on-LAN — {peer}")
    if not mac:
        handler._sse_send(
            "log", f"✗ No mac_address configured for {peer} in peers.conf"
        )
        handler._sse_send("done", {"ok": False, "message": "No MAC address configured"})
        return
    handler._sse_send("log", f"  MAC: {mac}")
    handler._sse_send("log", "  Sending magic packet (broadcast 255.255.255.255:9)…")
    sent = sum(1 if send_wol(mac) else 0 for _ in range(3) if not time.sleep(0.3))
    if sent == 0:
        handler._sse_send("log", "✗ Failed to send magic packet")
        handler._sse_send("done", {"ok": False, "message": "WoL send failed"})
        return
    handler._sse_send("log", f"✓ {sent}/3 magic packets sent")
    handler._sse_send("log", "")
    handler._sse_send("log", "  Waiting 15s for node to boot…")
    for i in range(3):
        time.sleep(5)
        handler._sse_send("log", f"  Ping attempt {i + 1}/3…")
        if ssh_ok(ssh_dest):
            handler._sse_send("log", f"✓ {peer} is online!")
            handler._sse_send("done", {"ok": True})
            return
    handler._sse_send("log", "⚠ Node not responding yet — may need more time to boot")
    handler._sse_send("done", {"ok": True, "message": "WoL sent, node still booting"})


def _handle_reboot(handler, peer: str, pc: dict, ssh_dest: str) -> None:
    import subprocess

    user, target = pc.get("user", ""), pc.get("ssh_alias", peer)
    handler._sse_send("log", f"▶ SSH Reboot — {peer}")
    handler._sse_send("log", f"  Target: {f'{user}@{target}' if user else target}")
    handler._sse_send("log", "  Checking SSH connectivity…")
    if not ssh_ok(ssh_dest, 8):
        handler._sse_send("log", f"✗ Cannot reach {peer}: unreachable")
        handler._sse_send("log", "  Try Wake-on-LAN first if the node is powered off")
        handler._sse_send("done", {"ok": False, "message": "SSH unreachable"})
        return
    handler._sse_send("log", "  ✓ Node reachable")
    handler._sse_send("log", "  Sending reboot command…")
    os_type = pc.get("os", "unknown")
    if os_type == "windows":
        reboot_cmd = "shutdown /r /t 5 /f 2>&1"
    elif os_type == "macos":
        reboot_cmd = "sudo shutdown -r now 2>&1 || sudo reboot 2>&1"
    else:
        reboot_cmd = "sudo reboot 2>&1 || sudo shutdown -r now 2>&1"
    try:
        r = subprocess.run(
            [
                "ssh",
                "-o",
                "ConnectTimeout=5",
                "-o",
                "BatchMode=yes",
                ssh_dest,
                reboot_cmd,
            ],
            capture_output=True,
            text=True,
            timeout=10,
        )
        if output := (r.stdout + r.stderr).strip():
            handler._sse_send("log", f"  {output}")
        handler._sse_send("log", "✓ Reboot command sent")
        handler._sse_send("log", "")
        handler._sse_send("log", "  Waiting 30s for node to come back…")
        time.sleep(20)
        for i in range(4):
            time.sleep(5)
            handler._sse_send("log", f"  Ping attempt {i + 1}/4…")
            if ssh_ok(ssh_dest):
                handler._sse_send("log", f"✓ {peer} is back online!")
                handler._sse_send("done", {"ok": True})
                return
        handler._sse_send("log", "⚠ Node not back yet — may need more time")
        handler._sse_send("done", {"ok": True, "message": "Reboot sent, still booting"})
    except Exception:
        handler._sse_send("log", "  Connection dropped (expected during reboot)")
        handler._sse_send("log", "✓ Reboot likely in progress")
        handler._sse_send("done", {"ok": True, "message": "Reboot in progress"})


def handle_mesh_action_sse(handler, qs: dict, safe_name) -> None:
    action, peer = qs.get("action", [""])[0], qs.get("peer", [""])[0]
    if not peer or (peer != "__all__" and not safe_name.match(peer)):
        handler._json_response({"error": "invalid peer"}, 400)
        return
    if action in ("wake", "reboot"):
        handle_power_action_sse(handler, action, peer)
        return
    is_all = peer == "__all__"
    peer_flag = "" if is_all else f"--peer {shlex.quote(peer)}"
    cmd = {
        "sync": f"{_SCRIPTS}/mesh-sync-all.sh {peer_flag}",
        "heartbeat": f"{_SCRIPTS}/mesh-heartbeat.sh status",
        "auth": f"{_SCRIPTS}/mesh-auth-sync.sh push {'--all' if is_all else f'--peer {shlex.quote(peer)}'}",
        "status": f"{_SCRIPTS}/mesh-load-query.sh {'--json' if is_all else f'--peer {shlex.quote(peer)} --json'}",
    }.get(action)
    if not cmd:
        handler._json_response({"error": "invalid action"}, 400)
        return
    label = {
        "sync": "Sync Config",
        "heartbeat": "Heartbeat Status",
        "auth": "Auth Sync",
        "status": "Load Status",
    }.get(action, action)
    handler._start_sse()
    handler._sse_send("log", f"▶ {label} — {'All Peers' if is_all else peer}")
    handler._sse_send("log", f"▶ Running: {cmd.split('/')[-1]}")
    run_command_sse(handler, cmd, timeout=120 if is_all else 60, env=_scripts_env())


def handle_fullsync_sse(handler, qs: dict) -> None:
    peer = qs.get("peer", [""])[0]
    force = qs.get("force", [""])[0] == "1"
    cmd = (
        f"{_SCRIPTS}/mesh-sync-all.sh"
        + (f" --peer {shlex.quote(peer)}" if peer else "")
        + (" --force" if force else "")
    )
    handler._start_sse()
    handler._sse_send("log", "▶ Full Bidirectional Sync")
    handler._sse_send("log", f"▶ Running: {cmd.split('/')[-1]}")
    run_command_sse(handler, cmd, timeout=180, env=_scripts_env())
