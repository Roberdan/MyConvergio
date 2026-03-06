"""Convergio Control Room — Web Dashboard Server.

Usage: python3 server.py [--port 8420]
"""

import concurrent.futures
import configparser
import re
import subprocess
import sys
import time
from http.server import HTTPServer, SimpleHTTPRequestHandler
from pathlib import Path
from socketserver import ThreadingMixIn
from urllib.parse import parse_qs, urlparse

import api_mesh as api_mesh_mod
from api_dashboard import (
    api_assignable_plans as _api_assignable_plans,
    api_coordinator_status as _api_coordinator_status,
    api_coordinator_toggle as _api_coordinator_toggle,
    api_events as _api_events,
    api_history as _api_history,
    api_mission as _api_mission,
    api_notifications as _api_notifications,
    api_overview as _api_overview,
    api_plan_detail as _api_plan_detail,
    api_task_status_dist as _api_task_status_dist,
    api_tasks_blocked as _api_tasks_blocked,
    api_tokens_by_model as _api_tokens_by_model,
    api_tokens_daily as _api_tokens_daily,
)
from api_mesh import (
    handle_fullsync_sse,
    handle_mesh_action,
    handle_mesh_action_sse,
    resolve_host_to_peer,
)
from api_peers import (
    api_peer_create,
    api_peer_delete,
    api_peer_discover,
    api_peer_list,
    api_peer_ssh_check,
    api_peer_update,
)
from api_plans import (
    api_preflight_sse,
    handle_plan_cancel,
    handle_plan_delegate,
    handle_plan_move,
    handle_plan_reset,
    handle_plan_start_sse,
    handle_pull_remote_db,
)
from api_terminal import handle_terminal
from middleware import (
    DB_PATH,
    PEERS_CONF as _PEERS_CONF,
    PORT,
    MiddlewareMixin,
    query,
    validate_queries_on_boot,
)

STATIC_DIR = Path(__file__).parent
PEERS_CONF = _PEERS_CONF
ALLOWED_ORIGINS = {f"http://localhost:{PORT}", f"http://127.0.0.1:{PORT}"}
_SAFE_NAME = re.compile(r"^[a-zA-Z0-9_.-]+$")
_sync_cache = {"data": None, "ts": 0}


def api_overview():
    return _api_overview()


def api_mission():
    return _api_mission(resolve_host_to_peer)


def api_tokens_daily():
    return _api_tokens_daily()


def api_tokens_by_model():
    return _api_tokens_by_model()


def api_mesh():
    return api_mesh_mod.api_mesh()


def api_history():
    return _api_history()


def api_task_status_dist():
    return _api_task_status_dist()


def api_tasks_blocked():
    return _api_tasks_blocked()


def api_assignable_plans():
    return _api_assignable_plans()


def api_notifications():
    return _api_notifications()


def api_events():
    return _api_events()


def api_coordinator_status():
    return _api_coordinator_status()


def api_coordinator_toggle():
    return _api_coordinator_toggle()


def api_plan_detail(plan_id: int):
    return _api_plan_detail(plan_id)


def _check_peer_sync(peer_name: str, user: str, host: str) -> dict:
    try:
        local_sha = subprocess.run(
            ["git", "-C", str(Path.home() / ".claude"), "log", "--oneline", "-1"],
            capture_output=True,
            text=True,
            timeout=5,
        ).stdout.strip()
    except (subprocess.TimeoutExpired, OSError):
        local_sha = ""
    try:
        remote = subprocess.run(
            [
                "ssh",
                "-o",
                "ConnectTimeout=5",
                "-o",
                "BatchMode=yes",
                host,
                "-l",
                user,
                "git -C ~/.claude log --oneline -1",
            ],
            capture_output=True,
            text=True,
            timeout=5,
        )
        if remote.returncode != 0:
            return {
                "peer_name": peer_name,
                "reachable": False,
                "config_synced": None,
                "last_heartbeat_age_sec": -1,
            }
        remote_sha = remote.stdout.strip()
        return {
            "peer_name": peer_name,
            "reachable": True,
            "config_synced": bool(local_sha and remote_sha and local_sha == remote_sha),
            "last_heartbeat_age_sec": -1,
        }
    except (subprocess.TimeoutExpired, OSError):
        return {
            "peer_name": peer_name,
            "reachable": False,
            "config_synced": None,
            "last_heartbeat_age_sec": -1,
        }


def api_mesh_sync_status() -> list[dict]:
    now = time.time()
    if _sync_cache["data"] is not None and (now - _sync_cache["ts"]) < 60:
        return _sync_cache["data"]
    if not PEERS_CONF.exists():
        return []
    cp = configparser.ConfigParser()
    cp.read(str(PEERS_CONF))
    active_peers = [
        {
            "peer_name": s,
            "user": cp[s].get("user", ""),
            "host": cp[s].get("ssh_alias", s),
        }
        for s in cp.sections()
        if cp[s].get("status", "active") == "active"
    ]
    hb_map = {
        r["peer_name"]: r["last_seen"]
        for r in query("SELECT peer_name, last_seen FROM peer_heartbeats")
    }
    with concurrent.futures.ThreadPoolExecutor(max_workers=5) as pool:
        results = list(
            pool.map(
                lambda p: _check_peer_sync(p["peer_name"], p["user"], p["host"]),
                active_peers,
            )
        )
    for entry in results:
        entry["last_heartbeat_age_sec"] = (
            int(now - hb_map[entry["peer_name"]])
            if hb_map.get(entry["peer_name"])
            else -1
        )
    _sync_cache.update({"data": results, "ts": now})
    return results


