#!/usr/bin/env bash
set -euo pipefail

ROLE="${1:-}"
if [[ -z "$ROLE" ]]; then
  echo "Usage: $0 <agent-role>" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

resolve_profiles_file() {
  if [[ -n "${AGENT_PROFILES_FILE:-}" ]]; then
    echo "$AGENT_PROFILES_FILE"
    return 0
  fi

  local candidates=(
    "$REPO_ROOT/config/agent-profiles.yaml"
    "$REPO_ROOT/config/agent-profiles.yml"
    "$REPO_ROOT/agent-profiles.yaml"
    "$REPO_ROOT/agent-profiles.yml"
  )
  local candidate
  for candidate in "${candidates[@]}"; do
    if [[ -f "$candidate" ]]; then
      echo "$candidate"
      return 0
    fi
  done
  echo ""
}

PROFILE_FILE="$(resolve_profiles_file)"

PROFILE_JSON="$(
ROLE="$ROLE" PROFILE_FILE="$PROFILE_FILE" ruby <<'RUBY'
require "json"
require "yaml"

role = ENV.fetch("ROLE")
profile_file = ENV["PROFILE_FILE"]

fallback = {
  "common" => {
    "files" => [
      "CLAUDE.md",
      "rules/guardian.md",
      "rules/compaction-preservation.md"
    ]
  },
  "roles" => {
    "executor" => {
      "files" => [
        "AGENTS.md",
        "reference/operational/tool-preferences.md",
        "reference/operational/execution-optimization.md",
        "reference/operational/universal-orchestration.md",
        "reference/operational/enforcement-hooks.md"
      ],
      "target_tokens" => { "min" => 5000, "max" => 12000 }
    },
    "planner" => {
      "files" => [
        "AGENTS.md",
        "commands/planner.md",
        "reference/operational/agent-routing.md",
        "reference/operational/plan-scripts.md",
        "reference/operational/universal-orchestration.md"
      ],
      "target_tokens" => { "min" => 5000, "max" => 12000 }
    },
    "validator" => {
      "files" => [
        "AGENTS.md",
        "reference/operational/enforcement-hooks.md",
        "reference/operational/worktree-discipline.md",
        "reference/operational/copilot-alignment.md"
      ],
      "target_tokens" => { "min" => 5000, "max" => 12000 }
    },
    "reviewer" => {
      "files" => [
        "AGENTS.md",
        "reference/operational/copilot-alignment.md",
        "reference/operational/tool-preferences.md",
        "reference/operational/universal-orchestration.md"
      ],
      "target_tokens" => { "min" => 5000, "max" => 12000 }
    },
    "researcher" => {
      "files" => [
        "AGENTS.md",
        "commands/research.md",
        "reference/operational/universal-orchestration.md",
        "reference/operational/memory-protocol.md",
        "reference/operational/prompt-caching-guide.md"
      ],
      "target_tokens" => { "min" => 5000, "max" => 12000 }
    },
    "deployer" => {
      "files" => [
        "AGENTS.md",
        "commands/release.md",
        "reference/operational/external-services.md",
        "reference/operational/worktree-discipline.md"
      ],
      "target_tokens" => { "min" => 5000, "max" => 12000 }
    },
    "operator" => {
      "files" => [
        "AGENTS.md",
        "reference/operational/mesh-networking.md",
        "reference/operational/concurrency-control.md",
        "reference/operational/tool-preferences.md"
      ],
      "target_tokens" => { "min" => 5000, "max" => 12000 }
    }
  }
}

def array_value(value)
  return [] if value.nil?
  return value if value.is_a?(Array)
  return [value] if value.is_a?(String)
  []
end

data =
  if profile_file && !profile_file.empty? && File.file?(profile_file)
    raw = YAML.safe_load(File.read(profile_file), aliases: true)
    raw.is_a?(Hash) ? raw : {}
  else
    fallback
  end

profiles = data["roles"] || data["profiles"] || data["agent_profiles"]
if !profiles.is_a?(Hash)
  metadata_keys = %w[common defaults version schema]
  profiles = data.reject { |k, _| metadata_keys.include?(k.to_s) }
