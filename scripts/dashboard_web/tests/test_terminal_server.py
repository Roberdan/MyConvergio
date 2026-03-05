"""Tests for terminal_server.py get_ssh_config function."""

import configparser
import os
import tempfile
from pathlib import Path
from unittest.mock import patch

import pytest

# We import the module under test - but need to mock out the PEERS_CONF path
import sys

sys.path.insert(0, str(Path(__file__).parent.parent))


def make_peers_conf(content: str) -> Path:
    """Helper: write peers.conf to a temp file and return its Path."""
    tmp = tempfile.NamedTemporaryFile(
        mode="w", suffix=".conf", delete=False, encoding="utf-8"
    )
    tmp.write(content)
    tmp.flush()
    tmp.close()
    return Path(tmp.name)


SAMPLE_PEERS_CONF = """
[m3max]
ssh_alias=robertos-macbook-pro-m3-max.tail01f12c.ts.net
user=roberdan
os=macos
role=coordinator
status=active

[omarchy]
ssh_alias=omarchy.tail01f12c.ts.net
user=roberdan
os=linux
role=worker
status=active

[m1mario]
ssh_alias=mariodans-macbook-pro-m1.tail01f12c.ts.net
user=mariodan
os=macos
role=worker
status=active
"""


class TestGetSshConfig:
    """Tests for get_ssh_config (renamed from get_ssh_target)."""

    def _import_with_conf(self, conf_path: Path):
        """Import terminal_server with a patched PEERS_CONF path."""
        import importlib
        import terminal_server

        importlib.reload(terminal_server)
        terminal_server.PEERS_CONF = conf_path
        return terminal_server

    def test_returns_dict(self):
        """get_ssh_config returns a dict, not a string."""
        conf = make_peers_conf(SAMPLE_PEERS_CONF)
        try:
            ts = self._import_with_conf(conf)
            result = ts.get_ssh_config("m1mario")
            assert isinstance(result, dict), f"Expected dict, got {type(result)}"
        finally:
            os.unlink(conf)

    def test_returns_user_and_host(self):
        """Dict contains 'user' and 'host' keys."""
        conf = make_peers_conf(SAMPLE_PEERS_CONF)
        try:
            ts = self._import_with_conf(conf)
            result = ts.get_ssh_config("m1mario")
            assert "user" in result, "Missing 'user' key"
            assert "host" in result, "Missing 'host' key"
        finally:
            os.unlink(conf)

    def test_correct_user_m1mario(self):
        """m1mario peer returns user=mariodan."""
        conf = make_peers_conf(SAMPLE_PEERS_CONF)
        try:
            ts = self._import_with_conf(conf)
            result = ts.get_ssh_config("m1mario")
            assert result["user"] == "mariodan"
        finally:
            os.unlink(conf)

    def test_correct_host_m1mario(self):
        """m1mario peer returns correct ssh_alias as host."""
        conf = make_peers_conf(SAMPLE_PEERS_CONF)
        try:
            ts = self._import_with_conf(conf)
            result = ts.get_ssh_config("m1mario")
            assert result["host"] == "mariodans-macbook-pro-m1.tail01f12c.ts.net"
        finally:
            os.unlink(conf)

    def test_correct_user_omarchy(self):
        """omarchy peer returns user=roberdan."""
        conf = make_peers_conf(SAMPLE_PEERS_CONF)
        try:
            ts = self._import_with_conf(conf)
            result = ts.get_ssh_config("omarchy")
            assert result["user"] == "roberdan"
            assert result["host"] == "omarchy.tail01f12c.ts.net"
        finally:
            os.unlink(conf)

    def test_fallback_unknown_peer(self):
        """Unknown peer falls back to OS user and peer_name as host."""
        conf = make_peers_conf(SAMPLE_PEERS_CONF)
        try:
            ts = self._import_with_conf(conf)
            result = ts.get_ssh_config("unknown-peer")
            assert result["host"] == "unknown-peer"
            # user should be current OS user
            assert result["user"] == os.getlogin() or result["user"] == os.environ.get(
                "USER", os.environ.get("LOGNAME", "")
            )
        finally:
            os.unlink(conf)

    def test_fallback_no_conf_file(self):
        """No peers.conf falls back gracefully."""
        import terminal_server
        import importlib

        importlib.reload(terminal_server)
        terminal_server.PEERS_CONF = Path("/nonexistent/path/peers.conf")
        result = terminal_server.get_ssh_config("some-peer")
        assert isinstance(result, dict)
        assert result["host"] == "some-peer"
        assert isinstance(result["user"], str)
        assert len(result["user"]) > 0

    def test_get_ssh_target_removed(self):
        """get_ssh_target no longer exists (replaced by get_ssh_config)."""
        import terminal_server
        import importlib

        importlib.reload(terminal_server)
        assert not hasattr(
            terminal_server, "get_ssh_target"
        ), "get_ssh_target should be removed, use get_ssh_config instead"


class TestSshCommandConstruction:
    """Tests that the SSH command in terminal_handler uses user@host format."""

    def test_ssh_cmd_uses_user_at_host(self):
        """Verify that ssh command in terminal_handler is built as user@host."""
        import terminal_server
        import importlib

        importlib.reload(terminal_server)
        # Inspect source to verify user@host pattern
        import inspect

        source = inspect.getsource(terminal_server.terminal_handler)
        assert (
            "user" in source and "@" in source
        ), "terminal_handler should build ssh cmd as user@host"

    def test_ssh_options_include_strict_host_checking(self):
        """SSH command includes StrictHostKeyChecking=accept-new."""
        import terminal_server
        import importlib

        importlib.reload(terminal_server)
        import inspect

        source = inspect.getsource(terminal_server.terminal_handler)
        assert "StrictHostKeyChecking=accept-new" in source
