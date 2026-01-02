#!/bin/bash

# Hardware-Aware Settings Generator for Claude Code
# Detects system resources and generates optimal settings.json

set -e

CLAUDE_HOME="${HOME}/.claude"
SETTINGS_FILE="${CLAUDE_HOME}/settings.json"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
  echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
  echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warn() {
  echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
  echo -e "${RED}[ERROR]${NC} $1"
}

# Detect OS
detect_os() {
  case "$(uname -s)" in
    Darwin*)  echo "macos" ;;
    Linux*)   echo "linux" ;;
    CYGWIN*|MINGW*|MSYS*) echo "windows" ;;
    *)        echo "unknown" ;;
  esac
}

# Get CPU cores
get_cpu_cores() {
  local os=$(detect_os)
  case "$os" in
    macos)
      sysctl -n hw.ncpu
      ;;
    linux)
      nproc
      ;;
    windows)
      echo "$NUMBER_OF_PROCESSORS"
      ;;
    *)
      echo "4"  # Default fallback
      ;;
  esac
}

# Get total RAM in GB
get_total_ram_gb() {
  local os=$(detect_os)
  case "$os" in
    macos)
      echo $(($(sysctl -n hw.memsize) / 1024 / 1024 / 1024))
      ;;
    linux)
      echo $(($(grep MemTotal /proc/meminfo | awk '{print $2}') / 1024 / 1024))
      ;;
    windows)
      # Fallback
      echo "16"
      ;;
    *)
      echo "8"  # Default fallback
      ;;
  esac
}

# Detect if Apple Silicon
is_apple_silicon() {
  if [[ "$(uname -s)" == "Darwin" ]]; then
    if [[ "$(uname -m)" == "arm64" ]]; then
      return 0
    fi
  fi
  return 1
}

# Generate settings based on profile
generate_settings() {
  local profile=$1
  local cpu_cores=$(get_cpu_cores)
  local ram_gb=$(get_total_ram_gb)
  local os=$(detect_os)

  log_info "Detected: ${cpu_cores} CPU cores, ${ram_gb}GB RAM, OS: ${os}"

  # Determine profile based on RAM if not specified
  if [[ -z "$profile" ]]; then
    if [[ $ram_gb -ge 32 ]]; then
      profile="high"
    elif [[ $ram_gb -ge 16 ]]; then
      profile="medium"
    else
      profile="low"
    fi
    log_info "Auto-selected profile: $profile (based on ${ram_gb}GB RAM)"
  fi

  # Calculate optimal settings
  local max_parallel=4
  local node_memory=4096
  local shell_concurrency=2

  case "$profile" in
    high)
      max_parallel=$((cpu_cores > 8 ? 8 : cpu_cores))
      node_memory=$((ram_gb * 512))  # ~50% of RAM for Node
      shell_concurrency=4
      ;;
    medium)
      max_parallel=$((cpu_cores > 4 ? 4 : cpu_cores))
      node_memory=$((ram_gb * 256))  # ~25% of RAM
      shell_concurrency=2
      ;;
    low)
      max_parallel=2
      node_memory=2048
      shell_concurrency=1
      ;;
  esac

  # Cap node_memory at 16GB
  if [[ $node_memory -gt 16384 ]]; then
    node_memory=16384
  fi

  # Detect container runtime preference
  local container_runtime="docker"
  if is_apple_silicon; then
    # Prefer native container on Apple Silicon
    container_runtime="native"
  fi

  # Generate settings.json
  cat > "$SETTINGS_FILE" <<EOF
{
  "systemProfile": "$profile",
  "detectedAt": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "hardware": {
    "cpuCores": $cpu_cores,
    "ramGB": $ram_gb,
    "os": "$os",
    "appleSilicon": $(is_apple_silicon && echo "true" || echo "false")
  },
  "performance": {
    "maxParallelTasks": $max_parallel,
    "nodeMemoryMB": $node_memory,
    "shellConcurrency": $shell_concurrency,
    "containerRuntime": "$container_runtime"
  },
  "context": {
    "preferLeanAgents": $([ "$profile" = "low" ] && echo "true" || echo "false"),
    "preferConsolidatedRules": $([ "$profile" != "high" ] && echo "true" || echo "false"),
    "maxContextTokens": $([ "$profile" = "high" ] && echo "200000" || echo "100000")
  },
  "build": {
    "makeJobs": "-j$cpu_cores",
    "nodeMaxOldSpaceSize": "$node_memory"
  },
  "notes": [
    "This file was auto-generated based on your system hardware.",
    "Regenerate anytime: scripts/generate-settings.sh",
    "Manual edits are preserved between regenerations if you add 'userOverrides' section."
  ]
}
EOF

  log_success "Generated settings.json with profile: $profile"
  log_info "Location: $SETTINGS_FILE"
}

# Main
main() {
  local profile=""

  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case $1 in
      --low|--minimal)
        profile="low"
        shift
        ;;
      --medium|--standard)
        profile="medium"
        shift
        ;;
      --high|--performance)
        profile="high"
        shift
        ;;
      --help|-h)
        echo "Usage: $0 [--low|--medium|--high]"
        echo ""
        echo "Generate hardware-aware settings.json for Claude Code"
        echo ""
        echo "Options:"
        echo "  --low       Low-end hardware (<16GB RAM)"
        echo "  --medium    Mid-range hardware (16-32GB RAM)"
        echo "  --high      High-end hardware (>32GB RAM)"
        echo "  --help      Show this help message"
        echo ""
        echo "If no profile specified, auto-detects based on available RAM."
        exit 0
        ;;
      *)
        log_error "Unknown option: $1"
        exit 1
        ;;
    esac
  done

  # Ensure .claude directory exists
  mkdir -p "$CLAUDE_HOME"

  # Backup existing settings if present
  if [[ -f "$SETTINGS_FILE" ]]; then
    local backup="${SETTINGS_FILE}.backup.$(date +%Y%m%d%H%M%S)"
    cp "$SETTINGS_FILE" "$backup"
    log_info "Backed up existing settings to: $backup"
  fi

  # Generate settings
  generate_settings "$profile"

  echo ""
  log_info "Settings Summary:"
  if command -v jq &> /dev/null; then
    jq '.' "$SETTINGS_FILE"
  else
    cat "$SETTINGS_FILE"
  fi
}

main "$@"
