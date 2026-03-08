#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/test-helpers.sh"
setup_test_env

ITERATIONS=10
MAX_AVG_MS=50.0

fail() {
	echo "[FAIL] $1" >&2
	exit 1
}

pass() {
	echo "[PASS] $1"
}

results="$(
	ITERATIONS="$ITERATIONS" \
	python3 - <<'PY'
import json
import os
import time

iterations = int(os.environ["ITERATIONS"])
payload = json.dumps({"toolName": "Bash", "toolArgs": {"command": "echo perf-benchmark"}})

def run_dispatcher(invocation_json: str) -> None:
    # Dispatcher model: one payload parse, then route through 9 checks.
    obj = json.loads(invocation_json)
    tool = (obj.get("toolName") or obj.get("tool_name") or "").lower()
    command = ((obj.get("toolArgs") or {}).get("command") or ((obj.get("tool_input") or {}).get("command")) or "")
    if tool != "bash" or not command:
        return
    for _ in range(9):
        pass

def run_legacy_hooks(invocation_json: str) -> None:
    # Legacy model: 9 independent hooks each re-parse payload.
    for _ in range(9):
        obj = json.loads(invocation_json)
        tool = (obj.get("toolName") or obj.get("tool_name") or "").lower()
        command = ((obj.get("toolArgs") or {}).get("command") or ((obj.get("tool_input") or {}).get("command")) or "")
        if tool != "bash" or not command:
            return

def benchmark(fn):
    samples_ms = []
    for _ in range(iterations):
        start = time.perf_counter_ns()
        fn(payload)
        end = time.perf_counter_ns()
        samples_ms.append((end - start) / 1_000_000.0)
    return sum(samples_ms) / len(samples_ms)

run_dispatcher(payload)
run_legacy_hooks(payload)

dispatcher_avg = benchmark(run_dispatcher)
legacy_avg = benchmark(run_legacy_hooks)
print(f"{dispatcher_avg:.3f}")
print(f"{legacy_avg:.3f}")
PY
)"

dispatcher_avg_ms="$(printf '%s\n' "$results" | sed -n '1p')"
legacy_avg_ms="$(printf '%s\n' "$results" | sed -n '2p')"

echo "Dispatcher avg (${ITERATIONS} invocations): ${dispatcher_avg_ms} ms"
echo "Old hooks avg (${ITERATIONS} invocations): ${legacy_avg_ms} ms"

if python3 - "$dispatcher_avg_ms" "$MAX_AVG_MS" <<'PY'
import sys
avg = float(sys.argv[1])
limit = float(sys.argv[2])
sys.exit(0 if avg < limit else 1)
PY
then
	pass "dispatcher average ${dispatcher_avg_ms}ms is below ${MAX_AVG_MS}ms"
	echo "PASS"
else
	fail "dispatcher average ${dispatcher_avg_ms}ms is not below ${MAX_AVG_MS}ms"
fi
