#!/bin/bash
# worktree-safety.sh (T2-06)
# Subcommands: pre-check, notify-merge, recover, audit
set -euo pipefail

usage() {
  echo "Usage: $0 {pre-check|notify-merge|recover|audit} [args...]" >&2
  exit 2
}

case "${1:-}" in
  pre-check)
    # Check freshness (behind main?), auto-rebase if <=3, BLOCK if >10, stash if uncommitted
    branch=$(git rev-parse --abbrev-ref HEAD)
    main_branch="main"
    behind=$(git rev-list --count ${branch}..${main_branch} || echo 0)
    uncommitted=$(git status --porcelain | wc -l)
    if [ "$behind" -gt 10 ]; then
      echo "BLOCK: branch $branch is $behind commits behind $main_branch" >&2
      exit 3
    elif [ "$behind" -gt 0 ]; then
      if [ "$behind" -le 3 ]; then
        echo "Auto-rebasing $branch onto $main_branch ($behind behind)"
        git rebase $main_branch || { echo "Rebase failed" >&2; exit 4; }
      else
        echo "Manual rebase required ($behind behind)" >&2
        exit 2
      fi
    fi
    if [ "$uncommitted" -gt 0 ]; then
      echo "Stashing $uncommitted uncommitted changes"
      git stash
    fi
    echo "pre-check done"
    ;;
  notify-merge)
    # Find active worktrees with overlapping files, log WARNING
    worktrees=$(git worktree list | awk '{print $1}')
    overlap_found=0
    for wt1 in $worktrees; do
      for wt2 in $worktrees; do
        [ "$wt1" = "$wt2" ] && continue
        files1=$(cd "$wt1" && git ls-files)
        files2=$(cd "$wt2" && git ls-files)
        for f1 in $files1; do
          for f2 in $files2; do
            if [ "$f1" = "$f2" ]; then
              echo "WARNING: Overlapping file $f1 in $wt1 and $wt2" >&2
              overlap_found=1
            fi
          done
        done
      done
    done
    [ "$overlap_found" -eq 0 ] && echo "No overlaps detected"
    echo "notify-merge done"
    ;;
  recover)
    # Stash uncommitted, log recovery info
    uncommitted=$(git status --porcelain | wc -l)
    if [ "$uncommitted" -gt 0 ]; then
      echo "Recovering: stashing $uncommitted uncommitted changes"
      git stash
      echo "Recovery info: stash created"
    else
      echo "No uncommitted changes to recover"
    fi
    echo "recover done"
    ;;
  audit)
    # List worktrees, flag abandoned/orphaned/stale, output JSON
    worktrees=$(git worktree list | awk '{print $1}')
    now=$(date +%s)
    json="["
    for wt in $worktrees; do
      branch=$(cd "$wt" && git rev-parse --abbrev-ref HEAD)
      last_commit=$(cd "$wt" && git log -1 --format=%ct 2>/dev/null || echo 0)
      age=$((now - last_commit))
      status="active"
      if [ "$age" -gt $((60*60*24*30)) ]; then status="abandoned"; fi
      if [ "$last_commit" -eq 0 ]; then status="orphaned"; fi
      if [ "$age" -gt $((60*60*24*7)) ] && [ "$age" -le $((60*60*24*30)) ]; then status="stale"; fi
      json+="{\"path\":\"$wt\",\"branch\":\"$branch\",\"status\":\"$status\",\"age\":$age},"
    done
    json=${json%,}
    json+="]"
    echo "$json"
    echo "audit done"
    ;;
  *)
    usage
    ;;
esac
