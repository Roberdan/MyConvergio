"""Shared SSH runner for dashboard_web.

Provides ssh_run() and ssh_ok() used by server.py and mesh_handoff.py.
SSH_OPTS mirrors the defaults used throughout the codebase.
"""

import subprocess

SSH_OPTS = [
    "-o",
    "ConnectTimeout=10",
    "-o",
    "BatchMode=yes",
    "-o",
    "StrictHostKeyChecking=accept-new",
]


def ssh_run(dest: str, cmd: str, timeout: int = 15) -> subprocess.CompletedProcess:
    """Run a command on a remote host via SSH.

    Args:
        dest: SSH destination (ssh_alias or user@host).
        cmd: Shell command to run on the remote.
        timeout: subprocess timeout in seconds.

    Returns:
        CompletedProcess with stdout/stderr captured as text.

    Raises:
        subprocess.TimeoutExpired: if the command exceeds timeout.
        OSError: if SSH binary is not found.
    """
    return subprocess.run(
        ["ssh"] + SSH_OPTS + [dest, cmd],
        capture_output=True,
        text=True,
        timeout=timeout,
    )


def ssh_ok(dest: str, timeout: int = 8) -> bool:
    """Check whether an SSH connection to dest succeeds.

    Returns True if the connection and echo succeed, False on any error.
    Never raises — designed for liveness checks.
    """
    try:
        r = ssh_run(dest, "echo ok", timeout=timeout)
        return r.returncode == 0
    except (subprocess.TimeoutExpired, OSError):
        return False
