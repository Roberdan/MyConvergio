<!-- v2.0.0 -->

# API Development Standards

> MyConvergio agent ecosystem rule

## REST Conventions

**Methods**: GET (retrieve, idempotent), POST (create), PUT (replace, idempotent), PATCH (partial update, idempotent), DELETE (remove, idempotent) | Never GET with side effects

**Naming**: Plural nouns `/api/users`, identifiers `/api/users/{userId}`, nested `/api/users/{userId}/orders` | kebab-case multi-word `/api/payment-methods` | No verbs, max 3 levels deep

**Status Codes**: 200 OK, 201 Created, 204 No Content | 400 Bad Request, 401 Unauthorized, 403 Forbidden, 404 Not Found | 409 Conflict, 422 Validation Error, 429 Rate Limit, 500 Internal Error, 503 Unavailable

## Error Format

Consistent structure: `{error: {code, message, details?, requestId, timestamp}}` | Helpful messages | Never expose internals | Include request ID

```typescript
// Example error response
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Request validation failed",
    "details": {"email": ["Email is required"]},
    "requestId": "req_abc123",
    "timestamp": "2025-12-15T10:30:00Z"
  }
}
```

## Pagination

**All list endpoints** | Page or cursor-based | Metadata: total, page info, links | Query: `?page=1&limit=20` | Default 20-50, max 100 | Include hasNext, hasPrev

```typescript
{
  "data": [...],
  "pagination": {
    "page": 2, "limit": 20, "total": 150, "totalPages": 8,
    "hasNext": true, "hasPrev": true
  },
  "links": {"first": "...", "prev": "...", "self": "...", "next": "...", "last": "..."}
}
```

## Filtering & Sorting

Query params: `?status=active&category=books&sort=createdAt&order=desc` | Multi-field sort: `?sort=priority,createdAt` | Document available filters

## Versioning

URL versioning `/api/v1/users` | Backwards compatible within major version | Support 2+ major versions | Document deprecation timeline

## Rate Limiting

All public endpoints | Return 429 with headers: `X-RateLimit-Limit`, `X-RateLimit-Remaining`, `X-RateLimit-Reset` | Different limits for authed vs anon | Document limits

## Auth

OAuth 2.0 or JWT | Header: `Authorization: Bearer {token}` | 401 for invalid auth, 403 for insufficient permissions | Validate every request

## Documentation

OpenAPI/Swagger spec | All endpoints, params, responses with examples | Interactive explorer (Swagger UI) | Keep in sync, version with API

## CORS

Whitelist origins (no `*` in prod) | Specify allowed methods/headers | Handle preflight properly

## Anti-Patterns

❌ Verbs in URLs (`POST /api/createUser`) | ❌ Inconsistent error formats | ❌ No pagination | ❌ Generic 200 for errors | ❌ SQL injection via unparameterized queries
