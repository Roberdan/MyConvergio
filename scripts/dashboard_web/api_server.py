#!/usr/bin/env python3
import http.server
import socketserver
import json
import sqlite3
import urllib.parse
import os

class DashboardHandler(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        if self.path.startswith('/api/'):
            self.handle_api()
        else:
            super().do_GET()
    
    def handle_api(self):
        path = self.path[5:]  # Remove '/api/'
        
        try:
            if path == 'plans':
                data = self.get_plans()
            elif path == 'peers':
                data = self.get_peers()
            elif path == 'tasks':
                data = self.get_tasks()
            else:
                data = {"error": "Unknown endpoint"}
            
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps(data).encode())
        except Exception as e:
            self.send_response(500)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps({"error": str(e)}).encode())
    
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
