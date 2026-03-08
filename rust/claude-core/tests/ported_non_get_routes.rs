use claude_core::server::routes::{DELETE_ROUTES, POST_ROUTES, SSE_ROUTES, PUT_ROUTES, WS_ROUTES};

macro_rules! route_case {
    ($group:ident, $exists:ident, $shape:ident, $route:expr, $prefix:expr) => {
        #[test]
        fn $exists() {
            assert!($group.contains(&$route));
        }

        #[test]
        fn $shape() {
            assert!($route.starts_with($prefix));
        }
    };
}

route_case!(POST_ROUTES, has_chat_session_post, shape_chat_session_post, "/api/chat/session", "/api/");
route_case!(POST_ROUTES, has_chat_message_post, shape_chat_message_post, "/api/chat/message", "/api/");
route_case!(POST_ROUTES, has_chat_approve_post, shape_chat_approve_post, "/api/chat/approve", "/api/");
route_case!(POST_ROUTES, has_chat_execute_post, shape_chat_execute_post, "/api/chat/execute", "/api/");
route_case!(POST_ROUTES, has_github_repo_create_post, shape_github_repo_create_post, "/api/github/repo/create", "/api/");
route_case!(POST_ROUTES, has_mesh_init_post, shape_mesh_init_post, "/api/mesh/init", "/api/");
route_case!(POST_ROUTES, has_plan_status_post, shape_plan_status_post, "/api/plan-status", "/api/");
route_case!(POST_ROUTES, has_peers_post, shape_peers_post, "/api/peers", "/api/");
route_case!(POST_ROUTES, has_peers_ssh_check_post, shape_peers_ssh_check_post, "/api/peers/ssh-check", "/api/");
route_case!(POST_ROUTES, has_plan_validate_post, shape_plan_validate_post, "/api/plans/:plan_id/validate", "/api/");

route_case!(PUT_ROUTES, has_chat_requirement_put, shape_chat_requirement_put, "/api/chat/requirement", "/api/");
route_case!(PUT_ROUTES, has_peers_name_put, shape_peers_name_put, "/api/peers/:name", "/api/");

route_case!(DELETE_ROUTES, has_chat_session_delete, shape_chat_session_delete, "/api/chat/session", "/api/");
route_case!(DELETE_ROUTES, has_peers_name_delete, shape_peers_name_delete, "/api/peers/:name", "/api/");

route_case!(SSE_ROUTES, has_chat_stream_sse, shape_chat_stream_sse, "/api/chat/stream/:sid", "/api/");
route_case!(SSE_ROUTES, has_mesh_action_stream_sse, shape_mesh_action_stream_sse, "/api/mesh/action/stream", "/api/");
route_case!(SSE_ROUTES, has_mesh_fullsync_sse, shape_mesh_fullsync_sse, "/api/mesh/fullsync", "/api/");
route_case!(SSE_ROUTES, has_plan_preflight_sse, shape_plan_preflight_sse, "/api/plan/preflight", "/api/");
route_case!(SSE_ROUTES, has_plan_delegate_sse, shape_plan_delegate_sse, "/api/plan/delegate", "/api/");
route_case!(SSE_ROUTES, has_plan_start_sse, shape_plan_start_sse, "/api/plan/start", "/api/");
route_case!(SSE_ROUTES, has_mesh_pull_db_sse, shape_mesh_pull_db_sse, "/api/mesh/pull-db", "/api/");

route_case!(WS_ROUTES, has_ws_brain, shape_ws_brain, "/ws/brain", "/ws/");
route_case!(WS_ROUTES, has_ws_dashboard, shape_ws_dashboard, "/ws/dashboard", "/ws/");
