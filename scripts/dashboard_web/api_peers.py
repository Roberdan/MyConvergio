"""REST API endpoints for peer CRUD operations.

Endpoints:
  GET  /api/peers          - List peers with heartbeat status
  POST /api/peers          - Create new peer
  PUT  /api/peers/<name>   - Update existing peer
  DELETE /api/peers/<name> - Delete peer (soft/hard)
  POST /api/peers/ssh-check - Test SSH connectivity
  GET  /api/peers/discover  - Auto-discover via Tailscale
"""

import json
import re
import subprocess
import sys
import time
from pathlib import Path

if __package__ in (None, ""):
    sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
    from scripts.dashboard_web.middleware import PEERS_CONF, query
    from scripts.dashboard_web.peers_writer import PeersWriter
else:
    from .middleware import PEERS_CONF, query
    from .peers_writer import PeersWriter

_writer = PeersWriter(PEERS_CONF)
_REQUIRED_CREATE = ("ssh_alias", "user", "os", "role")
_VALID_OS = ("macos", "linux", "windows")
_VALID_ROLES = ("coordinator", "worker", "hybrid")
_VALID_ENGINES = ("claude", "copilot", "opencode", "ollama")
_MAC_RE = re.compile(r"^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$")
_IP_RE = re.compile(r"^100\.\d{1,3}\.\d{1,3}\.\d{1,3}$")
_NAME_RE = re.compile(r"^[a-zA-Z0-9_.-]+$")


def _parse_body(handler) -> dict:
    length = int(handler.headers.get("Content-Length", 0))
    if length == 0:
        return {}
    return json.loads(handler.rfile.read(length))


def _validate_create(data: dict) -> str | None:
    for field in _REQUIRED_CREATE:
        if not data.get(field):
            return f"Missing required field: {field}"
    if not data.get("peer_name") or not _NAME_RE.match(data["peer_name"]):
        return "Invalid or missing peer_name"
    if data["os"] not in _VALID_OS:
        return f"Invalid os: {data['os']}"
    if data["role"] not in _VALID_ROLES:
        return f"Invalid role: {data['role']}"
    if data.get("mac_address") and not _MAC_RE.match(data["mac_address"]):
        return f"Invalid MAC format: {data['mac_address']}"
    if data.get("tailscale_ip") and not _IP_RE.match(data["tailscale_ip"]):
        return f"Invalid IP format: {data['tailscale_ip']}"
    if data.get("default_engine") and data["default_engine"] not in _VALID_ENGINES:
        return f"Invalid engine: {data['default_engine']}"
    return None


def api_peer_list() -> dict:
    peers = _writer.list_peers()
    hb_map = {}
    for r in query("SELECT peer_name, last_seen FROM peer_heartbeats"):
        hb_map[r["peer_name"]] = r["last_seen"]
    now = time.time()
    for p in peers:
        ls = hb_map.get(p["peer_name"])
        p["last_heartbeat_age_sec"] = int(now - ls) if ls else -1
    return {"peers": peers}


def api_peer_create(handler) -> tuple[dict, int]:
    data = _parse_body(handler)
    err = _validate_create(data)
    if err:
        return {"error": err}, 400
    try:
        result = _writer.add_peer(data)
        return result, 201
    except ValueError as e:
        return {"error": str(e)}, 400


def api_peer_update(handler, name: str) -> tuple[dict, int]:
    data = _parse_body(handler)
    if data.get("os") and data["os"] not in _VALID_OS:
        return {"error": f"Invalid os: {data['os']}"}, 400
    if data.get("role") and data["role"] not in _VALID_ROLES:
        return {"error": f"Invalid role: {data['role']}"}, 400
    if data.get("mac_address") and not _MAC_RE.match(data["mac_address"]):
        return {"error": f"Invalid MAC: {data['mac_address']}"}, 400
    if data.get("tailscale_ip") and not _IP_RE.match(data["tailscale_ip"]):
        return {"error": f"Invalid IP: {data['tailscale_ip']}"}, 400
    if data.get("default_engine") and data["default_engine"] not in _VALID_ENGINES:
        return {"error": f"Invalid engine: {data['default_engine']}"}, 400
    try:
        result = _writer.update_peer(name, data)
        return result, 200
    except ValueError as e:
        return {"error": str(e)}, 404


def api_peer_delete(name: str, mode: str = "soft") -> tuple[dict, int]:
    try:
        result = _writer.delete_peer(name, mode)
        return result, 200
    except ValueError as e:
        return {"error": str(e)}, 404


def api_peer_ssh_check(handler) -> tuple[dict, int]:
    """Test SSH connectivity with 5s timeout (C-03). Tries ssh_alias then tailscale_ip."""
    data = _parse_body(handler)
    ssh_alias = data.get("ssh_alias", "")
    tailscale_ip = data.get("tailscale_ip", "")
    user = data.get("user", "")
    if not ssh_alias and not tailscale_ip:
        return {"error": "Need ssh_alias or tailscale_ip"}, 400

    for host in [ssh_alias, tailscale_ip]:
        if not host:
            continue
        target = f"{user}@{host}" if user else host
        start = time.time()
        try:
            r = subprocess.run(
                [
                    "ssh",
                    "-o",
                    "ConnectTimeout=5",
                    "-o",
                    "BatchMode=yes",
                    target,
                    "echo ok",
                ],
                capture_output=True,
                text=True,
                timeout=6,
            )
            latency = int((time.time() - start) * 1000)
            if r.returncode == 0:
                return {"ok": True, "latency_ms": latency, "host": host}, 200
        except (subprocess.TimeoutExpired, OSError):
            continue
    return {"ok": False, "error": "SSH unreachable", "latency_ms": -1}, 200


def api_peer_discover() -> dict:
    """Discover peers via tailscale status --json, diff with peers.conf."""
    try:
        r = subprocess.run(
            ["tailscale", "status", "--json"],
            capture_output=True,
            text=True,
            timeout=10,
        )
        if r.returncode != 0:
            return {"error": "tailscale status failed", "discovered": []}
    except (subprocess.TimeoutExpired, FileNotFoundError):
        return {"error": "tailscale not available", "discovered": []}

    ts_data = json.loads(r.stdout)
    existing = {p["peer_name"].lower() for p in _writer.list_peers()}
    discovered = []
    peers_map = ts_data.get("Peer", {})
    for _key, info in peers_map.items():
        raw = info.get("HostName", "").split(".")[0].lower()
        hostname = re.sub(r"[^a-z0-9_.-]", "-", raw).strip("-")
        hostname = re.sub(r"-+", "-", hostname)
        if not hostname or hostname in existing:
            continue
        ips = info.get("TailscaleIPs", [])
        ts_ip = next((ip for ip in ips if ip.startswith("100.")), "")
        discovered.append(
            {
                "hostname": hostname,
                "tailscale_ip": ts_ip,
                "dns_name": info.get("DNSName", "").rstrip("."),
                "os": "windows" if "windows" in info.get("OS", "").lower() else ("linux" if "linux" in info.get("OS", "").lower() else "macos"),
                "is_new": True,
            }
        )
    return {"discovered": discovered}
