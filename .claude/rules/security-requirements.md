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

## References

- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [OWASP Cheat Sheet Series](https://cheatsheetseries.owasp.org/)
- [CWE Top 25](https://cwe.mitre.org/top25/)
- [NIST Cybersecurity Framework](https://www.nist.gov/cyberframework)
