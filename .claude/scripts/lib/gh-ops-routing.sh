#!/bin/bash
# PR lifecycle routing via orchestrator
# Sources: pr-threads.sh, pr-comment-resolver, pr-ops.sh, agent-protocol.sh, delegate.sh
set -euo pipefail

# Source dependencies
source "$(dirname "$0")/../pr-threads.sh"
source "$(dirname "$0")/../pr-comment-resolver"
source "$(dirname "$0")/../pr-ops.sh"
source "$(dirname "$0")/../agent-protocol.sh"
source "$(dirname "$0")/../delegate.sh"

# route_pr_lifecycle: dispatches to PR ops
route_pr_lifecycle() {
  local pr_id="$1"
  # Example dispatch logic
  pr_threads "$pr_id"
  pr_comment_resolver "$pr_id"
  pr_ops "$pr_id"
}

# auto_resolve_pr: orchestrates full PR cycle
auto_resolve_pr() {
  local pr_id="$1"
  local envelope
  envelope=$(build_task_envelope "type: pr-ops" "$pr_id")
  delegate "pr-ops" "$envelope"
}

# End of gh-ops-routing.sh
