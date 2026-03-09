#!/usr/bin/env bash
# session-learnings.sh — Session learning signal analyzer
# Reads collected signals, summarizes, optionally clears processed entries.
# Version: 1.0.0
set -euo pipefail

LEARNINGS_FILE="$HOME/.claude/data/session-learnings.jsonl"

usage() {
  cat <<EOF
Usage: session-learnings.sh <command>
  summary    Show unprocessed signal summary (JSON)
  count      Count unprocessed signals
  clear      Mark all signals as processed
  tail [N]   Show last N entries (default 5)
EOF
  exit 1
}

[[ $# -lt 1 ]] && usage

case "$1" in
  summary)
    [[ ! -f "$LEARNINGS_FILE" ]] && echo '{"signals":[],"count":0}' && exit 0
    jq -s '{
      count: length,
      by_type: (map(.signals[]) | group_by(.type) | map({
        type: .[0].type,
        count: length,
        samples: [.[0:3][] | .data]
      })),
      projects: [map(.project) | unique[] | select(. != null)],
      time_range: {
        first: (sort_by(.timestamp) | first.timestamp),
        last: (sort_by(.timestamp) | last.timestamp)
      }
    }' "$LEARNINGS_FILE" 2>/dev/null || echo '{"signals":[],"count":0}'
    ;;
  count)
    [[ ! -f "$LEARNINGS_FILE" ]] && echo "0" && exit 0
    wc -l < "$LEARNINGS_FILE" | tr -d ' '
    ;;
  clear)
    ARCHIVE="$HOME/.claude/data/session-learnings-archive.jsonl"
    if [[ -f "$LEARNINGS_FILE" ]]; then
      cat "$LEARNINGS_FILE" >> "$ARCHIVE" 2>/dev/null
      : > "$LEARNINGS_FILE"
      echo "Signals archived and cleared."
    else
      echo "No signals to clear."
    fi
    ;;
  tail)
    N="${2:-5}"
    [[ ! -f "$LEARNINGS_FILE" ]] && echo "No signals." && exit 0
    tail -n "$N" "$LEARNINGS_FILE" | jq '.'
    ;;
  *)
    usage
    ;;
esac
