# OWASP Top 10 Security Checklist

## A01:2021 - Broken Access Control

- [ ] Authentication required for all sensitive operations
- [ ] Authorization checks on server-side (not just client)
- [ ] Principle of least privilege enforced
- [ ] No direct object references without validation
- [ ] CORS configured properly

## A02:2021 - Cryptographic Failures

- [ ] Sensitive data encrypted at rest
- [ ] TLS/HTTPS enforced for data in transit
- [ ] Strong cryptographic algorithms (AES-256, RSA-2048+)
- [ ] Secrets not hardcoded in source code
- [ ] Proper key management and rotation

## A03:2021 - Injection

- [ ] All inputs validated and sanitized
- [ ] Parameterized queries used (no string concatenation)
- [ ] ORM used correctly (no raw SQL injection)
- [ ] Command injection prevention
- [ ] NoSQL injection prevention

## A04:2021 - Insecure Design

- [ ] Threat modeling conducted
- [ ] Security requirements defined
- [ ] Secure design patterns applied
- [ ] Security by design, not as afterthought

## A05:2021 - Security Misconfiguration

- [ ] Default credentials changed
- [ ] Error messages don't leak sensitive info
- [ ] Security headers configured (CSP, HSTS, X-Frame-Options)
- [ ] Unnecessary features/services disabled
- [ ] Software up to date with security patches

## A06:2021 - Vulnerable and Outdated Components

- [ ] Dependency inventory maintained (SBOM)
- [ ] Automated vulnerability scanning
- [ ] Regular updates applied
- [ ] No known CVEs in dependencies

## A07:2021 - Identification and Authentication Failures

- [ ] Multi-factor authentication available
- [ ] Password complexity requirements enforced
- [ ] Rate limiting on login attempts
- [ ] Session management secure (timeout, regeneration)
- [ ] Credential stuffing prevention

## A08:2021 - Software and Data Integrity Failures

- [ ] Code signing implemented
- [ ] CI/CD pipeline secured
- [ ] Dependency integrity verified (checksums)
- [ ] Auto-update mechanism secured

## A09:2021 - Security Logging and Monitoring Failures

- [ ] Security events logged (login, access control)
- [ ] Logs protected from tampering
- [ ] Real-time alerting for anomalies
- [ ] Log retention policy defined
- [ ] SIEM integration

## A10:2021 - Server-Side Request Forgery (SSRF)

- [ ] URL validation and allowlisting
- [ ] Network segmentation
- [ ] Disable unused URL schemas
- [ ] Response validation
