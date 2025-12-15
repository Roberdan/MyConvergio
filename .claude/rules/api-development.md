# API Development Standards

> This rule is enforced by the MyConvergio agent ecosystem.

## Overview
Consistent, well-designed APIs are critical for system integration and developer experience. All APIs in the MyConvergio ecosystem must follow RESTful conventions, implement proper error handling, and provide comprehensive documentation.

## Requirements

### RESTful Conventions

#### HTTP Methods
- **GET**: Retrieve resources (idempotent, no side effects)
- **POST**: Create new resources
- **PUT**: Replace entire resource (idempotent)
- **PATCH**: Partial update of resource (idempotent)
- **DELETE**: Remove resource (idempotent)
- Never use GET for operations with side effects

#### Resource Naming
- Use plural nouns for collections: `/api/users`, `/api/products`
- Use specific identifiers: `/api/users/{userId}`
- Nested resources for relationships: `/api/users/{userId}/orders`
- Use kebab-case for multi-word resources: `/api/payment-methods`
- Avoid verbs in URLs (use HTTP methods instead)
- Keep URLs shallow (max 3 levels deep)

#### HTTP Status Codes
- **200 OK**: Successful GET, PUT, PATCH, or DELETE
- **201 Created**: Successful POST that creates a resource
- **204 No Content**: Successful request with no response body (DELETE)
- **400 Bad Request**: Invalid request (validation errors)
- **401 Unauthorized**: Authentication required
- **403 Forbidden**: Authenticated but not authorized
- **404 Not Found**: Resource doesn't exist
- **409 Conflict**: Request conflicts with current state
- **422 Unprocessable Entity**: Validation errors (semantic issues)
- **429 Too Many Requests**: Rate limit exceeded
- **500 Internal Server Error**: Server-side error
- **503 Service Unavailable**: Temporary unavailability

### Error Response Format
- Consistent error response structure across all endpoints
- Include error code, message, and details
- Provide helpful error messages for developers
- Never expose internal implementation details
- Include request ID for tracking

### Pagination
- Implement pagination for all list endpoints
- Support page-based or cursor-based pagination
- Include metadata: total count, page info, links
- Use consistent query parameters: `page`, `limit`, `cursor`
- Default limit should be reasonable (e.g., 20-50)
- Maximum limit to prevent abuse (e.g., 100)

### Filtering and Sorting
- Support filtering via query parameters
- Use consistent naming: `?status=active&category=books`
- Support sorting: `?sort=createdAt&order=desc`
- Allow multiple sort fields: `?sort=priority,createdAt`
- Document available filters and sort fields

### Versioning Strategy
- Version all public APIs from the start
- Use URL versioning: `/api/v1/users` or `/api/v2/users`
- Alternative: Header versioning: `Accept: application/vnd.myapp.v1+json`
- Maintain backwards compatibility within major versions
- Document deprecation timeline for old versions
- Support at least 2 major versions simultaneously

### Rate Limiting
- Implement rate limiting on all public endpoints
- Return `429 Too Many Requests` when limit exceeded
- Include headers: `X-RateLimit-Limit`, `X-RateLimit-Remaining`, `X-RateLimit-Reset`
- Different limits for authenticated vs anonymous users
- Document rate limits in API documentation

### Authentication & Authorization
- Use standard authentication (OAuth 2.0, JWT)
- Include authentication in headers: `Authorization: Bearer {token}`
- Return `401` for missing/invalid authentication
- Return `403` for insufficient permissions
- Validate authorization on every request

### API Documentation
- Use OpenAPI/Swagger specification
- Document all endpoints, parameters, and responses
- Include request/response examples
- Provide interactive API explorer (Swagger UI)
- Keep documentation in sync with implementation
- Version documentation with the API

### CORS Configuration
- Configure CORS for browser-based clients
- Whitelist allowed origins (avoid `*` in production)
- Specify allowed methods and headers
- Handle preflight requests properly

## Examples

### Good Examples

#### RESTful Resource Design
```typescript
// Good: RESTful endpoint structure
GET    /api/v1/users              // List all users
POST   /api/v1/users              // Create new user
GET    /api/v1/users/{userId}     // Get specific user
PUT    /api/v1/users/{userId}     // Replace user
PATCH  /api/v1/users/{userId}     // Update user
DELETE /api/v1/users/{userId}     // Delete user

// Good: Nested resources
GET    /api/v1/users/{userId}/orders           // User's orders
POST   /api/v1/users/{userId}/orders           // Create order for user
GET    /api/v1/users/{userId}/orders/{orderId} // Specific order
```

#### Error Response Format
```typescript
// Good: Consistent error structure
interface ErrorResponse {
  error: {
    code: string;
    message: string;
    details?: Record<string, string[]>;
    requestId: string;
    timestamp: string;
  };
}

// Example response
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Request validation failed",
    "details": {
      "email": ["Email is required", "Email format is invalid"],
      "age": ["Age must be at least 18"]
    },
    "requestId": "req_abc123",
    "timestamp": "2025-12-15T10:30:00Z"
  }
}
```

