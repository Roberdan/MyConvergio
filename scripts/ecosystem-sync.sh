#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SYNC_SCRIPT="$REPO_ROOT/scripts/mesh/sync-to-myconvergio.sh"
MANIFEST="$REPO_ROOT/config/ecosystem-sync-manifest.txt"
SOURCE_DIR="${SOURCE_DIR:-$HOME/.claude}"
TARGET_REPO="$REPO_ROOT"
MODE="all"
DRY_RUN=false
VERBOSE=false
CATEGORY="all"
STRICT=false

usage() {
  cat <<EOF
Usage: $(basename "$0") [all|upstream|mirrors|validate] [options]

Commands:
  all         Upstream sync + mirror sync + validation
  upstream    Sync ~/.claude -> MyConvergio
  mirrors     Sync MyConvergio canonical .claude paths -> mirrored public paths
  validate    Validate sync safety, manifest coverage, and generated agents

Options:
  --dry-run           Show planned operations without writing files
  --verbose           Print unchanged entries too
  --strict            Fail validation on warnings
  --category <name>   Forward category to upstream sync
  --source <dir>      Override upstream source (default: ~/.claude)
  --target <dir>      Override MyConvergio repo root (default: current repo)
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    all|upstream|mirrors|validate) MODE="$1" ;;
    --dry-run) DRY_RUN=true ;;
    --verbose|-v) VERBOSE=true ;;
    --strict) STRICT=true ;;
    --category) CATEGORY="${2:-all}"; shift ;;
    --source) SOURCE_DIR="${2:-$SOURCE_DIR}"; shift ;;
    --target) TARGET_REPO="${2:-$TARGET_REPO}"; shift ;;
    --help|-h) usage; exit 0 ;;
    *)
      echo "Unknown arg: $1" >&2
      usage
      exit 1
      ;;
  esac
  shift
done

run_upstream() {
  local args=(--source "$SOURCE_DIR" --target "$TARGET_REPO" --category "$CATEGORY")
  $DRY_RUN && args+=(--dry-run)
  $VERBOSE && args+=(--verbose)
  "$SYNC_SCRIPT" "${args[@]}"
}

run_mirrors() {
  python3 - "$TARGET_REPO" "$MANIFEST" "$DRY_RUN" "$VERBOSE" <<'PY'
import filecmp
import shutil
import sys
from pathlib import Path

repo = Path(sys.argv[1])
manifest = Path(sys.argv[2])
dry_run = sys.argv[3] == "true"
verbose = sys.argv[4] == "true"
new = updated = unchanged = 0

for raw in manifest.read_text(encoding="utf-8").splitlines():
    line = raw.strip()
    if not line or line.startswith("#"):
        continue
    mode, src_rel, dst_rel, _category, _notes = [part.strip() for part in line.split("|", 4)]
    src = repo / src_rel
    dst = repo / dst_rel
    if not src.exists():
        print(f"WARN missing source: {src_rel}")
        continue
    if mode == "dir":
        for path in sorted(
            p for p in src.rglob("*")
            if p.is_file() and "__pycache__" not in p.parts and p.suffix != ".pyc"
        ):
            rel = path.relative_to(src)
            target = dst / rel
            if not target.exists():
                print(f"NEW     {target.relative_to(repo)} <- {path.relative_to(repo)}")
                new += 1
                if not dry_run:
                    target.parent.mkdir(parents=True, exist_ok=True)
                    shutil.copy2(path, target)
            elif not filecmp.cmp(path, target, shallow=False):
                print(f"UPDATED {target.relative_to(repo)} <- {path.relative_to(repo)}")
                updated += 1
                if not dry_run:
                    shutil.copy2(path, target)
            else:
                unchanged += 1
                if verbose:
                    print(f"UNCHANGED {target.relative_to(repo)}")
    elif mode == "file":
        if not dst.exists():
            print(f"NEW     {dst.relative_to(repo)} <- {src.relative_to(repo)}")
            new += 1
            if not dry_run:
                dst.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(src, dst)
        elif not filecmp.cmp(src, dst, shallow=False):
            print(f"UPDATED {dst.relative_to(repo)} <- {src.relative_to(repo)}")
            updated += 1
            if not dry_run:
                shutil.copy2(src, dst)
        else:
            unchanged += 1
            if verbose:
                print(f"UNCHANGED {dst.relative_to(repo)}")
    else:
        print(f"WARN invalid manifest mode: {mode}")

print(f"SUMMARY new={new} updated={updated} unchanged={unchanged}")
PY
}

run_validate() {
  python3 - "$TARGET_REPO" "$MANIFEST" "$STRICT" <<'PY'
import re
import sys
from pathlib import Path

repo = Path(sys.argv[1])
manifest = Path(sys.argv[2])
strict = sys.argv[3] == "true"
issues = []
checks = 0
scan_paths = set()
home = Path.home()
user_markers = [str(home), f"/Users/{home.name}", f"/home/{home.name}"]

for raw in manifest.read_text(encoding="utf-8").splitlines():
    line = raw.strip()
    if not line or line.startswith("#"):
        continue
    mode, src_rel, dst_rel, _category, _notes = [part.strip() for part in line.split("|", 4)]
    src = repo / src_rel
    dst = repo / dst_rel
    checks += 1
    if not src.exists():
      issues.append(f"missing source in manifest: {src_rel}")
    if mode not in {"file", "dir"}:
      issues.append(f"invalid manifest mode: {mode}")
    if mode == "file":
        scan_paths.add(src)
        scan_paths.add(dst)
    elif mode == "dir" and src.exists():
        scan_paths.update(
            p for p in src.rglob("*") if p.is_file() and "__pycache__" not in p.parts and p.suffix != ".pyc"
        )
        if dst.exists():
            scan_paths.update(
                p for p in dst.rglob("*") if p.is_file() and "__pycache__" not in p.parts and p.suffix != ".pyc"
            )

scan_paths.update(
    {
        repo / "scripts/ecosystem-sync.sh",
        repo / "scripts/mesh/sync-to-myconvergio.sh",
        repo / ".claude/agents/release_management/ecosystem-sync.md",
        repo / "copilot-agents/ecosystem-sync.agent.md",
    }
)
for path in sorted(scan_paths):
    if not path.exists() or not path.is_file():
        continue
    try:
        content = path.read_text(encoding="utf-8")
    except Exception:
        continue
    for marker in user_markers:
        if marker and marker in content:
            issues.append(f"sanitize hit {marker} in {path.relative_to(repo)}")
            break

print(f"Validated {checks} manifest entries")
if issues:
    for issue in issues:
        print(f"ISSUE {issue}")
    sys.exit(1 if strict else 0)
print("Validation clean")
PY
  local gen_args=()
  $DRY_RUN && gen_args+=(--dry-run)
  $VERBOSE && gen_args+=(--verbose)
  "$REPO_ROOT/scripts/generate-copilot-agents.sh" "${gen_args[@]}"
}

case "$MODE" in
  upstream) run_upstream ;;
  mirrors) run_mirrors ;;
  validate) run_validate ;;
  all)
    run_upstream
    run_mirrors
    run_validate
    ;;
esac
