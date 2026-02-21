#!/bin/bash
# RED test: settings.json must reference model-registry-refresh.sh and env-vault-guard.sh
set -euo pipefail

fail=0
if ! grep -q 'model-registry-refresh' ./settings.json; then
  echo 'FAIL: model-registry-refresh.sh not registered in settings.json'
  fail=1
fi
if ! grep -q 'env-vault-guard' ./settings.json; then
  echo 'FAIL: env-vault-guard.sh not registered in settings.json'
  fail=1
fi
exit $fail