#### Pagination Response
```typescript
// Good: Comprehensive pagination metadata
{
  "data": [
    { "id": "1", "name": "User 1" },
    { "id": "2", "name": "User 2" }
  ],
  "pagination": {
    "page": 2,
    "limit": 20,
    "total": 150,
    "totalPages": 8,
    "hasNext": true,
    "hasPrev": true
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

#### Rate Limiting Implementation
```typescript
// Good: Rate limiting with informative headers
app.use('/api', rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100, // Limit each IP to 100 requests per windowMs
  standardHeaders: true, // Return rate limit info in headers
  legacyHeaders: false,
  handler: (req, res) => {
    res.status(429).json({
      error: {
        code: 'RATE_LIMIT_EXCEEDED',
        message: 'Too many requests, please try again later',
        retryAfter: req.rateLimit.resetTime,
        requestId: req.id,
        timestamp: new Date().toISOString()
      }
    });
  }
}));

// Response headers:
// X-RateLimit-Limit: 100
// X-RateLimit-Remaining: 0
// X-RateLimit-Reset: 1702641600
```

#### Proper Status Code Usage
```typescript
// Good: Appropriate status codes
app.post('/api/v1/users', async (req, res) => {
  try {
    // Validate input
    const validation = validateUserInput(req.body);
    if (!validation.valid) {
      return res.status(400).json({
        error: {
          code: 'VALIDATION_ERROR',
          message: 'Invalid input',
          details: validation.errors
        }
      });
    }

    // Check for conflicts
    const existingUser = await findUserByEmail(req.body.email);
    if (existingUser) {
      return res.status(409).json({
        error: {
          code: 'USER_ALREADY_EXISTS',
          message: 'User with this email already exists'
        }
      });
    }

    // Create user
    const user = await createUser(req.body);

    // Return 201 Created with Location header
    res.status(201)
       .location(`/api/v1/users/${user.id}`)
       .json({ data: user });
  } catch (error) {
    // Return 500 for unexpected errors
    res.status(500).json({
      error: {
        code: 'INTERNAL_ERROR',
        message: 'An unexpected error occurred',
        requestId: req.id
      }
    });
  }
});
```

#### Filtering and Sorting
```typescript
// Good: Flexible filtering and sorting
GET /api/v1/products?category=electronics&minPrice=100&maxPrice=500&sort=price&order=asc

app.get('/api/v1/products', async (req, res) => {
  const {
    category,
    minPrice,
    maxPrice,
    sort = 'createdAt',
    order = 'desc',
    page = 1,
    limit = 20
  } = req.query;

  const filters = {};
  if (category) filters.category = category;
  if (minPrice) filters.price = { $gte: Number(minPrice) };
  if (maxPrice) filters.price = { ...filters.price, $lte: Number(maxPrice) };

  const products = await findProducts({
    filters,
    sort: { [sort]: order === 'asc' ? 1 : -1 },
    page: Number(page),
    limit: Number(limit)
  });

  res.json({
    data: products.items,
    pagination: products.pagination
  });
});
```

### Bad Examples

#### Non-RESTful Design
```typescript
// Bad: Verbs in URLs, inconsistent structure
POST /api/createUser          // Should be POST /api/users
GET  /api/getUserById/123     // Should be GET /api/users/123
POST /api/deleteUser          // Should be DELETE /api/users/{id}
GET  /api/updateUserStatus    // Should be PATCH /api/users/{id}
```

#### Inconsistent Error Responses
```typescript
// Bad: Different error formats
// Endpoint 1 returns:
{ "error": "User not found" }

// Endpoint 2 returns:
{ "message": "Invalid request", "code": 400 }

// Endpoint 3 returns:
{ "errors": ["Email is required"] }

// Bad: No error details or context
```

#### No Pagination
```typescript
// Bad: Returns all records without pagination
GET /api/users
// Returns 10,000 user records - performance nightmare!
```

#### Poor Status Code Usage
```typescript
// Bad: Always returns 200, even for errors
app.post('/api/users', async (req, res) => {
  const user = await createUser(req.body);
  if (!user) {
    return res.status(200).json({ success: false, error: 'Failed' });
  }
  res.status(200).json({ success: true, data: user });
});

// Bad: Generic status codes
app.get('/api/users/:id', async (req, res) => {
  const user = await findUser(req.params.id);
  if (!user) {
    return res.status(500).json({ error: 'Not found' }); // Should be 404!
  }
  res.json(user);
});
```

#### Unsafe Filtering
```typescript
// Bad: SQL injection vulnerability
app.get('/api/users', async (req, res) => {
  const { name } = req.query;
  const query = `SELECT * FROM users WHERE name = '${name}'`;
  // Vulnerable to SQL injection!
  const users = await db.query(query);
  res.json(users);
});
```

## References
- [RESTful API Design Best Practices](https://restfulapi.net/)
- [HTTP Status Codes](https://httpstatuses.com/)
- [OpenAPI Specification](https://swagger.io/specification/)
- [API Design Patterns](https://microservice-api-patterns.org/)
- [Richardson Maturity Model](https://martinfowler.com/articles/richardsonMaturityModel.html)
- [OAuth 2.0 Specification](https://oauth.net/2/)
- [CORS Specification](https://developer.mozilla.org/en-US/docs/Web/HTTP/CORS)
- [REST API Tutorial](https://www.restapitutorial.com/)
