#!/usr/bin/env bash
set -euo pipefail

MODE="run"
YOLO=1

usage() {
  cat <<'EOF'
Usage: copilot-planner.sh [--print] [--no-yolo] <goal...>

MyConvergio wrapper for the Copilot planner agent.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --print)
      MODE="print"
      shift
      ;;
    --no-yolo)
      YOLO=0
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --)
      shift
      break
      ;;
    -*)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
    *)
      break
      ;;
  esac
done

if [[ $# -eq 0 ]]; then
  usage >&2
  exit 1
fi

REQUEST="$*"

read -r -d '' PROMPT <<EOF || true
@planner

User request:
$REQUEST

Mandatory routing:
- Use the planner agent, not the built-in /plan command
- Planner model must be claude-opus-4.6-1m
- Follow the shared planner workflow from commands/planner.md
- Do not create an inline plan outside the planner/plan-db flow
EOF

if [[ "$MODE" == "print" ]]; then
  printf '%s\n' "$PROMPT"
  exit 0
fi

if ! command -v copilot >/dev/null 2>&1; then
  echo "ERROR: copilot CLI not found in PATH" >&2
  exit 1
fi

CMD=(copilot)
if [[ "$YOLO" -eq 1 ]]; then
  CMD+=(--yolo)
fi
CMD+=(-p "$PROMPT")

exec "${CMD[@]}"
