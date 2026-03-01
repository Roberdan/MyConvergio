#!/usr/bin/env bash
# c-compact.sh — machine-only JSON output engine | Version: 1.1.0
# Strips null/0/false/[] from JSON objects and arrays. NO key abbreviation.
# Source this lib: source "$(dirname "${BASH_SOURCE[0]}")/c-compact.sh"

_PYTHON3=$(command -v python3 2>/dev/null || true)

# c_strip_defaults: strip null/0/false/[] from a single JSON object on stdin
c_strip_defaults() {
	if [[ -z "$_PYTHON3" ]]; then
		cat # passthrough if python3 unavailable
		return
	fi
	"$_PYTHON3" -c "
import json, sys
try:
    d = json.load(sys.stdin)
    if isinstance(d, dict):
        print(json.dumps({k: v for k, v in d.items()
                          if v not in (None, 0, False, [], {})}, separators=(',', ':')))
    else:
        print(json.dumps(d, separators=(',', ':')))
except Exception:
    pass
"
}

# c_compact_array: strip defaults from every element of a JSON array on stdin
c_compact_array() {
	if [[ -z "$_PYTHON3" ]]; then
		cat
		return
	fi
	"$_PYTHON3" -c "
import json, sys
try:
    arr = json.load(sys.stdin)
    if isinstance(arr, list):
        print(json.dumps(
            [{k: v for k, v in d.items() if v not in (None, 0, False, [], {})}
             if isinstance(d, dict) else d for d in arr],
            separators=(',', ':')))
    else:
        print(json.dumps(arr, separators=(',', ':')))
except Exception:
    pass
"
}

# c_out: pipe filter — strips defaults from single JSON object (use as final step)
c_out() {
	c_strip_defaults
}

# c_table: pipe-separated stdin → JSON array of objects
# First row = header field names; subsequent rows = data. Per ADR-0021: JSON only.
c_table() {
	if [[ -z "$_PYTHON3" ]]; then
		cat # passthrough if python3 unavailable
		return
	fi
	"$_PYTHON3" -c "
import json, sys
lines = [l.rstrip('\n') for l in sys.stdin if l.strip()]
if not lines:
    print('[]'); sys.exit(0)
headers = lines[0].split('|')
result = []
for row in lines[1:]:
    fields = row.split('|')
    result.append({headers[i]: fields[i] if i < len(fields) else '' for i in range(len(headers))})
print(json.dumps(result, separators=(',', ':')))
"
}
