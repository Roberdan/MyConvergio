"""SSE streaming helper for dashboard_web API handlers.

Extracts the Popen+readline+sse_send pattern shared by api_mesh.py
and api_plans.py into a single reusable function.
"""

import os
import subprocess


def run_command_sse(
    handler,
    cmd: str,
    *,
    timeout: int = 60,
    env: dict[str, str] | None = None,
    cwd: str | None = None,
) -> None:
    """Run shell command and stream output lines as SSE log events.

    Sends each stdout line as ``handler._sse_send("log", line)`` and a final
    ``handler._sse_send("done", {...})`` with ok/exit_code on completion.
    Handles TimeoutExpired (terminates process) and arbitrary exceptions.

    Args:
        handler: HTTP handler with ``_sse_send(event, data)`` method.
        cmd: Shell command to execute (passed to ``shell=True``).
        timeout: Seconds before process is force-terminated (default 60).
        env: Environment dict for the subprocess; defaults to ``os.environ``.
        cwd: Working directory for the subprocess.
    """
    effective_env = env if env is not None else dict(os.environ)
    try:
        proc = subprocess.Popen(
            cmd,
            shell=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            env=effective_env,
            cwd=cwd,
        )
        for line in proc.stdout:
            handler._sse_send("log", line.rstrip())
        proc.wait(timeout=timeout)
        handler._sse_send(
            "done", {"ok": proc.returncode == 0, "exit_code": proc.returncode}
        )
    except subprocess.TimeoutExpired:
        proc.terminate()
        handler._sse_send(
            "done",
            {"ok": False, "exit_code": 1, "message": f"Timeout ({timeout}s)"},
        )
    except Exception as exc:
        handler._sse_send("done", {"ok": False, "message": str(exc)})
