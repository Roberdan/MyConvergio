#!/bin/bash
# tests/test-model-registry.sh
# RED phase: All tests expected to fail (TDD)
set -euo pipefail

@test "refresh-creates-file" {
  rm -f data/models-registry.json
  scripts/model-registry.sh refresh
  [ -f data/models-registry.json ] || exit 1
}

@test "refresh-parses-opencode" {
  scripts/model-registry.sh refresh
  grep 'opencode' data/models-registry.json || exit 1
}

@test "refresh-includes-multipliers" {
  scripts/model-registry.sh refresh
  grep 'multiplier' data/models-registry.json || exit 1
}

@test "diff-new-model" {
  cp data/models-registry.json data/models-registry.json.bak
  echo '{"models": [{"name": "new-model", "multiplier": 2}]}' > data/models-registry.json
  scripts/model-registry.sh diff | grep 'new-model' || exit 1
  mv data/models-registry.json.bak data/models-registry.json
}

@test "diff-removed" {
  cp data/models-registry.json data/models-registry.json.bak
  jq 'del(.models[0])' data/models-registry.json > data/models-registry.json.tmp && mv data/models-registry.json.tmp data/models-registry.json
  scripts/model-registry.sh diff | grep 'removed' || exit 1
  mv data/models-registry.json.bak data/models-registry.json
}

@test "diff-version-change" {
  cp data/models-registry.json data/models-registry.json.bak
  jq '.models[0].version = "2.0.0"' data/models-registry.json > data/models-registry.json.tmp && mv data/models-registry.json.tmp data/models-registry.json
  scripts/model-registry.sh diff | grep 'version' || exit 1
  mv data/models-registry.json.bak data/models-registry.json
}

@test "check-fresh" {
  scripts/model-registry.sh check | grep 'fresh' || exit 1
}

@test "check-stale" {
  touch -d '2 days ago' data/models-registry.json
  scripts/model-registry.sh check | grep 'stale' || exit 1
}

@test "list-valid-json" {
  scripts/model-registry.sh list | jq .models || exit 1
}

@test "cli-version-detection" {
  scripts/model-registry.sh refresh
  scripts/model-registry.sh list | grep 'cli_version' || exit 1
}
