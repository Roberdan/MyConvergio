#!/bin/bash
# Extract dashboard data as JSON for external renderers (terminui, etc.)
# Version: 1.0.0
# Usage: source from dashboard-mini.sh, call _extract_dashboard_json
set -uo pipefail

CLAUDE_HOME="${CLAUDE_HOME:-$HOME/.claude}"
DB="${DB:-$CLAUDE_HOME/data/dashboard.db}"

_extract_dashboard_json() {
	local db="$DB"
	[[ ! -f "$db" ]] && echo '{"error":"no db"}' && return 1

	# Overview stats (single query)
	local ov
	ov=$(sqlite3 -separator '|' "$db" "
		SELECT
			(SELECT COUNT(*) FROM plans),
			(SELECT COUNT(*) FROM plans WHERE status='done'),
			(SELECT COUNT(*) FROM plans WHERE status='doing'),
			(SELECT COUNT(*) FROM plans WHERE status='todo'),
			(SELECT COUNT(*) FROM tasks WHERE plan_id IN (SELECT id FROM plans WHERE status='doing')),
			(SELECT COUNT(*) FROM tasks WHERE status='done' AND plan_id IN (SELECT id FROM plans WHERE status='doing')),
			(SELECT COUNT(*) FROM tasks WHERE status='in_progress' AND plan_id IN (SELECT id FROM plans WHERE status='doing')),
			(SELECT COUNT(*) FROM plans WHERE status='cancelled');
	" 2>/dev/null)

	local total plan_done doing todo total_tasks done_tasks in_progress cancelled
	IFS='|' read -r total plan_done doing todo total_tasks done_tasks in_progress cancelled <<<"$ov"

	# Active plans
	local plans_json="[]"
	plans_json=$(sqlite3 -json "$db" "
		SELECT p.id, p.name, p.project_id as project, p.status,
			COALESCE(p.execution_host,'') as host,
			COALESCE(p.human_summary, REPLACE(REPLACE(COALESCE(p.description,''),char(10),' '),char(13),'')) as description,
			(SELECT COUNT(*) FROM waves WHERE plan_id=p.id AND status NOT IN ('cancelled')) as wave_total,
			(SELECT COUNT(*) FROM waves WHERE plan_id=p.id AND tasks_done=tasks_total AND tasks_total>0) as wave_done,
			(SELECT COUNT(*) FROM tasks WHERE plan_id=p.id AND status NOT IN ('cancelled','skipped')) as task_total,
			(SELECT COUNT(*) FROM tasks WHERE plan_id=p.id AND status='done') as task_done,
			COALESCE((SELECT SUM(input_tokens+output_tokens) FROM token_usage WHERE project_id=p.project_id),0) as tokens,
			COALESCE(p.started_at, p.created_at) as started_at
		FROM plans p WHERE p.status IN ('doing','in_progress') ORDER BY p.id
	" 2>/dev/null || echo "[]")

	# Mesh peers
	local peers_json
	peers_json=$(/usr/bin/python3 -c "
import json, configparser, time, sqlite3, os

conf_path = os.path.expanduser('~/.claude/config/peers.conf')
db_path = os.path.expanduser('~/.claude/data/dashboard.db')
stale = 300
now = int(time.time())

peers = []
if os.path.exists(conf_path):
    cp = configparser.ConfigParser()
    cp.read(conf_path)
    hb = {}
    if os.path.exists(db_path):
        try:
            conn = sqlite3.connect(db_path)
            for row in conn.execute('SELECT peer_name, last_seen, load_json FROM peer_heartbeats'):
                name, seen, lj = row
                load = {}
                try: load = json.loads(lj) if lj else {}
                except: pass
                hb[name] = {'seen': seen, 'load': load}
            conn.close()
        except: pass
    for sec in cp.sections():
        p = dict(cp[sec])
        h = hb.get(sec, {})
        online = (now - h.get('seen', 0)) <= stale if h.get('seen') else False
        cpu = h.get('load', {}).get('cpu_load', 0)
        tasks = h.get('load', {}).get('tasks_in_progress', 0)
        peers.append({
            'name': sec,
            'os': p.get('os', 'linux'),
            'role': p.get('role', 'worker'),
            'status': p.get('status', 'active'),
            'capabilities': p.get('capabilities', '').split(','),
            'online': online,
            'cpu': round(float(cpu)) if cpu else 0,
            'tasks': int(tasks) if tasks else 0,
        })

print(json.dumps(peers))
" 2>/dev/null || echo "[]")

	# Build final JSON
	/usr/bin/python3 -c "
import json, sys
data = {
    'overview': {
        'total': ${total:-0}, 'done': ${plan_done:-0}, 'doing': ${doing:-0},
        'todo': ${todo:-0}, 'cancelled': ${cancelled:-0},
        'tasks_total': ${total_tasks:-0}, 'tasks_done': ${done_tasks:-0},
        'tasks_running': ${in_progress:-0}
    },
    'plans': json.loads('''${plans_json}'''),
    'mesh': json.loads('''${peers_json}'''),
}
print(json.dumps(data, indent=2))
"
}
