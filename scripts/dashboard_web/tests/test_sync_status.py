"""Tests for /api/mesh/sync-status — logic lives in lib/mesh_helpers.py."""

import sys
import time
from pathlib import Path
from unittest.mock import MagicMock, patch

import pytest

sys.path.insert(0, str(Path(__file__).parent.parent))

import server  # noqa: E402
import lib.mesh_helpers as mesh_helpers  # noqa: E402


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

SAMPLE_PEERS_CONF = """
[m3max]
ssh_alias=robertos-macbook-pro-m3-max.ts.net
user=roberdan
os=macos
role=coordinator
status=active

[omarchy]
ssh_alias=omarchy.ts.net
user=roberdan
os=linux
role=worker
status=active

[inactive_peer]
ssh_alias=inactive.ts.net
user=roberdan
os=linux
role=worker
status=inactive
"""


def _make_peers_conf(tmp_path, content=SAMPLE_PEERS_CONF):
    p = tmp_path / "peers.conf"
    p.write_text(content)
    return p


# ---------------------------------------------------------------------------
# Unit: _check_peer_sync (now in lib.mesh_helpers)
# ---------------------------------------------------------------------------


class TestCheckPeerSync:
    def test_reachable_synced(self, tmp_path):
        """Peer reachable and HEAD matches local HEAD."""
        sha = "abc1234 commit msg"

        local_result = MagicMock()
        local_result.returncode = 0
        local_result.stdout = sha

        remote_result = MagicMock()
        remote_result.returncode = 0
        remote_result.stdout = sha

        with patch("lib.mesh_helpers.subprocess.run", return_value=local_result):
            with patch("lib.mesh_helpers.ssh_run", return_value=remote_result):
                result = mesh_helpers._check_peer_sync(
                    "omarchy", "roberdan", "omarchy.ts.net"
                )

        assert result["peer_name"] == "omarchy"
        assert result["reachable"] is True
        assert result["config_synced"] is True

    def test_reachable_not_synced(self, tmp_path):
        """Peer reachable but HEAD differs from local."""
        local_result = MagicMock()
        local_result.returncode = 0
        local_result.stdout = "abc1234 commit A"

        remote_result = MagicMock()
        remote_result.returncode = 0
        remote_result.stdout = "def5678 commit B"

        with patch("lib.mesh_helpers.subprocess.run", return_value=local_result):
            with patch("lib.mesh_helpers.ssh_run", return_value=remote_result):
                result = mesh_helpers._check_peer_sync(
                    "omarchy", "roberdan", "omarchy.ts.net"
                )

        assert result["reachable"] is True
        assert result["config_synced"] is False

    def test_unreachable_peer(self):
        """SSH fails → reachable=false, config_synced=null."""
        import subprocess

        local_result = MagicMock()
        local_result.returncode = 0
        local_result.stdout = "abc1234 commit msg"

        with patch("lib.mesh_helpers.subprocess.run", return_value=local_result):
            with patch(
                "lib.mesh_helpers.ssh_run",
                side_effect=subprocess.TimeoutExpired("ssh", 5),
            ):
                result = mesh_helpers._check_peer_sync(
                    "omarchy", "roberdan", "omarchy.ts.net"
                )

        assert result["reachable"] is False
        assert result["config_synced"] is None

    def test_ssh_nonzero_exit(self):
        """SSH returns nonzero → unreachable."""
        local_result = MagicMock()
        local_result.returncode = 0
        local_result.stdout = "abc1234 commit msg"

        remote_result = MagicMock()
        remote_result.returncode = 255  # connection refused

        with patch("lib.mesh_helpers.subprocess.run", return_value=local_result):
            with patch("lib.mesh_helpers.ssh_run", return_value=remote_result):
                result = mesh_helpers._check_peer_sync(
                    "omarchy", "roberdan", "omarchy.ts.net"
                )

        assert result["reachable"] is False
        assert result["config_synced"] is None


# ---------------------------------------------------------------------------
# Unit: api_mesh_sync_status (now in lib.mesh_helpers)
# ---------------------------------------------------------------------------


