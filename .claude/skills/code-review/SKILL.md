---
name: code-review
description: Comprehensive code review with security, patterns, and quality focus
allowed-tools:
  - Read
  - Glob
  - Grep
  - Bash
context: fork
user-invocable: true
version: "1.0.0"
---

# Code Review Skill

> Reusable workflow extracted from rex-code-reviewer expertise.

## Purpose

Perform comprehensive code review with focus on quality, security, design patterns, and best practices to prevent bugs before merge.

## When to Use

- Pull request reviews before merge
- Code quality assessment for legacy code
- Security vulnerability identification
- Design pattern evaluation
- Pre-release code audits
- Technical debt quantification

## Workflow Steps

1. **Context Understanding**
   - Understand the purpose and scope of the code change
   - Review related issue/ticket context
   - Identify affected components and dependencies

2. **Architecture Review**
   - Verify alignment with overall system architecture
   - Check adherence to SOLID principles
   - Validate design pattern usage
   - Assess maintainability impact

3. **Logic & Security Review**
   - Validate business logic correctness
   - Check edge case handling
   - Scan for OWASP Top 10 vulnerabilities
   - Verify input validation and sanitization
   - Check authentication/authorization

4. **Performance & Quality Check**
   - Identify potential bottlenecks
   - Check algorithmic complexity
   - Verify database query optimization
   - Assess resource management

5. **Style & Standards**
   - Verify adherence to team coding standards
   - Check naming conventions
   - Validate documentation quality
   - Review test coverage adequacy

6. **Generate Feedback**
   - Categorize issues by severity (CRITICAL/HIGH/MEDIUM/SUGGESTION)
   - Provide file:line references
   - Include concrete fix recommendations
   - Acknowledge good patterns

## Inputs Required

- **Code to review**: Pull request diff, file paths, or commit range
- **Context**: Purpose of changes, related requirements
- **Standards**: Team coding standards, style guides
- **Scope**: Full review vs focused review (security, performance, etc.)

## Outputs Produced

- **Review Report**: Detailed findings by severity with file:line references
- **Security Issues**: Vulnerabilities flagged with severity levels
- **Pattern Assessment**: Design pattern usage evaluation
- **Refactoring Roadmap**: Prioritized improvements with effort estimates
- **Decision**: Approve / Request Changes / Comment

## Review Categories

### Severity Levels

- **🔴 CRITICAL**: Must fix before merge - security issues, data loss risks, breaking bugs
- **🟠 HIGH**: Should fix - significant maintainability or performance issues
- **🟡 MEDIUM**: Consider fixing - code smell, minor inefficiencies
- **🟢 SUGGESTION**: Nice to have - style improvements, minor optimizations
- **💡 LEARNING**: Educational - explaining why certain patterns are preferred

## Checklist Format

### Security Checklist

- [ ] No hardcoded secrets or credentials
- [ ] Input validation and sanitization present
- [ ] SQL injection prevention (parameterized queries)
- [ ] XSS prevention (output encoding)
- [ ] Authentication/authorization properly implemented
- [ ] Sensitive data encrypted at rest and in transit
- [ ] No security misconfigurations

### Quality Checklist

- [ ] Code without tests is incomplete - tests present
- [ ] Edge cases and error conditions handled
- [ ] No hardcoded values - configuration used
- [ ] Logging comprehensive with context
- [ ] No TO-DO/FIX-ME comments without tickets
- [ ] Documentation updated for public APIs
- [ ] No scope creep - focused on specific change

### Performance Checklist

- [ ] No N+1 query patterns
- [ ] Appropriate indexing for queries
- [ ] Efficient algorithms (check Big O)
- [ ] Proper connection pooling
- [ ] Caching strategy implemented where appropriate
- [ ] Resource cleanup (connections, files, memory)

## Example Usage

```
Input: Review pull request #123 adding user authentication

Workflow Execution:
1. Context: New OAuth2 implementation for user login
2. Architecture: Clean separation of auth logic, follows existing patterns
3. Security: ✅ Tokens stored securely, ❌ Missing rate limiting
4. Performance: ✅ Cached token validation
5. Standards: ✅ Tests present, ❌ Missing API documentation

Output:
🔴 CRITICAL: Add rate limiting to prevent brute force attacks
   File: src/auth/oauth.py:45
   Fix: Implement token bucket rate limiter with Redis

🟠 HIGH: Missing API documentation for new endpoints
   File: src/api/auth.py:12-67
   Fix: Add OpenAPI/Swagger documentation

🟢 APPROVE with changes required
```

## Related Agents

- **rex-code-reviewer** - Full agent with reasoning and adaptation
- **thor-quality-assurance-guardian** - Quality standards enforcement
- **luca-security-expert** - Deep security analysis
- **baccio-tech-architect** - Architecture pattern validation
- **dario-debugger** - Root cause analysis support

## ISE Engineering Fundamentals Alignment

- Every PR must be reviewed before merge
- Improve code quality by identifying defects early
- Foster learning through knowledge sharing
- Build shared understanding of codebase
- "Value quality and precision over completing fast"
