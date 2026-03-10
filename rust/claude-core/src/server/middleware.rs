use axum::body::Body;
use axum::http::{Method, Request, StatusCode};
use axum::middleware::Next;
use axum::response::{IntoResponse, Response};
use axum::Json;
use std::env;
use std::sync::OnceLock;
use tower_http::cors::CorsLayer;

pub fn cors_layer() -> CorsLayer {
    let origins = env::var("CONVERGIO_CORS_ORIGINS")
        .ok()
        .map(|value| {
            value
                .split(',')
                .map(str::trim)
                .filter(|origin| !origin.is_empty())
                .filter_map(|origin| axum::http::HeaderValue::from_str(origin).ok())
                .collect::<Vec<_>>()
        })
        .filter(|parsed| !parsed.is_empty())
        .unwrap_or_else(|| {
            vec![
                axum::http::HeaderValue::from_static("http://localhost:8420"),
                axum::http::HeaderValue::from_static("http://127.0.0.1:8420"),
            ]
        });

    CorsLayer::new()
        .allow_origin(origins)
        .allow_methods([
            Method::GET,
            Method::POST,
            Method::PUT,
            Method::DELETE,
            Method::OPTIONS,
        ])
        .allow_headers([
            axum::http::header::CONTENT_TYPE,
            axum::http::header::AUTHORIZATION,
            axum::http::header::ACCEPT,
        ])
}

static AUTH_TOKEN: OnceLock<Option<String>> = OnceLock::new();

fn get_auth_token() -> &'static Option<String> {
    AUTH_TOKEN.get_or_init(|| {
        env::var("CONVERGIO_AUTH_TOKEN").ok().filter(|t| !t.is_empty())
    })
}

/// Returns true if the token matches or auth is disabled (no env var set).
pub fn check_bearer(header_value: Option<&str>) -> bool {
    match get_auth_token() {
        None => true, // dev mode — no token configured
        Some(expected) => header_value
            .and_then(|v| v.strip_prefix("Bearer "))
            .map(|t| t == expected.as_str())
            .unwrap_or(false),
    }
}

/// Returns true if this request requires Bearer auth.
fn needs_auth(method: &Method, path: &str) -> bool {
    if path == "/api/health" {
        return false;
    }
    // Mutable HTTP methods always need auth
    if matches!(*method, Method::POST | Method::PUT | Method::DELETE) {
        return true;
    }
    // WebSocket PTY and plan mutation SSE endpoints need auth even on GET
    const PROTECTED_GET: &[&str] = &[
        "/ws/pty",
        "/api/plan/start",
        "/api/plan/delegate",
        "/api/plan/preflight",
    ];
    PROTECTED_GET.contains(&path)
}

/// Axum middleware: rejects mutable requests without a valid Bearer token.
/// GET read-only routes pass through. Auth disabled when env var is unset.
pub async fn require_auth(req: Request<Body>, next: Next) -> Response {
    if !needs_auth(req.method(), req.uri().path()) {
        return next.run(req).await;
    }

    let auth_header = req
        .headers()
        .get("authorization")
        .and_then(|v| v.to_str().ok());

    if check_bearer(auth_header) {
        next.run(req).await
    } else {
        (
            StatusCode::UNAUTHORIZED,
            Json(serde_json::json!({
                "error": "Unauthorized",
                "message": "Valid Bearer token required"
            })),
        )
            .into_response()
    }
}

/// Middleware that ensures responses include a Cache-Control header when absent.
/// Simple default: private, max-age=10
pub async fn set_cache_headers(req: Request<Body>, next: Next) -> Response {
    use axum::http::header::CACHE_CONTROL;
    use axum::http::HeaderValue;

    let mut res = next.run(req).await;
    if !res.headers().contains_key(CACHE_CONTROL) {
        res.headers_mut()
            .insert(CACHE_CONTROL, HeaderValue::from_static("private, max-age=10"));
    }
    res
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn auth_disabled_when_no_env_var() {
        if get_auth_token().is_none() {
            assert!(check_bearer(None));
            assert!(check_bearer(Some("Bearer anything")));
            assert!(check_bearer(Some("garbage")));
        }
    }

    #[test]
    fn needs_auth_mutable_methods() {
        assert!(needs_auth(&Method::POST, "/api/ideas"));
        assert!(needs_auth(&Method::PUT, "/api/ideas/1"));
        assert!(needs_auth(&Method::DELETE, "/api/ideas/1"));
    }

    #[test]
    fn needs_auth_protected_get_paths() {
        assert!(needs_auth(&Method::GET, "/ws/pty"));
        assert!(needs_auth(&Method::GET, "/api/plan/start"));
        assert!(needs_auth(&Method::GET, "/api/plan/delegate"));
        assert!(needs_auth(&Method::GET, "/api/plan/preflight"));
    }

    #[test]
    fn no_auth_for_read_routes() {
        assert!(!needs_auth(&Method::GET, "/api/health"));
        assert!(!needs_auth(&Method::GET, "/api/overview"));
        assert!(!needs_auth(&Method::GET, "/api/ideas"));
        assert!(!needs_auth(&Method::GET, "/ws/brain"));
        assert!(!needs_auth(&Method::GET, "/ws/dashboard"));
    }
}
