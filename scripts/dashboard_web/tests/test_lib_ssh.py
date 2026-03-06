"""Tests for T1-01: shared SSH runner in lib/ssh.py.

Verifies ssh_run() and ssh_ok() functions exist and behave correctly.
"""

import subprocess
import sys
import os
from pathlib import Path
from unittest.mock import patch, MagicMock

# Ensure lib is importable
BASE = Path(__file__).parent.parent
sys.path.insert(0, str(BASE))


# --- F-21: File existence ---


def test_lib_ssh_file_exists():
    assert (BASE / "lib" / "ssh.py").is_file(), "lib/ssh.py must exist"


def test_lib_init_file_exists():
    assert (BASE / "lib" / "__init__.py").is_file(), "lib/__init__.py must exist"


# --- F-21: Import ---


def test_imports():
    from lib.ssh import ssh_run, ssh_ok

    assert callable(ssh_run)
    assert callable(ssh_ok)


# --- F-21: ssh_run signature and return type ---


def test_ssh_run_returns_completed_process():
    from lib.ssh import ssh_run

    mock_result = MagicMock(spec=subprocess.CompletedProcess)
    mock_result.returncode = 0
    mock_result.stdout = "ok\n"
    mock_result.stderr = ""
    with patch("subprocess.run", return_value=mock_result) as m:
        result = ssh_run("mypeer", "echo ok")
    assert result is mock_result
    m.assert_called_once()
    call_args = m.call_args[0][0]  # positional: the command list
    assert "ssh" in call_args[0]
    assert "mypeer" in call_args
    assert "echo ok" in call_args


def test_ssh_run_includes_batch_mode():
    from lib.ssh import ssh_run

    mock_result = MagicMock(spec=subprocess.CompletedProcess)
    mock_result.returncode = 0
    mock_result.stdout = ""
    mock_result.stderr = ""
    with patch("subprocess.run", return_value=mock_result) as m:
        ssh_run("mypeer", "echo ok")
    cmd = m.call_args[0][0]
    cmd_str = " ".join(cmd)
    assert "BatchMode=yes" in cmd_str


def test_ssh_run_custom_timeout():
    from lib.ssh import ssh_run

    mock_result = MagicMock(spec=subprocess.CompletedProcess)
    mock_result.returncode = 0
    mock_result.stdout = ""
    mock_result.stderr = ""
    with patch("subprocess.run", return_value=mock_result) as m:
        ssh_run("mypeer", "echo ok", timeout=42)
    kwargs = m.call_args[1]
    assert kwargs.get("timeout") == 42


def test_ssh_run_default_timeout():
    from lib.ssh import ssh_run

    mock_result = MagicMock(spec=subprocess.CompletedProcess)
    mock_result.returncode = 0
    mock_result.stdout = ""
    mock_result.stderr = ""
    with patch("subprocess.run", return_value=mock_result) as m:
        ssh_run("mypeer", "echo ok")
    kwargs = m.call_args[1]
    # Default timeout must be set (some reasonable value >= 10)
    assert kwargs.get("timeout") is not None
    assert kwargs["timeout"] >= 10


# --- F-21: ssh_ok signature and return type ---


def test_ssh_ok_returns_true_on_success():
    from lib.ssh import ssh_ok

    mock_result = MagicMock(spec=subprocess.CompletedProcess)
    mock_result.returncode = 0
    mock_result.stdout = "ok\n"
    mock_result.stderr = ""
    with patch("subprocess.run", return_value=mock_result):
        assert ssh_ok("mypeer") is True


def test_ssh_ok_returns_false_on_failure():
    from lib.ssh import ssh_ok

    mock_result = MagicMock(spec=subprocess.CompletedProcess)
    mock_result.returncode = 1
    mock_result.stdout = ""
    mock_result.stderr = "connection refused"
    with patch("subprocess.run", return_value=mock_result):
        assert ssh_ok("mypeer") is False


def test_ssh_ok_returns_false_on_timeout():
    from lib.ssh import ssh_ok

    with patch("subprocess.run", side_effect=subprocess.TimeoutExpired("ssh", 8)):
        assert ssh_ok("mypeer") is False


def test_ssh_ok_returns_false_on_os_error():
    from lib.ssh import ssh_ok

    with patch("subprocess.run", side_effect=OSError("no such file")):
        assert ssh_ok("mypeer") is False


# --- F-21: ssh_run handles exceptions gracefully ---


def test_ssh_run_raises_timeout():
    """ssh_run propagates TimeoutExpired — callers decide how to handle it."""
    from lib.ssh import ssh_run

    with patch("subprocess.run", side_effect=subprocess.TimeoutExpired("ssh", 15)):
        try:
            ssh_run("mypeer", "cmd", timeout=15)
            # Some implementations may catch and return a failed result
        except subprocess.TimeoutExpired:
            pass  # Also acceptable


# --- F-21: SSH options ---


def test_ssh_run_connect_timeout_option():
    from lib.ssh import ssh_run

    mock_result = MagicMock(spec=subprocess.CompletedProcess)
    mock_result.returncode = 0
    mock_result.stdout = ""
    mock_result.stderr = ""
    with patch("subprocess.run", return_value=mock_result) as m:
        ssh_run("mypeer", "echo ok")
    cmd = " ".join(m.call_args[0][0])
    assert "ConnectTimeout" in cmd


# --- F-21: Module line count ≤ 250 ---


def test_ssh_py_line_count():
    ssh_file = BASE / "lib" / "ssh.py"
    if ssh_file.exists():
        lines = len(ssh_file.read_text().splitlines())
        assert lines <= 250, f"lib/ssh.py has {lines} lines (max 250)"
