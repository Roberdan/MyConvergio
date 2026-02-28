#!/bin/bash
# Plan DB CRUD dispatcher
# Sourced by plan-db.sh

if [[ -n "${PLAN_DB_CRUD_MODULES_LOADED:-}" ]]; then
return 0 2>/dev/null || exit 0
fi
export PLAN_DB_CRUD_MODULES_LOADED=1

SCRIPT_DIR_CRUD="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR_CRUD/plan-db/crud-common.sh"
source "$SCRIPT_DIR_CRUD/plan-db/crud-plans.sh"
source "$SCRIPT_DIR_CRUD/plan-db/crud-tasks.sh"
source "$SCRIPT_DIR_CRUD/plan-db/crud-waves.sh"
