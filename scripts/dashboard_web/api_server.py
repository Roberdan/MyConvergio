#!/usr/bin/env python3
import http.server
import socketserver
import json
import sqlite3
import urllib.parse
import urllib.request
import urllib.error
import os

class DashboardHandler(http.server.SimpleHTTPRequestHandler):
    daemon_base_url = None

    def do_GET(self):
        if self.path.startswith('/api/'):
            self.handle_api()
        else:
            super().do_GET()

    def do_POST(self):
        if self.path.startswith('/api/'):
            self.handle_api()
        else:
            self.send_response(405)
            self.end_headers()
    
    def handle_api(self):
        parsed = urllib.parse.urlparse(self.path)
        path = parsed.path[5:]  # Remove '/api/'
        
        try:
            if path == 'plans':
                data = self.get_plans()
            elif path == 'peers':
                data = self.get_peers()
            elif path == 'tasks':
                data = self.get_tasks()
            elif path == 'mesh/health':
                ok, source, payload = self.check_daemon_health()
                data = {"ok": ok, "daemon": source, "health": payload}
                self.send_response(200 if ok else 503)
                self.send_header('Content-Type', 'application/json')
                self.end_headers()
                self.wfile.write(json.dumps(data).encode())
                return
            elif path == 'mesh/init' and self.command == 'POST':
                data = {"ok": True, "daemons_restarted": [], "hosts_needing_normalization": 0}
            elif path == 'mesh/pull-db':
                data = {"ok": True, "count": 0, "synced": []}
            elif path.startswith('mesh'):
                data, status = self.proxy_mesh_request(path, parsed.query)
                self.send_response(status)
                self.send_header('Content-Type', 'application/json')
                self.end_headers()
                self.wfile.write(json.dumps(data).encode())
                return
            else:
                data = {"error": "Unknown endpoint"}
                self.send_response(404)
                self.send_header('Content-Type', 'application/json')
                self.end_headers()
                self.wfile.write(json.dumps(data).encode())
                return
            
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps(data).encode())
        except Exception as e:
            self.send_response(500)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps({"error": str(e)}).encode())

    def daemon_candidates(self):
        if DashboardHandler.daemon_base_url:
            return [DashboardHandler.daemon_base_url]

        candidates = []
        if os.getenv('MESH_DAEMON_URL'):
            candidates.append(os.getenv('MESH_DAEMON_URL').rstrip('/'))

        host_list = []
        env_hosts = os.getenv('MESH_DAEMON_HOSTS', '')
        if env_hosts.strip():
            host_list.extend([h.strip() for h in env_hosts.split(',') if h.strip()])
        if os.getenv('MESH_DAEMON_HOST'):
            host_list.append(os.getenv('MESH_DAEMON_HOST').strip())
        if os.getenv('TAILSCALE_IP'):
            host_list.append(os.getenv('TAILSCALE_IP').strip())
        host_list.extend(['127.0.0.1', 'localhost'])

        dedup = []
        for host in host_list:
            if host and host not in dedup:
                dedup.append(host)
        for host in dedup:
            candidates.append(f'http://{host}:9421')

        return candidates

    def daemon_request(self, daemon_path, query='', timeout=3, method='GET'):
        query_suffix = f'?{query}' if query else ''
        last_error = None
        for base in self.daemon_candidates():
            url = f'{base}{daemon_path}{query_suffix}'
            req = urllib.request.Request(url, method=method)
            try:
                with urllib.request.urlopen(req, timeout=timeout) as response:
                    DashboardHandler.daemon_base_url = base
                    body = response.read().decode('utf-8') or '{}'
                    try:
                        return json.loads(body), response.status, base
                    except json.JSONDecodeError:
                        return {"raw": body}, response.status, base
            except urllib.error.HTTPError as http_err:
                last_error = {"error": str(http_err), "status": http_err.code}
            except Exception as exc:
                last_error = {"error": str(exc)}
        return last_error or {"error": "Daemon unavailable"}, 503, None

    def check_daemon_health(self):
        data, status, base = self.daemon_request('/health', timeout=2)
        return status < 400, base, data

    def proxy_mesh_request(self, mesh_path, query=''):
        subpath = mesh_path[len('mesh'):].lstrip('/')
        route_map = {
            '': '/api/peers',
            'status': '/api/status',
            'peers': '/api/peers',
            'metrics': '/api/metrics',
            'sync-stats': '/api/sync-stats',
            'logs': '/api/logs',
            'health': '/health',
            'sync-status': '/api/sync-stats',
        }
        daemon_path = route_map.get(subpath)
        if not daemon_path:
            return {"error": f"Unsupported mesh endpoint: {subpath}"}, 404

        data, status, _ = self.daemon_request(daemon_path, query=query)
        if subpath == '' and isinstance(data, dict) and 'peers' in data and isinstance(data['peers'], list):
            return data['peers'], status
        if subpath == 'sync-status':
            if isinstance(data, dict) and isinstance(data.get('peers'), list):
                return data['peers'], status
            if isinstance(data, list):
                return data, status
            return [], status
        return data, status
    
    def get_plans(self):
        conn = sqlite3.connect(os.path.expanduser('~/.claude/data/dashboard.db'))
        cursor = conn.execute('SELECT id, name, status, execution_host, progress_percentage FROM plans LIMIT 20')
        plans = [{"id": row[0], "name": row[1], "status": row[2], "execution_host": row[3], "progress": row[4]} for row in cursor]
        conn.close()
        return {"plans": plans}
    
    def get_peers(self):
        return {"peers": [
            {"peer_name": "m3max", "is_online": True, "load_json": '{"cpu": 45.2, "tasks": 2}'},
            {"peer_name": "omarchy", "is_online": True, "load_json": '{"cpu": 67.8, "tasks": 2}'},
            {"peer_name": "m1mario", "is_online": True, "load_json": '{"cpu": 23.1, "tasks": 1}'}
        ]}
    
    def get_tasks(self):
        conn = sqlite3.connect(os.path.expanduser('~/.claude/data/dashboard.db'))
        cursor = conn.execute('SELECT id, plan_id, title, status, progress_percentage FROM tasks LIMIT 20')
        tasks = [{"id": row[0], "plan_id": row[1], "title": row[2], "status": row[3], "progress": row[4]} for row in cursor]
        conn.close()
        return {"tasks": tasks}

os.chdir(os.path.expanduser('~/.claude/scripts/dashboard_web'))
PORT = 8420
with socketserver.TCPServer(("", PORT), DashboardHandler) as httpd:
    print(f"✅ Dashboard server running on http://localhost:{PORT}")
    httpd.serve_forever()
