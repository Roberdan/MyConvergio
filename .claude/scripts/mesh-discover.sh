#!/usr/bin/env bash
# mesh-discover.sh v1.1.0
# Discover Tailscale peers, show tool versions and repo status.
# Usage: mesh-discover.sh [--deep]
#   --deep: SSH into online peers to check tool versions and repo status
set -euo pipefail

CLAUDE_HOME="${CLAUDE_HOME:-$HOME/.claude}"
PEERS_CONF="$CLAUDE_HOME/config/peers.conf"
DEEP=false
[[ "${1:-}" == "--deep" ]] && DEEP=true

if ! command -v tailscale &>/dev/null; then
	echo "ERROR: tailscale CLI not found" >&2
	exit 1
fi

TS_JSON=$(tailscale status --json 2>/dev/null)

/usr/bin/python3 -c "
import json, sys, re

ts = json.loads('''$TS_JSON''')
self_node = ts.get('Self', {})
peers = ts.get('Peer', {})

conf_peers = set()
try:
    with open('$PEERS_CONF') as f:
        for line in f:
            m = re.match(r'^\[(.+)\]', line.strip())
            if m:
                conf_peers.add(m.group(1))
except FileNotFoundError:
    pass

print('=== TAILSCALE NETWORK ===')
print(f'This machine: {self_node.get(\"HostName\", \"?\")} ({self_node.get(\"OS\", \"?\")})')
print(f'  IP: {\", \".join(self_node.get(\"TailscaleIPs\", [])[:1])}')
print()

for k, p in peers.items():
    hostname = p.get('HostName', '?')
    os_name = p.get('OS', '?')
    online = 'ONLINE' if p.get('Online') else 'offline'
    ips = p.get('TailscaleIPs', [])
    ip = ips[0] if ips else '?'
    dns = p.get('DNSName', '').rstrip('.')
    in_conf = 'IN peers.conf' if any(hostname.lower().replace(' ', '').replace(\"'\", '') in c.lower() for c in conf_peers) else 'NOT in peers.conf'
    print(f'  {hostname} | {os_name} | {ip} | {online} | {in_conf}')
    if online == 'ONLINE' and dns:
        print(f'    DNS: {dns}')

print()
joined = ', '.join(sorted(conf_peers))
print(f'peers.conf: {len(conf_peers)} entries ({joined})')
print(f'Tailscale: {len(peers)} peers')
"

if ! $DEEP; then
	echo ""
	echo "Tip: use --deep to SSH into online peers and check tool versions + repo status"
	exit 0
fi

echo ""
echo "=== DEEP PROBE (online peers) ==="

# Parse peers.conf for SSH details
while IFS= read -r line; do
	line="${line%%#*}"
	[[ -z "${line// /}" ]] && continue

	if [[ "$line" =~ ^\[(.+)\]$ ]]; then
		[[ -n "${PEER_NAME:-}" && -n "${PEER_SSH:-}" && "${PEER_STATUS:-active}" == "active" && "$PEER_NAME" != "m3max" ]] && {
			echo ""
			echo "--- $PEER_NAME ($PEER_SSH) ---"
			if ssh -o ConnectTimeout=5 -o BatchMode=yes "$PEER_SSH" true 2>/dev/null; then
				ssh -o ConnectTimeout=10 "$PEER_SSH" "
					printf 'claude: '; claude --version 2>/dev/null || printf 'NOT INSTALLED\n'
					printf 'gh: '; gh --version 2>/dev/null | head -1 || printf 'NOT INSTALLED\n'
					printf 'ollama: '; ollama --version 2>/dev/null || printf 'NOT INSTALLED\n'
					printf 'tailscale: '; tailscale version 2>/dev/null | head -1 || printf 'NOT INSTALLED\n'
					printf '\nRepos:\n'
					for d in ~/GitHub/VirtualBPM ~/GitHub/MyConvergio ~/.claude; do
						if [ -d \"\$d/.git\" ]; then
							sha=\$(git -C \$d log --oneline -1 2>/dev/null)
							branch=\$(git -C \$d branch --show-current 2>/dev/null)
							printf '  %s: %s [%s]\n' \"\$d\" \"\$sha\" \"\$branch\"
						fi
					done
					printf '\nmodels.yaml: '
					if [ -f ~/.claude/config/models.yaml ]; then printf 'PRESENT\n'; else printf 'MISSING\n'; fi
				" 2>/dev/null
			else
				echo "  OFFLINE — cannot probe"
			fi
		} || true
		PEER_NAME="${BASH_REMATCH[1]}"
		PEER_SSH="" PEER_STATUS="active"
	fi
	[[ "$line" =~ ssh_alias=(.+) ]] && PEER_SSH="${BASH_REMATCH[1]// /}"
	[[ "$line" =~ status=(.+) ]] && PEER_STATUS="${BASH_REMATCH[1]// /}"
done <"$PEERS_CONF"

# Emit last peer
[[ -n "${PEER_NAME:-}" && -n "${PEER_SSH:-}" && "${PEER_STATUS:-active}" == "active" && "$PEER_NAME" != "m3max" ]] && {
	echo ""
	echo "--- $PEER_NAME ($PEER_SSH) ---"
	if ssh -o ConnectTimeout=5 -o BatchMode=yes "$PEER_SSH" true 2>/dev/null; then
		ssh -o ConnectTimeout=10 "$PEER_SSH" "
			printf 'claude: '; claude --version 2>/dev/null || printf 'NOT INSTALLED\n'
			printf 'gh: '; gh --version 2>/dev/null | head -1 || printf 'NOT INSTALLED\n'
			printf 'ollama: '; ollama --version 2>/dev/null || printf 'NOT INSTALLED\n'
			printf 'tailscale: '; tailscale version 2>/dev/null | head -1 || printf 'NOT INSTALLED\n'
			printf '\nRepos:\n'
			for d in ~/GitHub/VirtualBPM ~/GitHub/MyConvergio ~/.claude; do
				if [ -d \"\$d/.git\" ]; then
					sha=\$(git -C \$d log --oneline -1 2>/dev/null)
					branch=\$(git -C \$d branch --show-current 2>/dev/null)
					printf '  %s: %s [%s]\n' \"\$d\" \"\$sha\" \"\$branch\"
				fi
			done
			printf '\nmodels.yaml: '
			if [ -f ~/.claude/config/models.yaml ]; then printf 'PRESENT\n'; else printf 'MISSING\n'; fi
		" 2>/dev/null
	else
		echo "  OFFLINE — cannot probe"
	fi
} || true
