#!/usr/bin/env python3
"""Convergio Terminal Server — WebSocket PTY bridge on port 8421.

Local peers spawn a shell directly. Remote peers connect via SSH.
Supports tmux session attach via ssh -t tmux attach.
"""
import asyncio
import json
import os
import pty
import signal
import struct
import subprocess
import sys
import fcntl
import termios

try:
    import websockets
except ImportError:
    print("pip install websockets", file=sys.stderr)
    sys.exit(1)

PORT = int(os.environ.get("TERM_PORT", 8421))
SHELL = os.environ.get("SHELL", "/bin/zsh")

# Peer SSH aliases from mesh config
PEER_SSH = {}

def _load_peers():
    """Load peer SSH aliases from peers.conf or API."""
    try:
        import urllib.request
        data = json.loads(urllib.request.urlopen("http://localhost:8420/api/mesh", timeout=3).read())
        for p in data:
            name = p.get("peer_name", "")
            ssh = p.get("ssh_alias", "")
            if name and ssh:
                PEER_SSH[name] = ssh
    except Exception:
        pass

def _is_local(peer):
    try:
        import urllib.request
        data = json.loads(urllib.request.urlopen("http://localhost:8420/api/mesh", timeout=3).read())
        for p in data:
            if p.get("peer_name") == peer:
                return p.get("is_local", False)
    except Exception:
        pass
    return peer in ("local", "localhost", os.uname().nodename.split(".")[0])

def _build_cmd(peer, tmux_session):
    if _is_local(peer):
        if tmux_session:
            return ["tmux", "new-session", "-A", "-s", tmux_session]
        return [SHELL, "-l"]
    ssh_host = PEER_SSH.get(peer, peer)
    if tmux_session:
        return ["ssh", "-t", ssh_host, f"tmux new-session -A -s {tmux_session}"]
    return ["ssh", "-t", ssh_host]

async def _pty_handler(ws):
    params = dict(p.split("=", 1) for p in ws.path.split("?", 1)[-1].split("&") if "=" in p)
    peer = params.get("peer", "local")
    tmux_session = params.get("tmux_session", "")

    cmd = _build_cmd(peer, tmux_session)
    master_fd, slave_fd = pty.openpty()

    proc = subprocess.Popen(
        cmd,
        stdin=slave_fd, stdout=slave_fd, stderr=slave_fd,
        preexec_fn=os.setsid,
        env={**os.environ, "TERM": "xterm-256color"},
    )
    os.close(slave_fd)
    os.set_blocking(master_fd, False)

    loop = asyncio.get_event_loop()

    async def read_pty():
        while True:
            try:
                data = await loop.run_in_executor(None, lambda: os.read(master_fd, 4096))
                if not data:
                    break
                await ws.send(data)
            except OSError:
                break

    async def write_pty():
        try:
            async for msg in ws:
                if isinstance(msg, bytes):
                    os.write(master_fd, msg)
                else:
                    try:
                        parsed = json.loads(msg)
                        if parsed.get("type") == "resize":
                            cols = parsed.get("cols", 80)
                            rows = parsed.get("rows", 24)
                            winsize = struct.pack("HHHH", rows, cols, 0, 0)
                            fcntl.ioctl(master_fd, termios.TIOCSWINSZ, winsize)
                            continue
                    except (json.JSONDecodeError, KeyError):
                        pass
                    os.write(master_fd, msg.encode())
        except websockets.ConnectionClosed:
            pass

    read_task = asyncio.create_task(read_pty())
    write_task = asyncio.create_task(write_pty())

    try:
        await asyncio.wait([read_task, write_task], return_when=asyncio.FIRST_COMPLETED)
    finally:
        read_task.cancel()
        write_task.cancel()
        try:
            os.kill(proc.pid, signal.SIGHUP)
            proc.wait(timeout=2)
        except Exception:
            proc.kill()
        try:
            os.close(master_fd)
        except OSError:
            pass

async def main():
    _load_peers()
    print(f"Terminal server on ws://0.0.0.0:{PORT}/ws")
    async with websockets.serve(_pty_handler, "0.0.0.0", PORT):
        await asyncio.Future()

if __name__ == "__main__":
    asyncio.run(main())
