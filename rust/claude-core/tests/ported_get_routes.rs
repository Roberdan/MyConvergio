use claude_core::server::routes::GET_ROUTES;

macro_rules! get_route_case {
    ($exists:ident, $shape:ident, $route:expr) => {
        #[test]
        fn $exists() {
            assert!(GET_ROUTES.contains(&$route));
        }

        #[test]
        fn $shape() {
            assert!($route.starts_with("/api/"));
        }
    };
}

get_route_case!(has_overview, shape_overview, "/api/overview");
get_route_case!(has_mission, shape_mission, "/api/mission");
get_route_case!(has_organization, shape_organization, "/api/organization");
get_route_case!(has_live_system, shape_live_system, "/api/live-system");
get_route_case!(has_tokens_daily, shape_tokens_daily, "/api/tokens/daily");
get_route_case!(has_tokens_models, shape_tokens_models, "/api/tokens/models");
get_route_case!(has_mesh, shape_mesh, "/api/mesh");
get_route_case!(has_mesh_sync_status, shape_mesh_sync_status, "/api/mesh/sync-status");
get_route_case!(has_history, shape_history, "/api/history");
get_route_case!(has_tasks_distribution, shape_tasks_distribution, "/api/tasks/distribution");
get_route_case!(has_tasks_blocked, shape_tasks_blocked, "/api/tasks/blocked");
get_route_case!(has_plans_assignable, shape_plans_assignable, "/api/plans/assignable");
get_route_case!(has_notifications, shape_notifications, "/api/notifications");
get_route_case!(has_nightly_jobs, shape_nightly_jobs, "/api/nightly/jobs");
get_route_case!(has_projects, shape_projects, "/api/projects");
get_route_case!(has_events, shape_events, "/api/events");
get_route_case!(has_coordinator_status, shape_coordinator_status, "/api/coordinator/status");
get_route_case!(has_coordinator_toggle, shape_coordinator_toggle, "/api/coordinator/toggle");
get_route_case!(has_peers, shape_peers, "/api/peers");
get_route_case!(has_peers_discover, shape_peers_discover, "/api/peers/discover");
get_route_case!(has_agents, shape_agents, "/api/agents");
get_route_case!(has_sessions, shape_sessions, "/api/sessions");
get_route_case!(has_chat_models, shape_chat_models, "/api/chat/models");
get_route_case!(has_chat_sessions, shape_chat_sessions, "/api/chat/sessions");
