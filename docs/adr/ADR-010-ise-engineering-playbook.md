# ADR-010: ISE Engineering Playbook as Standard

| Field | Value |
|-------|-------|
| **Status** | Accepted |
| **Date** | 2025-12-15 |
| **Deciders** | Roberto, AI Team |

## Context

Microsoft's ISE (Industry Solutions Engineering) team maintains the Engineering Fundamentals Playbook, a comprehensive guide for building enterprise solutions. This playbook covers best practices for:

- Software Engineering
- Architecture & Design
- Data Science & ML
- DevOps & CI/CD
- Security & Compliance
- Testing & Quality
- Responsible AI

## Decision

All technical agents must be experts in and follow the ISE Engineering Playbook:
- **Reference**: https://microsoft.github.io/code-with-engineering-playbook/
- **GitHub**: https://github.com/microsoft/code-with-engineering-playbook

## Applicable Agents

- `baccio-tech-architect` - Architecture patterns
- `marco-devops-engineer` - CI/CD and DevOps
- `rex-code-reviewer` - Code review standards
- `otto-performance-optimizer` - Performance engineering
- `omri-data-scientist` - ML/DS practices
- `paolo-best-practices-enforcer` - Engineering standards
- `dario-debugger` - Debugging methodology
- `dan-engineering-gm` - Engineering leadership
- `luca-security-expert` - Security practices

## Key Playbook Sections

1. **Fundamentals**
   - Design Reviews
   - Code Reviews
   - Testing
   - Documentation

2. **Engineering Process**
   - Agile Development
   - Sprint Planning
   - Retrospectives

3. **Architecture**
   - Microservices
   - Event-Driven
   - API Design

4. **DevOps**
   - CI/CD Pipelines
   - Infrastructure as Code
   - Observability

5. **Security**
   - Threat Modeling
   - Secure Development
   - Compliance

6. **Responsible AI**
   - Fairness
   - Reliability
   - Privacy
   - Inclusiveness
   - Transparency
   - Accountability

## Rationale

1. Industry-proven enterprise patterns
2. Comprehensive coverage of engineering practices
3. Aligns with Microsoft values and responsible AI principles
4. Living documentation that evolves with best practices

## Consequences

**Positive:**
- Consistent engineering standards
- Enterprise-grade solutions
- Responsible AI built-in

**Negative:**
- Additional knowledge requirement for agents
- Must stay updated with playbook changes

## Implementation

Added ISE Engineering Playbook reference to all technical agents with:
- Link to playbook
- Key principles summary
- Instruction to follow playbook patterns
