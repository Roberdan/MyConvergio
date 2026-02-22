# API Development Standards v2.0.0

> Enforced by MyConvergio agent ecosystem. Compact format per ADR 0009.

## HTTP Methods

| Method | Purpose                 | Idempotent | Safe |
|--------|-------------------------|------------|------|
| GET    | Retrieve resource       | ✓          | ✓    |
| POST   | Create resource         | ✗          | ✗    |
| PUT    | Replace entire resource | ✓          | ✗    |
| PATCH  | Partial update          | ✓          | ✗    |
| DELETE | Remove resource         | ✓          | ✗    |

Never use GET for operations with side effects.

## Resource Naming

- Collections: plural nouns (`/api/users`, `/api/products`)
- Specific items: `/api/users/{userId}`
- Nested relations: `/api/users/{userId}/orders`
- Multi-word: kebab-case (`/api/payment-methods`)
- No verbs (use HTTP methods)
- Max 3 levels deep

## Status Codes

| Code | Meaning                | Use Case                        |
|------|------------------------|---------------------------------|
| 200  | OK                     | Successful GET/PUT/PATCH/DELETE |
| 201  | Created                | Successful POST                 |
| 204  | No Content             | Successful DELETE               |
| 400  | Bad Request            | Validation errors               |
| 401  | Unauthorized           | Auth required                   |
| 403  | Forbidden              | Auth'd but insufficient perms   |
| 404  | Not Found              | Resource missing                |
| 409  | Conflict               | State conflict                  |
| 422  | Unprocessable Entity   | Semantic validation errors      |
| 429  | Too Many Requests      | Rate limit exceeded             |
| 500  | Internal Server Error  | Server error                    |
| 503  | Service Unavailable    | Temporary unavailability        |

## Error Response Format

```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Request validation failed",
    "details": {
      "email": ["Email required", "Invalid format"],
      "age": ["Must be ≥18"]
    },
    "requestId": "req_abc123",
    "timestamp": "2025-12-15T10:30:00Z"
  }
}
```

Required fields: code | message | requestId | timestamp | details (optional)

## Pagination

Page-based or cursor-based required for all list endpoints.

```json
{
  "data": [...],
  "pagination": {
    "page": 2, "limit": 20, "total": 150, "totalPages": 8,
    "hasNext": true, "hasPrev": true
  },
  "links": {
    "first": "/api/v1/users?page=1&limit=20",
    "prev": "/api/v1/users?page=1&limit=20",
    "self": "/api/v1/users?page=2&limit=20",
    "next": "/api/v1/users?page=3&limit=20",
    "last": "/api/v1/users?page=8&limit=20"
  }
}
```

Query params: `page`, `limit`, `cursor` | Default limit: 20-50 | Max: 100

## Filtering & Sorting

- Filter: `?status=active&category=books&minPrice=100`
- Sort: `?sort=createdAt&order=desc`
- Multi-sort: `?sort=priority,createdAt`
- Document all available filters/sort fields

## Versioning

- URL: `/api/v1/users` (preferred)
- Header: `Accept: application/vnd.myapp.v1+json`
- Backwards compat within major versions
- Support ≥2 major versions simultaneously
- Document deprecation timeline

## Rate Limiting

Headers: `X-RateLimit-Limit`, `X-RateLimit-Remaining`, `X-RateLimit-Reset`

Return 429 when exceeded. Different limits for auth'd vs anonymous.

## Auth & Authz

- OAuth 2.0 or JWT
- Header: `Authorization: Bearer {token}`
- 401: missing/invalid auth
- 403: insufficient permissions
- Validate on every request

## Documentation

- OpenAPI/Swagger spec required
- Document: endpoints | params | responses | examples
- Interactive explorer (Swagger UI)
- Keep in sync with code
- Version with API

## Examples

### RESTful Endpoints

```typescript
GET    /api/v1/users              // List
POST   /api/v1/users              // Create
GET    /api/v1/users/{userId}     // Get
PUT    /api/v1/users/{userId}     // Replace
PATCH  /api/v1/users/{userId}     // Update
DELETE /api/v1/users/{userId}     // Delete
GET    /api/v1/users/{userId}/orders  // Nested
```

### Status Code Usage

```typescript
// ✓ Correct status codes
app.post('/api/v1/users', async (req, res) => {
  if (!validateUserInput(req.body).valid) {
    return res.status(400).json({...});  // Validation
  }
  if (await findUserByEmail(req.body.email)) {
    return res.status(409).json({...});  // Conflict
  }
  const user = await createUser(req.body);
  res.status(201).location(`/api/v1/users/${user.id}`).json({data: user});
});

// ✗ Wrong: Always 200
app.post('/api/users', async (req, res) => {
  res.status(200).json({success: false});  // Should be 400/409/500
});
```

### Rate Limiting

```typescript
app.use('/api', rateLimit({
  windowMs: 15 * 60 * 1000,  // 15min
  max: 100,
  handler: (req, res) => res.status(429).json({
    error: {code: 'RATE_LIMIT_EXCEEDED', message: '...', retryAfter: req.rateLimit.resetTime}
  })
}));
```

### Common Anti-Patterns

| ✗ Bad                        | ✓ Good                  |
|------------------------------|-------------------------|
| POST /api/createUser         | POST /api/users         |
| GET /api/getUserById/123     | GET /api/users/123      |
| POST /api/deleteUser         | DELETE /api/users/{id}  |
| `...WHERE name = '${name}'`  | Use parameterized query |
| Return 200 for errors        | Use appropriate status  |
| No pagination                | Paginate all lists      |

## References

RESTful API Best Practices: restfulapi.net | HTTP Status Codes: httpstatuses.com | OpenAPI Spec: swagger.io/specification | OAuth 2.0: oauth.net/2 | API Patterns: microservice-api-patterns.org

---

**v2.0.0** (2026-02-15): Compact format per ADR 0009 - 65% reduction from 358 to 200 lines