ROUTES = {
    "/api/overview": api_overview,
    "/api/mission": api_mission,
    "/api/tokens/daily": api_tokens_daily,
    "/api/tokens/models": api_tokens_by_model,
    "/api/mesh": api_mesh,
    "/api/mesh/sync-status": api_mesh_sync_status,
    "/api/history": api_history,
    "/api/tasks/distribution": api_task_status_dist,
    "/api/tasks/blocked": api_tasks_blocked,
    "/api/plans/assignable": api_assignable_plans,
    "/api/notifications": api_notifications,
    "/api/events": api_events,
    "/api/coordinator/status": api_coordinator_status,
    "/api/coordinator/toggle": api_coordinator_toggle,
    "/api/peers": api_peer_list,
    "/api/peers/discover": api_peer_discover,
}


class Handler(MiddlewareMixin, SimpleHTTPRequestHandler):
    def __init__(self, *a, **kw):
        super().__init__(*a, directory=str(STATIC_DIR), **kw)

    def do_GET(self):
        parsed = urlparse(self.path)
        path = parsed.path
        qs = parse_qs(parsed.query)
        if path in ROUTES:
            self._json_response(ROUTES[path]())
            return
        if path == "/api/mesh/action":
            self._json_response(handle_mesh_action(qs, _SAFE_NAME))
            return
        if path == "/api/mesh/action/stream":
            handle_mesh_action_sse(self, qs, _SAFE_NAME)
            return
        if path == "/api/mesh/fullsync":
            handle_fullsync_sse(self, qs)
            return
        if path == "/api/terminal":
            self._json_response(handle_terminal(qs, _SAFE_NAME))
            return
        if path == "/api/plan/move":
            self._json_response(handle_plan_move(qs))
            return
        if path == "/api/plan/cancel":
            self._json_response(handle_plan_cancel(qs))
            return
        if path == "/api/plan/reset":
            self._json_response(handle_plan_reset(qs))
            return
        if path == "/api/plan/preflight":
            api_preflight_sse(self, qs)
            return
        if path == "/api/plan/delegate":
            handle_plan_delegate(self, qs, _SAFE_NAME)
            return
        if path == "/api/plan/start":
            handle_plan_start_sse(self, qs)
            return
        if path == "/api/mesh/pull-db":
            handle_pull_remote_db(self, qs)
            return
        if path.startswith("/api/plan/"):
            pid = path.split("/")[-1]
            self._json_response(
                (
                    api_plan_detail(int(pid))
                    if pid.isdigit()
                    else {"error": "invalid plan id"}
                ),
                200 if pid.isdigit() else 400,
            )
            return
        if path in ("", "/"):
            self.path = "/index.html"
        super().do_GET()

    def do_POST(self):
        parsed = urlparse(self.path)
        path = parsed.path
        if path == "/api/peers":
            data, code = api_peer_create(self)
            self._json_response(data, code)
            return
        if path == "/api/peers/ssh-check":
            data, code = api_peer_ssh_check(self)
            self._json_response(data, code)
            return
        self.send_error(405, "Method Not Allowed")

    def do_PUT(self):
        parsed = urlparse(self.path)
        path = parsed.path
        if path.startswith("/api/peers/"):
            name = path.split("/")[-1]
            if not _SAFE_NAME.match(name):
                self._json_response({"error": "invalid peer name"}, 400)
                return
            data, code = api_peer_update(self, name)
            self._json_response(data, code)
            return
        self.send_error(405, "Method Not Allowed")

    def do_DELETE(self):
        parsed = urlparse(self.path)
        path = parsed.path
        qs = parse_qs(parsed.query)
        if path.startswith("/api/peers/"):
            name = path.split("/")[-1]
            if not _SAFE_NAME.match(name):
                self._json_response({"error": "invalid peer name"}, 400)
                return
            mode = qs.get("mode", ["soft"])[0]
            data, code = api_peer_delete(name, mode)
            self._json_response(data, code)
            return
        self.send_error(405, "Method Not Allowed")

    def log_message(self, fmt, *args):
        pass


class ThreadedHTTPServer(ThreadingMixIn, HTTPServer):
    daemon_threads = True


def main():
    port = int(sys.argv[sys.argv.index("--port") + 1]) if "--port" in sys.argv else PORT

    # Validate all SQL queries against actual schema before serving
    passed, failed, errors = validate_queries_on_boot()
    if failed:
        print(
            f"\033[1;31m✗ SQL VALIDATION: {failed} queries FAILED (schema mismatch)\033[0m"
        )
        for e in errors:
            print(f"\033[31m{e}\033[0m")
        print(f"  {passed} queries OK | Fix broken queries before deploying!\n")
    elif passed:
        print(f"\033[32m✓ SQL validation: {passed}/{passed} queries OK\033[0m")

    server = ThreadedHTTPServer(("127.0.0.1", port), Handler)
    print(f"\033[1;36m◈ Convergio Control Room\033[0m → http://localhost:{port}")
    print(f"  DB: {DB_PATH}\n  Press Ctrl+C to stop\n")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nShutdown.")
        server.server_close()


if __name__ == "__main__":
    main()
