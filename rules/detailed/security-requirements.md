# Security Requirements

> This rule is enforced by the MyConvergio agent ecosystem.

## Overview
Security is a first-class concern in the MyConvergio ecosystem. All code must adhere to industry-standard security practices, with awareness of OWASP Top 10 vulnerabilities and implementation of defense-in-depth strategies.

## Requirements

### Input Validation
- Validate all user input on both client and server side
- Use allowlists (whitelist) over denylists (blacklist) when possible
- Sanitize input before processing or storage
- Implement length limits on all text inputs
- Validate data types, formats, and ranges
- Reject unexpected or malformed input

### SQL Security
- Always use parameterized queries or prepared statements
- Never concatenate user input into SQL strings
- Use ORM frameworks with built-in protection (SQLAlchemy, Prisma)
- Apply principle of least privilege for database accounts
- Implement connection pooling with proper timeout settings

### Cross-Site Scripting (XSS) Prevention
- Escape all user-generated content before rendering in HTML
- Use Content Security Policy (CSP) headers
- Sanitize HTML input using established libraries (DOMPurify)
- Never use `dangerouslySetInnerHTML` without sanitization
- Set appropriate `X-Content-Type-Options` headers

### Secrets Management
- Never commit secrets, API keys, or credentials to version control
- Use environment variables for all sensitive configuration
- Use secret management services (HashiCorp Vault, AWS Secrets Manager)
- Rotate secrets regularly
- Use `.env` files locally, never commit them (`.gitignore`)
- Use different secrets for different environments

### Authentication & Authorization
- Implement proper authentication for all protected resources
- Use industry-standard protocols (OAuth 2.0, OpenID Connect)
- Implement role-based access control (RBAC)
- Verify authorization on every request (server-side)
- Use secure session management
- Implement account lockout after failed login attempts
- Require strong passwords (minimum length, complexity)

### HTTPS & Transport Security
- Use HTTPS for all external communication
- Implement HSTS (HTTP Strict Transport Security)
- Use secure cookies (`Secure`, `HttpOnly`, `SameSite` flags)
- Validate SSL/TLS certificates
- Use TLS 1.2 or higher

### Dependencies & Supply Chain
- Keep all dependencies up to date
- Use dependency scanning tools (Snyk, npm audit, safety)
- Review security advisories regularly
- Pin dependency versions in production
- Verify package integrity using checksums

### Error Handling & Logging
- Never expose stack traces or internal details to users
- Log security events (failed logins, access violations)
- Sanitize logs to prevent log injection
- Implement rate limiting to prevent abuse
- Monitor for suspicious patterns

## Examples

### Good Examples

#### SQL Parameterization (Python)
```python
# Good: Parameterized query
def get_user_by_email(email: str) -> Optional[User]:
    query = "SELECT * FROM users WHERE email = ?"
    result = db.execute(query, (email,))
    return result.fetchone()

# Good: ORM usage
def get_user_by_email(email: str) -> Optional[User]:
    return db.query(User).filter(User.email == email).first()
```

#### Input Validation (TypeScript)
```typescript
// Good: Comprehensive validation
const validateEmail = (email: string): boolean => {
  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  return email.length <= 255 && emailRegex.test(email);
};

const createUser = async (email: string, name: string) => {
  if (!validateEmail(email)) {
    throw new ValidationError('Invalid email format');
  }
  if (name.length < 2 || name.length > 100) {
    throw new ValidationError('Name must be 2-100 characters');
  }
  // Proceed with sanitized input
};
```

#### Secrets Management
```typescript
// Good: Environment variables
const apiKey = process.env.STRIPE_API_KEY;
if (!apiKey) {
  throw new Error('STRIPE_API_KEY not configured');
}

// Good: .env file (not committed)
// .env
STRIPE_API_KEY=sk_live_xxxxxxxxxxxxx
DATABASE_URL=postgresql://user:pass@host:5432/db
```

#### XSS Prevention (React)
```typescript
// Good: Sanitized HTML
import DOMPurify from 'dompurify';

const SafeHtmlDisplay = ({ htmlContent }: { htmlContent: string }) => {
  const sanitized = DOMPurify.sanitize(htmlContent);
  return <div dangerouslySetInnerHTML={{ __html: sanitized }} />;
};

// Good: Escaped by default
const UserComment = ({ comment }: { comment: string }) => {
  return <p>{comment}</p>; // React escapes by default
};
```

### Bad Examples

#### SQL Injection Vulnerability
```python
# Bad: String concatenation - SQL injection risk!
def get_user_by_email(email: str):
    query = f"SELECT * FROM users WHERE email = '{email}'"
    return db.execute(query)
# Attacker can use: email = "'; DROP TABLE users; --"
```

#### Hardcoded Secrets
```typescript
// Bad: Secret in code!
const API_KEY = 'NEVER_HARDCODE_SECRETS_USE_ENV_VARS';
fetch('https://api.stripe.com/v1/charges', {
  headers: { 'Authorization': `Bearer ${API_KEY}` }
});
```

#### No Input Validation
```typescript
// Bad: No validation
const createUser = async (email: string, age: number) => {
  await db.users.create({ email, age });
  // What if email is malicious HTML? What if age is -1000?
};
```

#### XSS Vulnerability
```typescript
// Bad: Unescaped user content
const UserProfile = ({ bio }: { bio: string }) => {
  return <div dangerouslySetInnerHTML={{ __html: bio }} />;
  // Attacker can inject: <script>steal_cookies()</script>
};
```

## References
- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [OWASP Cheat Sheet Series](https://cheatsheetseries.owasp.org/)
- [CWE Top 25 Most Dangerous Software Weaknesses](https://cwe.mitre.org/top25/)
- [NIST Cybersecurity Framework](https://www.nist.gov/cyberframework)
- [MyConvergio Security Framework](../frameworks/security-framework.md)
- [SQLAlchemy Security Considerations](https://docs.sqlalchemy.org/en/20/faq/security.html)
- [OWASP SQL Injection Prevention](https://cheatsheetseries.owasp.org/cheatsheets/SQL_Injection_Prevention_Cheat_Sheet.html)
- [Content Security Policy (CSP)](https://developer.mozilla.org/en-US/docs/Web/HTTP/CSP)
