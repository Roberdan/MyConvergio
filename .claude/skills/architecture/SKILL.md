---
name: architecture
description: Design scalable system architectures using DDD, Clean Architecture, cloud-native patterns
allowed-tools:
  - Read
  - Glob
  - Grep
  - WebSearch
context: fork
user-invocable: true
version: "2.0.0"
---

# Architecture Design Skill

> Reusable workflow extracted from baccio-tech-architect expertise.

Design scalable, maintainable, secure system architectures using DDD, Clean Architecture, cloud-native patterns.

## When to Use

New system design | Legacy modernization | Stack selection | Scalability planning | Microservices design | Cloud migration | Debt evaluation | Architecture review

## Workflow

| Step | Actions |
|------|---------|
| **1. Requirements** | Gather functional/NFRs, constraints (budget, timeline, team), scale (users, data, traffic), compliance |
| **2. Domain Model** | Apply DDD: bounded contexts, aggregates, entities, ubiquitous language |
| **3. Pattern Selection** | Choose style (monolith/microservices/serverless), patterns (CQRS, Event Sourcing, Saga), Clean Architecture |
| **4. Tech Stack** | Evaluate options vs requirements, team expertise, vendor lock-in, cost, compliance |
| **5. Scalability** | Horizontal/vertical scaling, caching (app/CDN/DB), load balancing, sharding, geo-distribution |
| **6. Security** | Zero-Trust, auth/authz, encryption (at-rest/in-transit), boundaries, defense-in-depth |
| **7. Observability** | Structured logging, metrics (Prometheus, CloudWatch), tracing, dashboards, alerts |
| **8. Documentation** | ADRs, C4 diagrams, API contracts/versioning, deployment architecture, capacity planning |

## Inputs

- Business requirements (problem to solve)
- NFRs (performance, security, compliance)
- Scale (current/projected users, data, traffic)
- Constraints (budget, timeline, team skills, existing systems)
- Compliance (GDPR, HIPAA, SOC2, etc.)

## Outputs

- Architecture Blueprint
- ADRs (decision records with rationale)
- Tech Stack Recommendation
- Scalability Plan
- Security Architecture
- Deployment Diagrams
- Migration Roadmap

## Architecture Patterns

### Styles

| Pattern | Traits |
|---------|--------|
| Monolithic | Single deployable, simpler, less scalable |
| Microservices | Independent services, complex, highly scalable |
| Serverless | Event-driven, pay-per-use, elastic |
| Modular Monolith | Compromise between monolith and microservices |
| SOA | Enterprise service bus |

### Design Patterns

| Pattern | Use Case |
|---------|----------|
| DDD | Bounded contexts, aggregates, entities |
| Clean Architecture | Dependency inversion, layers, boundaries |
| CQRS | Command Query Responsibility Segregation |
| Event Sourcing | Event log as source of truth |
| Saga | Distributed transactions |
| API Gateway | Single entry point |
| BFF | Backend for Frontend (API per client) |

### Communication

- **Sync**: REST, GraphQL, gRPC
- **Async**: Kafka, RabbitMQ, SQS
- **Pub/Sub**: Event-driven
- **RPC**: Request-Reply

## ADR Template

```markdown
## Decision: [Technology/Pattern]

### Context
[Problem, constraints]

### Options
1. **Option A**: [Pros/Cons/Cost]
2. **Option B**: [Pros/Cons/Cost]

### Decision
[Choice with rationale]

### Consequences
- Positive: [Benefits]
- Negative: [Drawbacks]
- Mitigation: [Actions]
```

## NFR Checklist

See [nfr-checklist.md](./nfr-checklist.md) for performance, availability, security, observability, maintainability requirements.

## Example

```
Input: E-commerce platform, 10K users, 99.9% uptime, PCI DSS

Steps:
1. Requirements: User accounts, catalog, cart, checkout
2. Domain: User, Product, Cart, Order contexts
3. Pattern: Microservices + API Gateway + Event-driven
4. Stack: Node.js, PostgreSQL, Redis, Kafka, AWS ECS/RDS
5. Scale: Horizontal (ECS), read replicas, CDN
6. Security: OAuth2+JWT, PCI gateway, encryption
7. Observability: CloudWatch, X-Ray, Grafana
8. Docs: ADRs, C4 diagrams, API specs

Output: Blueprint + ADRs + diagrams
```

## Tech Stack Evaluation

| Criterion | Weight | Option A | Option B | Option C |
|-----------|--------|----------|----------|----------|
| Team expertise | 20% | 8/10 | 5/10 | 6/10 |
| Scalability | 25% | 9/10 | 7/10 | 8/10 |
| Cost | 15% | 6/10 | 9/10 | 7/10 |
| Community | 10% | 9/10 | 8/10 | 6/10 |
| Compliance | 15% | 8/10 | 7/10 | 9/10 |
| Lock-in | 15% | 7/10 | 5/10 | 8/10 |
| **Total** | 100% | **7.9** | **6.9** | **7.5** |

## Related Agents

- **baccio-tech-architect** - Full reasoning/decision-making
- **luca-security-expert** - Security validation
- **dan-engineering-gm** - Leadership alignment
- **marco-devops-engineer** - Infrastructure/deployment
- **domik-mckinsey-strategic-decision-maker** - Strategic decisions

## Engineering Fundamentals

- Document ADRs for all major decisions
- Apply proven design patterns
- Trade studies before decisions
- Technical spikes for high-risk unknowns
- Design for NFRs from day one
- Infrastructure as Code
- GitOps workflows
