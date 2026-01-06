#!/bin/bash
# Plan DB Display - Output and export functions
# Sourced by plan-db.sh

# Show kanban board
cmd_kanban() {
    echo -e "${BLUE}=============== KANBAN BOARD ===============${NC}"
    echo ""

    echo -e "${YELLOW}DOING${NC}"
    sqlite3 -column "$DB_FILE" "
        SELECT project_name, plan_name, progress || '%' as prog,
               CASE WHEN is_master THEN '*' ELSE '' END as m
        FROM v_kanban WHERE status = 'doing';
    " || echo "  (none)"
    echo ""

    echo -e "${NC}TODO${NC}"
    sqlite3 -column "$DB_FILE" "
        SELECT project_name, plan_name,
               CASE WHEN is_master THEN '*' ELSE '' END as m
        FROM v_kanban WHERE status = 'todo' LIMIT 10;
    " || echo "  (none)"
    echo ""

    echo -e "${GREEN}DONE (recent)${NC}"
    sqlite3 -column "$DB_FILE" "
        SELECT project_name, plan_name, completed_at
        FROM v_kanban WHERE status = 'done'
        ORDER BY completed_at DESC LIMIT 5;
    " || echo "  (none)"
}

# Get plan as JSON
cmd_json() {
    local plan_id="$1"
    sqlite3 -json "$DB_FILE" "
        SELECT p.id, p.name, p.status, p.is_master, p.tasks_done, p.tasks_total,
               p.created_at, p.started_at, p.completed_at, p.validated_at,
               pr.id as project_id, pr.name as project_name
        FROM plans p
        JOIN projects pr ON p.project_id = pr.id
        WHERE p.id = $plan_id;
    "
}

# Get kanban as JSON
cmd_kanban_json() {
    sqlite3 -json "$DB_FILE" "SELECT * FROM v_kanban;"
}

# Quick status for current context
cmd_status() {
    local project_id="${1:-}"

    echo -e "${BLUE}=== Quick Status ===${NC}"

    # Active plans
    echo -e "\n${YELLOW}Active Plans:${NC}"
    if [[ -n "$project_id" ]]; then
        sqlite3 -column "$DB_FILE" "
            SELECT name, tasks_done || '/' || tasks_total as progress
            FROM plans WHERE project_id = '$project_id' AND status = 'doing';
        "
    else
        sqlite3 -column "$DB_FILE" "
            SELECT pr.name as project, p.name as plan, p.tasks_done || '/' || p.tasks_total as progress
            FROM plans p JOIN projects pr ON p.project_id = pr.id
            WHERE p.status = 'doing' LIMIT 5;
        "
    fi

    # In-progress tasks
    echo -e "\n${YELLOW}In-Progress Tasks:${NC}"
    sqlite3 -column "$DB_FILE" "
        SELECT task_id, title, wave_id FROM tasks
        WHERE status = 'in_progress'
        ${project_id:+AND project_id = '$project_id'}
        LIMIT 5;
    "
}
