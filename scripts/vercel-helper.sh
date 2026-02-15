#!/usr/bin/env bash
# Vercel CLI wrapper with common operations
# Replaces Vercel MCP (2.6k token overhead)

# Version: 1.0.0
set -euo pipefail

# Check if vercel CLI is installed
if ! command -v vercel &> /dev/null; then
  echo "Error: vercel CLI not installed" >&2
  echo "Install: npm i -g vercel" >&2
  exit 1
fi

case "${1:-help}" in
  projects|ls)
    # List projects
    vercel projects ls
    ;;

  deployments)
    # List deployments
    vercel ls
    ;;

  deploy)
    # Deploy current project
    shift
    vercel "$@"
    ;;

  logs)
    # View logs
    if [ -z "${2:-}" ]; then
      vercel logs
    else
      vercel logs "$2"
    fi
    ;;

  env)
    # List environment variables
    vercel env ls
    ;;

  env-add)
    # Add environment variable
    if [ -z "${2:-}" ] || [ -z "${3:-}" ]; then
      echo "Usage: $0 env-add <key> <value> [environment]" >&2
      exit 1
    fi
    vercel env add "$2" "${4:-production}" <<< "$3"
    ;;

  domains)
    # List domains
    vercel domains ls
    ;;

  status)
    # Show deployment status
    if [ -z "${2:-}" ]; then
      echo "Usage: $0 status <deployment-url-or-id>" >&2
      exit 1
    fi
    vercel inspect "$2"
    ;;

  rollback)
    # Rollback to previous deployment
    vercel rollback
    ;;

  help|*)
    cat <<EOF
Vercel CLI Helper

Usage: $0 <command> [args]

Commands:
  projects, ls            List projects
  deployments             List deployments
  deploy [options]        Deploy current project
  logs [deployment]       View logs
  env                     List environment variables
  env-add <key> <value>   Add environment variable
  domains                 List domains
  status <deployment>     Show deployment status
  rollback                Rollback to previous deployment

Examples:
  $0 projects
  $0 deploy --prod
  $0 logs
  $0 env-add DATABASE_URL "postgresql://..."
  $0 status myapp-abc123.vercel.app

Documentation: https://vercel.com/docs/cli
EOF
    ;;
esac
