#!/bin/bash
# RED test: hooks/model-registry-refresh.sh must exist, be valid bash, contain '14', and be <80 lines
set -euo pipefail
fail=0

# 1. File must exist
TARGET="hooks/model-registry-refresh.sh"
if [ ! -f "$TARGET" ]; then
  echo "FAIL: $TARGET does not exist"
  fail=1
fi

# 2. Bash syntax check
if [ -f "$TARGET" ]; then
  if ! bash -n "$TARGET"; then
    echo "FAIL: $TARGET is not valid bash"
    fail=1
  fi
fi

# 3. Must contain '14' (for 14-day check)
if [ -f "$TARGET" ]; then
  if ! grep -q '14' "$TARGET"; then
    echo "FAIL: $TARGET missing '14'"
    fail=1
  fi
fi

# 4. Must be <80 lines
if [ -f "$TARGET" ]; then
  lines=$(wc -l < "$TARGET")
  if [ "$lines" -ge 80 ]; then
    echo "FAIL: $TARGET has $lines lines (>=80)"
    fail=1
  fi
fi

if [ $fail -eq 0 ]; then
  echo 'PASS: All checks passed'
  exit 0
else
  exit 1
fi
