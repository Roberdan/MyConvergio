use std::collections::HashSet;

use claude_core::server::routes::{
    DELETE_ROUTES, GET_ROUTES, POST_ROUTES, SSE_ROUTES, PUT_ROUTES, WS_ROUTES,
};

#[test]
fn get_route_count_matches_python_port_contract() {
    assert_eq!(GET_ROUTES.len(), 25);
}

#[test]
fn non_get_route_count_matches_python_port_contract() {
    assert_eq!(POST_ROUTES.len() + PUT_ROUTES.len() + DELETE_ROUTES.len() + SSE_ROUTES.len() + WS_ROUTES.len(), 24);
}

#[test]
fn get_routes_are_unique() {
    let unique: HashSet<_> = GET_ROUTES.iter().collect();
    assert_eq!(unique.len(), GET_ROUTES.len());
}

#[test]
fn non_get_routes_are_unique_per_group() {
    for group in [POST_ROUTES, PUT_ROUTES, DELETE_ROUTES, SSE_ROUTES, WS_ROUTES] {
        let unique: HashSet<_> = group.iter().collect();
        assert_eq!(unique.len(), group.len());
    }
}

#[test]
fn every_route_starts_with_slash() {
    for route in GET_ROUTES
        .iter()
        .chain(POST_ROUTES)
        .chain(PUT_ROUTES)
        .chain(DELETE_ROUTES)
        .chain(SSE_ROUTES)
        .chain(WS_ROUTES)
    {
        assert!(route.starts_with('/'));
    }
}
