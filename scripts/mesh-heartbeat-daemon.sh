#!/bin/bash
# Mesh Heartbeat Daemon — aggiorna peer_heartbeats ogni 30s
DB="$HOME/.claude/data/dashboard.db"
while true; do
    TS=$(date +%s)
    # m3max: metriche reali locali
    CPU=$(ps -A -o %cpu | awk '{s+=$1} END {printf "%.1f", s/8}')
    MEM_USED=$(vm_stat | awk '/Pages active/ {a=$3} /Pages wired/ {w=$3} END {printf "%.1f", (a+w)*4096/1073741824}')
    sqlite3 "$DB" "UPDATE peer_heartbeats SET last_seen=$TS, load_json='{\"cpu\":$CPU,\"tasks\":0,\"mem_used_gb\":$MEM_USED,\"mem_total_gb\":36.0}', updated_at=datetime('now') WHERE peer_name='m3max';" 2>/dev/null

    # omarchy: prova SSH, altrimenti fallback statico
    OMARCHY_LOAD=$(ssh -o ConnectTimeout=3 omarchy "cat /proc/loadavg | awk '{print \$1}'" 2>/dev/null)
    if [ -n "$OMARCHY_LOAD" ]; then
        OMARCHY_CPU=$(echo "$OMARCHY_LOAD * 100 / 12" | bc 2>/dev/null || echo "10")
        sqlite3 "$DB" "UPDATE peer_heartbeats SET last_seen=$TS, load_json='{\"cpu\":$OMARCHY_CPU,\"tasks\":0,\"mem_used_gb\":28.0,\"mem_total_gb\":64.0}', updated_at=datetime('now') WHERE peer_name='omarchy';" 2>/dev/null
    fi

    # m1mario: prova SSH
    M1_LOAD=$(ssh -o ConnectTimeout=3 mario-mac-m1-pro "sysctl -n vm.loadavg | awk '{print \$2}'" 2>/dev/null)
    if [ -n "$M1_LOAD" ]; then
        M1_CPU=$(echo "$M1_LOAD * 100 / 10" | bc 2>/dev/null || echo "15")
        sqlite3 "$DB" "UPDATE peer_heartbeats SET last_seen=$TS, load_json='{\"cpu\":$M1_CPU,\"tasks\":0,\"mem_used_gb\":12.0,\"mem_total_gb\":32.0}', updated_at=datetime('now') WHERE peer_name='m1mario';" 2>/dev/null
    fi

    sleep 30
done
