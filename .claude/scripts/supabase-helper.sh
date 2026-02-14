#!/usr/bin/env bash
# Supabase CLI wrapper with common operations
# Replaces Supabase MCP (5k token overhead)

set -euo pipefail

# Check if supabase CLI is installed
if ! command -v supabase &> /dev/null; then
  echo "Error: supabase CLI not installed" >&2
  echo "Install: brew install supabase/tap/supabase" >&2
  exit 1
fi

case "${1:-help}" in
  projects|ls)
    # List projects
    supabase projects list
    ;;

  status)
    # Project status
    supabase status
    ;;

  db-push)
    # Push database changes
    supabase db push
    ;;

  db-reset)
    # Reset database
    supabase db reset
    ;;

  migrate)
    # Create migration
    if [ -z "${2:-}" ]; then
      echo "Usage: $0 migrate <name>" >&2
      exit 1
    fi
    supabase migration new "$2"
    ;;

  migrations)
    # List migrations
    supabase migration list
    ;;

  functions)
    # List edge functions
    supabase functions list
    ;;

  deploy)
    # Deploy edge function
    if [ -z "${2:-}" ]; then
      echo "Usage: $0 deploy <function-name>" >&2
      exit 1
    fi
    supabase functions deploy "$2"
    ;;

  logs)
    # View logs
    if [ -z "${2:-}" ]; then
      echo "Usage: $0 logs <service>" >&2
      echo "Services: api, auth, db, storage, functions" >&2
      exit 1
    fi
    supabase logs --service "$2"
    ;;

  link)
    # Link project
    supabase link
    ;;

  help|*)
    cat <<EOF
Supabase CLI Helper

Usage: $0 <command> [args]

Commands:
  projects, ls            List projects
  status                  Show project status
  db-push                 Push database changes
  db-reset                Reset database
  migrate <name>          Create new migration
  migrations              List migrations
  functions               List edge functions
  deploy <function>       Deploy edge function
  logs <service>          View logs (api, auth, db, storage, functions)
  link                    Link to project

Examples:
  $0 projects
  $0 migrate add_user_table
  $0 deploy my-function
  $0 logs api

Documentation: https://supabase.com/docs/guides/cli
EOF
    ;;
esac
