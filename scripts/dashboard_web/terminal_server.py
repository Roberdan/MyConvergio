"""WebSocket + PTY terminal server for Convergio Control Room.

Uses `websockets` library for proper browser WebSocket protocol handling.
Each connection spawns a real pseudo-terminal via pty.fork().
Supports local shell and SSH to remote mesh peers.

Usage: python3 terminal_server.py [--port 8421]
"""

import asyncio
import configparser
import json
import os
import signal
import struct
import sys
from pathlib import Path
from urllib.parse import parse_qs, urlparse

# Platform-specific imports: pty/fcntl/termios only on POSIX
IS_WINDOWS = sys.platform == "win32"
if not IS_WINDOWS:
    import fcntl
    import pty
    import termios

import websockets

PEERS_CONF = Path.home() / ".claude" / "config" / "peers.conf"
PORT = 8421


def get_ssh_config(peer_name: str) -> dict:
    """Return SSH connection config for a peer as {user, host}.

    Reads peers.conf to get the ssh_alias (host) and user fields.
    Falls back to peer_name as host and current OS user if not found.
    """
    fallback_user = os.environ.get("USER") or os.environ.get("LOGNAME") or "root"
    if not PEERS_CONF.exists():
        return {"user": fallback_user, "host": peer_name}
    cp = configparser.ConfigParser()
    cp.read(str(PEERS_CONF))
    if peer_name in cp:
        host = cp[peer_name].get("ssh_alias", peer_name)
        user = cp[peer_name].get("user", fallback_user)
        return {"user": user, "host": host}
    return {"user": fallback_user, "host": peer_name}


async def terminal_handler(ws):
    # Parse peer from request path
    path = ws.request.path if hasattr(ws.request, "path") else ""
    parsed = urlparse(path)
    qs = parse_qs(parsed.query)
    peer = qs.get("peer", ["local"])[0]
    tmux_session = qs.get("tmux_session", [""])[0]

    # Determine command
    if peer and peer not in ("local", ""):
        ssh_cfg = get_ssh_config(peer)
        user, host = ssh_cfg["user"], ssh_cfg["host"]
        # Prepend common paths (SSH BatchMode has minimal PATH)
        path_prefix = (
            "export PATH=/opt/homebrew/bin:/usr/local/bin:$HOME/.local/bin:$PATH; "
        )
        if tmux_session:
            cmd = [
                "ssh",
                "-tt",
                "-o",
                "StrictHostKeyChecking=accept-new",
                f"{user}@{host}",
                f"{path_prefix}tmux new-session -A -s '{tmux_session}'",
            ]
        else:
            cmd = [
                "ssh",
                "-tt",
                "-o",
                "StrictHostKeyChecking=accept-new",
                f"{user}@{host}",
            ]
    else:
        if IS_WINDOWS:
            cmd = [os.environ.get("COMSPEC", "cmd.exe")]
        elif tmux_session:
            shell = os.environ.get("SHELL", "/bin/bash")
            cmd = [shell, "-l", "-c", f"tmux new-session -A -s '{tmux_session}'"]
        else:
            shell = os.environ.get("SHELL", "/bin/bash")
            cmd = [shell, "-l"]

    if IS_WINDOWS:
        await _terminal_handler_subprocess(ws, cmd)
    else:
        await _terminal_handler_pty(ws, cmd)


async def _terminal_handler_pty(ws, cmd):
    """POSIX PTY-based terminal handler."""
    pid, master_fd = pty.fork()
    if pid == 0:
        os.environ["TERM"] = "xterm-256color"
        os.environ["LANG"] = "en_US.UTF-8"
        os.execvp(cmd[0], cmd)
        sys.exit(1)

    winsize = struct.pack("HHHH", 24, 80, 0, 0)
    fcntl.ioctl(master_fd, termios.TIOCSWINSZ, winsize)

    loop = asyncio.get_running_loop()
    closed = asyncio.Event()

    async def pty_to_ws():
        read_queue = asyncio.Queue()

        def on_readable():
            try:
                data = os.read(master_fd, 16384)
                if data:
                    read_queue.put_nowait(data)
                else:
                    closed.set()
            except OSError:
                closed.set()

        loop.add_reader(master_fd, on_readable)
        try:
            while not closed.is_set():
                try:
                    data = await asyncio.wait_for(read_queue.get(), timeout=1)
                    await ws.send(data)
                except asyncio.TimeoutError:
                    continue
                except (
                    websockets.exceptions.ConnectionClosed,
                    BrokenPipeError,
                ):
                    break
        finally:
            loop.remove_reader(master_fd)

    async def ws_to_pty():
        try:
            async for message in ws:
                if isinstance(message, str):
                    try:
                        msg = json.loads(message)
                        if msg.get("type") == "resize":
                            cols = int(msg.get("cols", 80))
                            rows = int(msg.get("rows", 24))
                            ws_buf = struct.pack("HHHH", rows, cols, 0, 0)
                            fcntl.ioctl(master_fd, termios.TIOCSWINSZ, ws_buf)
                            os.kill(pid, signal.SIGWINCH)
                    except (json.JSONDecodeError, ValueError, OSError):
                        pass
                elif isinstance(message, bytes):
                    try:
                        os.write(master_fd, message)
                    except OSError:
                        break
        except websockets.exceptions.ConnectionClosed:
            pass
        finally:
            closed.set()

    try:
        await asyncio.gather(pty_to_ws(), ws_to_pty())
    finally:
        try:
            os.close(master_fd)
        except OSError:
            pass
        try:
            os.kill(pid, signal.SIGTERM)
        except OSError:
            pass
        try:
            os.waitpid(pid, os.WNOHANG)
        except ChildProcessError:
            pass


async def _terminal_handler_subprocess(ws, cmd):
    """Windows fallback: subprocess pipes (no PTY)."""
    import subprocess

    proc = await asyncio.create_subprocess_exec(
        *cmd,
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
    )
    closed = asyncio.Event()

    async def proc_to_ws():
        try:
            while not closed.is_set():
                data = await proc.stdout.read(4096)
                if not data:
                    break
                await ws.send(data)
        except (websockets.exceptions.ConnectionClosed, BrokenPipeError):
            pass
        finally:
            closed.set()

    async def ws_to_proc():
        try:
            async for message in ws:
                if isinstance(message, bytes) and proc.stdin:
                    proc.stdin.write(message)
                    await proc.stdin.drain()
        except (websockets.exceptions.ConnectionClosed, BrokenPipeError):
            pass
        finally:
            closed.set()

    try:
        await asyncio.gather(proc_to_ws(), ws_to_proc())
    finally:
        try:
            proc.kill()
        except OSError:
            pass


async def main():
    port = PORT
    if "--port" in sys.argv:
        idx = sys.argv.index("--port")
        port = int(sys.argv[idx + 1])

    bind_host = "0.0.0.0"  # All interfaces for mesh access
    async with websockets.serve(
        terminal_handler,
        bind_host,
        port,
        origins=None,  # Allow all origins (cross-port)
    ):
        print(f"\033[1;35m◈ Terminal Server\033[0m → ws://{bind_host}:{port}")
        print(f"  Peers: {PEERS_CONF}")
        print(f"  Press Ctrl+C to stop\n")
        await asyncio.Future()  # Run forever


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        print("\nShutdown.")
