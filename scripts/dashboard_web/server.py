"""Convergio Control Room — Web Dashboard Server.

Usage: python3 server.py [--port 8420]
"""

import re
import sys
from http.server import HTTPServer, SimpleHTTPRequestHandler
from pathlib import Path
from socketserver import ThreadingMixIn
from urllib.parse import parse_qs, urlparse

import api_mesh as api_mesh_mod
from api_dashboard import (
    api_assignable_plans,
    api_coordinator_status,
    api_coordinator_toggle,
    api_events,
    api_history,
    api_mission as _api_mission,
    api_notifications,
    api_overview,
    api_plan_detail,
    api_task_status_dist,
    api_tasks_blocked,
    api_tokens_by_model,
    api_tokens_daily,
)
from api_mesh import api_mesh_sync_status, handle_mesh_action, resolve_host_to_peer
from api_mesh_actions import handle_fullsync_sse, handle_mesh_action_sse
from api_peers import (
    api_peer_create,
    api_peer_delete,
    api_peer_discover,
    api_peer_list,
    api_peer_ssh_check,
    api_peer_update,
)
from api_plans import (
    handle_plan_cancel,
    handle_plan_move,
    handle_plan_reset,
    handle_plan_validate,
    handle_pull_remote_db,
)
from api_plans_sse import (
    api_preflight_sse,
    handle_plan_delegate,
    handle_plan_start_sse,
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


def api_mission():
    return _api_mission(resolve_host_to_peer)


def api_mesh():
    return api_mesh_mod.api_mesh()


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
        m = re.match(r"^/api/plans/(\d+)/validate$", path)
        if m:
            self._json_response(handle_plan_validate(int(m.group(1))))
            return
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