end
common_section = data["common"] || {}
common_files = array_value(common_section["files"]) + array_value(common_section["includes"])

role_config = profiles[role] || {}
role_files = []
if role_config.is_a?(Hash)
  role_files += array_value(role_config["files"])
  role_files += array_value(role_config["includes"])
  role_files += array_value(role_config["instructions"])
  %w[rules references commands].each do |section|
    role_files += array_value(role_config[section])
  end
  role_config.each_value do |value|
    role_files += value if value.is_a?(Array)
  end
end
files = (common_files + role_files).map { |x| x.to_s.strip }.reject(&:empty?).uniq

target = role_config["target_tokens"] || {}
min_tokens = target["min"] || target["min_tokens"] || 5000
max_tokens = target["max"] || target["max_tokens"] || 12000

result = {
  "files" => files,
  "min_tokens" => min_tokens.to_i,
  "max_tokens" => max_tokens.to_i,
  "known_roles" => profiles.keys.sort,
  "profile_source" => if profile_file && !profile_file.empty? && File.file?(profile_file)
    profile_file
  else
    "embedded-default"
  end
}

puts JSON.generate(result)
RUBY
)"

FILES_LEN="$(echo "$PROFILE_JSON" | jq '.files | length')"
if [[ "$FILES_LEN" -eq 0 ]]; then
  echo "No profile found for role '$ROLE' in agent-profiles configuration." >&2
  echo "Known roles: $(echo "$PROFILE_JSON" | jq -r '.known_roles | join(", ")')" >&2
  exit 1
fi

MIN_TOKENS="$(echo "$PROFILE_JSON" | jq -r '.min_tokens')"
MAX_TOKENS="$(echo "$PROFILE_JSON" | jq -r '.max_tokens')"
PROFILE_SOURCE="$(echo "$PROFILE_JSON" | jq -r '.profile_source')"

echo "### Agent Role: $ROLE"
echo "### Profile Source: $PROFILE_SOURCE"
echo "### Target Tokens: ${MIN_TOKENS}-${MAX_TOKENS}"
echo

MAX_CHARS=$((MAX_TOKENS * 4))
MIN_CHARS=$((MIN_TOKENS * 4))
CURRENT_BYTES=0
EMITTED_COUNT=0

emit_file() {
  local rel_path="$1"
  local abs_path
  abs_path="$(python3 - "$REPO_ROOT" "$rel_path" <<'PY'
import os
import sys
repo_root, rel = sys.argv[1], sys.argv[2]
print(os.path.realpath(os.path.join(repo_root, rel)))
PY
)"
  if [[ "$abs_path" != "$REPO_ROOT" && "$abs_path" != "$REPO_ROOT/"* ]]; then
    echo "Skipping path outside repository: $rel_path" >&2
    return 0
  fi
  if [[ ! -f "$abs_path" ]]; then
    echo "Skipping missing instruction file: $rel_path" >&2
    return 0
  fi

  local content
  content="$(cat "$abs_path")"
  local block
  block=$(printf '### Source: %s\n%s\n\n' "$rel_path" "$content")
  local block_bytes
  block_bytes="$(printf '%s' "$block" | wc -c | tr -d '[:space:]')"

  if (( CURRENT_BYTES + block_bytes > MAX_CHARS )) && (( EMITTED_COUNT > 0 )); then
    echo "Skipping file to stay within max token target: $rel_path" >&2
    return 0
  fi

  printf '%s' "$block"
  CURRENT_BYTES=$((CURRENT_BYTES + block_bytes))
  EMITTED_COUNT=$((EMITTED_COUNT + 1))
}

while IFS= read -r rel_path; do
  emit_file "$rel_path"
done < <(echo "$PROFILE_JSON" | jq -r '.files[]')

if (( CURRENT_BYTES < MIN_CHARS )); then
  echo "Warning: output is below target token range for role '$ROLE' (${CURRENT_BYTES} chars)." >&2
fi
