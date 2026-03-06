"""Tests for lib.sse.run_command_sse helper function."""

import sys
import os
import subprocess
import unittest
from unittest.mock import MagicMock, patch, call

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))


class TestRunCommandSse(unittest.TestCase):
    """Verify run_command_sse extracts the Popen+readline+sse_send pattern."""

    def _make_handler(self):
        handler = MagicMock()
        handler._sse_send = MagicMock()
        return handler

    def test_import(self):
        """Module must be importable from lib.sse."""
        from lib.sse import run_command_sse  # noqa: F401

    def test_success_streams_lines(self):
        """Each line from stdout must be sent as 'log' SSE event."""
        from lib.sse import run_command_sse

        handler = self._make_handler()
        proc = MagicMock()
        proc.stdout = iter(["line one\n", "line two\n", ""])
        proc.returncode = 0
        proc.wait = MagicMock()

        with patch("subprocess.Popen", return_value=proc):
            run_command_sse(handler, "echo test", timeout=30)

        log_calls = [c for c in handler._sse_send.call_args_list if c[0][0] == "log"]
        messages = [c[0][1] for c in log_calls]
        assert "line one" in messages, f"Expected 'line one' in {messages}"
        assert "line two" in messages, f"Expected 'line two' in {messages}"

    def test_success_sends_done_ok(self):
        """On returncode==0, done event must have ok=True."""
        from lib.sse import run_command_sse

        handler = self._make_handler()
        proc = MagicMock()
        proc.stdout = iter([""])
        proc.returncode = 0
        proc.wait = MagicMock()

        with patch("subprocess.Popen", return_value=proc):
            run_command_sse(handler, "echo ok", timeout=30)

        done_calls = [c for c in handler._sse_send.call_args_list if c[0][0] == "done"]
        assert done_calls, "Expected a 'done' SSE event"
        done_data = done_calls[0][0][1]
        assert done_data.get("ok") is True

    def test_failure_sends_done_not_ok(self):
        """On non-zero returncode, done event must have ok=False."""
        from lib.sse import run_command_sse

        handler = self._make_handler()
        proc = MagicMock()
        proc.stdout = iter([""])
        proc.returncode = 1
        proc.wait = MagicMock()

        with patch("subprocess.Popen", return_value=proc):
            run_command_sse(handler, "false", timeout=30)

        done_calls = [c for c in handler._sse_send.call_args_list if c[0][0] == "done"]
        assert done_calls, "Expected a 'done' SSE event"
        done_data = done_calls[0][0][1]
        assert done_data.get("ok") is False

    def test_timeout_terminates_process(self):
        """On TimeoutExpired, process must be terminated and done sent with ok=False."""
        from lib.sse import run_command_sse

        handler = self._make_handler()
        proc = MagicMock()
        proc.stdout = iter([""])
        proc.wait = MagicMock(side_effect=subprocess.TimeoutExpired("cmd", 30))
        proc.terminate = MagicMock()

        with patch("subprocess.Popen", return_value=proc):
            run_command_sse(handler, "sleep 9999", timeout=30)

        proc.terminate.assert_called_once()
        done_calls = [c for c in handler._sse_send.call_args_list if c[0][0] == "done"]
        assert done_calls, "Expected a 'done' SSE event on timeout"
        assert done_calls[0][0][1].get("ok") is False

    def test_exception_sends_done_with_message(self):
        """On unexpected exception, done event must include error message."""
        from lib.sse import run_command_sse

        handler = self._make_handler()
        with patch("subprocess.Popen", side_effect=OSError("bad cmd")):
            run_command_sse(handler, "badcmd", timeout=30)

        done_calls = [c for c in handler._sse_send.call_args_list if c[0][0] == "done"]
        assert done_calls, "Expected a 'done' SSE event on exception"
        done_data = done_calls[0][0][1]
        assert done_data.get("ok") is False
        assert "bad cmd" in str(done_data.get("message", ""))

    def test_custom_env_passed_to_popen(self):
        """Custom env dict must be forwarded to Popen."""
        from lib.sse import run_command_sse

        handler = self._make_handler()
        proc = MagicMock()
        proc.stdout = iter([""])
        proc.returncode = 0
        proc.wait = MagicMock()
        custom_env = {"MY_VAR": "hello"}

        with patch("subprocess.Popen", return_value=proc) as mock_popen:
            run_command_sse(handler, "echo $MY_VAR", timeout=30, env=custom_env)

        mock_popen.assert_called_once()
        _, kwargs = mock_popen.call_args
        assert kwargs.get("env") == custom_env

    def test_lines_rstripped(self):
        """Log messages must have trailing whitespace stripped."""
        from lib.sse import run_command_sse

        handler = self._make_handler()
        proc = MagicMock()
        proc.stdout = iter(["hello   \n", ""])
        proc.returncode = 0
        proc.wait = MagicMock()

        with patch("subprocess.Popen", return_value=proc):
            run_command_sse(handler, "echo test", timeout=30)

        log_calls = [c for c in handler._sse_send.call_args_list if c[0][0] == "log"]
        messages = [c[0][1] for c in log_calls]
        assert "hello" in messages, f"Expected stripped 'hello' in {messages}"
        assert "hello   " not in messages, "Line must be rstripped"


if __name__ == "__main__":
    unittest.main()
