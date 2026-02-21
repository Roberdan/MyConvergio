---
name: security-audit
description: OWASP-aligned security assessments with vulnerability analysis and remediation
allowed-tools:
  - Read
  - Glob
  - Grep
  - Bash
context: fork
user-invocable: true
version: "2.0.0"
---

# Security Audit Skill

> Reusable workflow extracted from luca-security-expert expertise.

Conduct comprehensive security assessments to identify vulnerabilities, assess risks, provide remediation aligned with OWASP, zero-trust, and compliance.

## When to Use

Pre-release validation | Post-incident review | Compliance prep (SOC2, ISO27001, GDPR) | Vendor assessment | Pentest planning | Architecture review | Incident response | Posture assessment

## Workflow

| Step | Actions |
|------|---------|
| **1. Scope** | Identify assets (apps, infra, data), boundaries, authorization, compliance (GDPR, HIPAA, PCI-DSS), timeline |
| **2. Info Gathering** | Map attack surface, inventory assets/tech, review architecture/data flows, existing docs, critical functions |
| **3. Threat Model** | Apply STRIDE (Spoofing, Tampering, Repudiation, Info Disclosure, DoS, Elevation), actors, attack vectors, prioritize |
| **4. Vulnerability Assessment** | OWASP Top 10, auth/authz, injection, session mgmt, crypto, API security, infrastructure, dependencies |
| **5. Risk Analysis** | Calculate risk (Likelihood × Impact), classify severity, business impact, compensating controls, prioritize |
| **6. Pentest** | Manual testing, automated scanning (Burp, ZAP), exploitation (controlled), privilege escalation, lateral movement |
| **7. Remediation** | Prioritized roadmap, fix recommendations, compensating controls, effort/timeline, validation criteria |
| **8. Report & Validate** | Document findings + evidence, executive summary, technical details, re-test after fixes, update baseline |

## Inputs

- Scope (systems, apps, infrastructure)
- Authorization (written permission)
- Access (test credentials, environment)
- Documentation (architecture, stack, security docs)
- Compliance (GDPR, HIPAA, PCI-DSS, etc.)
- Constraints (testing windows, off-limits)

## Outputs

- Security Assessment Report (findings + evidence)
- Risk Register (vulnerabilities by severity/impact)
- Remediation Roadmap (prioritized fixes + timeline)
- Executive Summary (high-level risk overview)
- Technical Details (exploitation + fix guidance)
- Compliance Gap Analysis

## OWASP Top 10

See [owasp-checklist.md](./owasp-checklist.md) for complete A01-A10 verification items.

## Risk Rating

| Severity | Likelihood × Impact | Action | Timeline |
|----------|---------------------|--------|----------|
| **Critical** | High + High | Data breach, system compromise | 24 hours |
| **High** | High + Med or Med + High | Significant security risk | 7 days |
| **Medium** | Med + Med or Low + High | Moderate security concern | 30 days |
| **Low** | Low + Low or Low + Med | Minor security issue | Next release |

**Risk Calculation**: Likelihood (Low/Med/High) × Impact (Low/Med/High/Critical) = Priority

## Example

```
Input: Pre-release audit for financial app

Steps:
1. Scope: Web + API + DB, PCI-DSS required
2. Info: React, Node.js, PostgreSQL, AWS
3. Threat Model: STRIDE → data exposure, injection risks
4. Vulnerabilities:
   🔴 CRITICAL: SQL injection in payment endpoint
   🔴 CRITICAL: JWT tokens never expire
   🟠 HIGH: Weak password (6 chars, no complexity)
   🟡 MEDIUM: Missing rate limiting
   🟢 LOW: Security headers not optimized
5. Risk: SQL injection = HIGH × CRITICAL = P0
6. Remediation:
   P0: Parameterized queries, token expiration (24h)
   P1: Password policy, rate limiting (7d)
   P2: Security headers (next sprint)
7. Report: Executive + technical + roadmap
8. Validate: Re-test after fixes

Output: BLOCKED - 2 critical fixes required first
```

## Security Tools

| Category | Tools |
|----------|-------|
| **Vulnerability Scanning** | OWASP ZAP, Burp Suite, Nmap, Nikto |
| **Code Analysis** | SonarQube, Snyk, Semgrep, GitHub CodeQL |
| **Infrastructure** | Trivy, Checkov, AWS Security Hub, Prowler |
| **Auth Testing** | Hydra, John the Ripper, Hashcat |

## Zero-Trust Principles

1. **Verify Explicitly**: Always authenticate/authorize
2. **Least Privilege**: Minimal permissions
3. **Assume Breach**: Design for compromise, limit blast radius
4. **Microsegmentation**: Isolate workloads/networks
5. **Continuous Monitoring**: Real-time threat detection

## Compliance Frameworks

| Framework | Focus | Key Requirements |
|-----------|-------|------------------|
| **GDPR** | Data Privacy | Protection by design/default, Right to erasure, 72h breach notification, Privacy impact assessments |
| **SOC2** | Security Controls | Security, availability, processing integrity, confidentiality, privacy, Annual audits |
| **ISO27001** | Info Security | 114 controls across 14 domains, Risk management, Continuous improvement |
| **PCI-DSS** | Payment Card | Secure network, Protect cardholder data, Vulnerability mgmt, Monitoring/testing |

## Related Agents

- **luca-security-expert** - Full reasoning and threat analysis
- **rex-code-reviewer** - Code-level security review
- **baccio-tech-architect** - Security architecture validation
- **marco-devops-engineer** - Infrastructure security
- **elena-legal-compliance-expert** - Regulatory compliance

## Engineering Fundamentals

- Threat modeling (STRIDE/DREAD) for all features
- Static/dynamic security testing in CI/CD
- Shift-left security: early pipeline checks
- Dependency scanning automated
- Container security: image scanning, runtime protection
- Secret management: vault-based, no secrets in code
- Security code review checklist for every PR