class TestApiMeshSyncStatus:
    def test_returns_list_per_active_peer(self, tmp_path, monkeypatch):
        """Returns one entry per active peer (skips inactive)."""
        peers_path = _make_peers_conf(tmp_path)
        monkeypatch.setattr(mesh_helpers, "PEERS_CONF", peers_path)
        mesh_helpers._sync_cache["data"] = None
        mesh_helpers._sync_cache["ts"] = 0

        def fake_check(peer_name, user, host):
            return {
                "peer_name": peer_name,
                "reachable": True,
                "config_synced": True,
                "last_heartbeat_age_sec": 10,
            }

        with patch("lib.mesh_helpers._check_peer_sync", side_effect=fake_check):
            with patch("lib.mesh_helpers.query", return_value=[]):
                result = mesh_helpers.api_mesh_sync_status()

        names = [r["peer_name"] for r in result]
        assert "m3max" in names
        assert "omarchy" in names
        assert "inactive_peer" not in names

    def test_cache_returns_stale_within_60s(self, tmp_path, monkeypatch):
        """Result is cached for 60s; second call must not re-check peers."""
        peers_path = _make_peers_conf(tmp_path)
        monkeypatch.setattr(mesh_helpers, "PEERS_CONF", peers_path)

        stale_data = [{"peer_name": "cached", "reachable": True, "config_synced": True}]
        mesh_helpers._sync_cache["data"] = stale_data
        mesh_helpers._sync_cache["ts"] = time.time() - 30  # 30s old → still fresh

        with patch("lib.mesh_helpers._check_peer_sync") as mock_check:
            result = mesh_helpers.api_mesh_sync_status()
            mock_check.assert_not_called()

        assert result == stale_data

        mesh_helpers._sync_cache["data"] = None
        mesh_helpers._sync_cache["ts"] = 0

    def test_cache_refreshes_after_60s(self, tmp_path, monkeypatch):
        """Expired cache (>60s) triggers a new check."""
        peers_path = _make_peers_conf(tmp_path)
        monkeypatch.setattr(mesh_helpers, "PEERS_CONF", peers_path)

        old_data = [{"peer_name": "old", "reachable": True, "config_synced": True}]
        mesh_helpers._sync_cache["data"] = old_data
        mesh_helpers._sync_cache["ts"] = time.time() - 61  # expired

        def fake_check(peer_name, user, host):
            return {
                "peer_name": peer_name,
                "reachable": True,
                "config_synced": True,
                "last_heartbeat_age_sec": 5,
            }

        with patch("lib.mesh_helpers._check_peer_sync", side_effect=fake_check):
            with patch("lib.mesh_helpers.query", return_value=[]):
                result = mesh_helpers.api_mesh_sync_status()

        names = [r["peer_name"] for r in result]
        assert "old" not in names

        mesh_helpers._sync_cache["data"] = None
        mesh_helpers._sync_cache["ts"] = 0

    def test_last_heartbeat_age_populated(self, tmp_path, monkeypatch):
        """last_heartbeat_age_sec is computed from peer_heartbeats DB."""
        peers_path = _make_peers_conf(tmp_path)
        monkeypatch.setattr(mesh_helpers, "PEERS_CONF", peers_path)
        mesh_helpers._sync_cache["data"] = None
        mesh_helpers._sync_cache["ts"] = 0

        now = time.time()
        hb_rows = [
            {"peer_name": "m3max", "last_seen": now - 42},
            {"peer_name": "omarchy", "last_seen": now - 120},
        ]

        def fake_check(peer_name, user, host):
            return {
                "peer_name": peer_name,
                "reachable": True,
                "config_synced": True,
                "last_heartbeat_age_sec": -1,
            }

        with patch("lib.mesh_helpers._check_peer_sync", side_effect=fake_check):
            with patch("lib.mesh_helpers.query", return_value=hb_rows):
                result = mesh_helpers.api_mesh_sync_status()

        m3max_entry = next((r for r in result if r["peer_name"] == "m3max"), None)
        omarchy_entry = next((r for r in result if r["peer_name"] == "omarchy"), None)
        assert m3max_entry is not None
        assert 40 <= m3max_entry["last_heartbeat_age_sec"] <= 45
        assert omarchy_entry is not None
        assert 118 <= omarchy_entry["last_heartbeat_age_sec"] <= 122


# ---------------------------------------------------------------------------
# Integration: ROUTES registration (server re-exports api_mesh_sync_status)
# ---------------------------------------------------------------------------


class TestRoutesRegistration:
    def test_sync_status_in_routes(self):
        """/api/mesh/sync-status must be registered in ROUTES."""
        assert "/api/mesh/sync-status" in server.ROUTES

    def test_sync_status_route_is_callable(self):
        """ROUTES['/api/mesh/sync-status'] must be the api_mesh_sync_status function."""
        from scripts.dashboard_web.lib.mesh_helpers import api_mesh_sync_status

        assert server.ROUTES["/api/mesh/sync-status"] is api_mesh_sync_status
