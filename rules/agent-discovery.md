# Agent Discovery

> Dynamic routing to MyConvergio specialist agents when available.

**Last Updated**: 3 Gennaio 2026, 19:15 CET

---

## Source Priority

1. **MyConvergio specialists** (`/Users/roberdan/GitHub/MyConvergio/agents/`) - Domain experts
2. **Local agents** (`~/.claude/agents/`) - Default fallback

---

## Domain Catalog

### Marketing & Growth

| Agent | Expertise | Keywords |
|-------|-----------|----------|
| `sofia-marketing-strategist` | Digital marketing, brand strategy, growth hacking | marketing, campaign, brand, growth, content |
| `fabio-sales-business-development` | Sales, partnerships, deal negotiation | sales, revenue, partnership, deal, B2B |
| `fiona-market-analyst` | Market research, competitive analysis | market, competitor, research, analysis |
| `riccardo-storyteller` | Narrative, content creation | story, narrative, content, copywriting |
| `steve-executive-communication-strategist` | Executive comms, presentations | communication, presentation, executive |

### Leadership & Strategy

| Agent | Expertise | Keywords |
|-------|-----------|----------|
| `ali-chief-of-staff` | Executive operations, strategic alignment | CoS, executive, alignment, operations |
| `amy-cfo` | Finance, budgeting, financial strategy | finance, budget, CFO, investment, ROI |
| `antonio-strategy-expert` | Corporate strategy, competitive positioning | strategy, competitive, positioning |
| `dan-engineering-gm` | Engineering leadership, tech org | engineering manager, tech lead, org |
| `domik-mckinsey-strategic-decision-maker` | Strategic decisions, McKinsey frameworks | decision, framework, McKinsey, consulting |
| `matteo-strategic-business-architect` | Business architecture, operating model | business architecture, operating model |
| `satya-board-of-directors` | Board-level decisions, governance | board, governance, shareholder |

### Technical Development

| Agent | Expertise | Keywords |
|-------|-----------|----------|
| `baccio-tech-architect` | System design, architecture | architecture, system design, microservices |
| `dario-debugger` | Debugging, root cause analysis | debug, bug, troubleshoot, error |
| `marco-devops-engineer` | CI/CD, infrastructure, deployment | devops, CI/CD, infrastructure, deploy |
| `otto-performance-optimizer` | Performance tuning, profiling | performance, optimize, profiling, latency |
| `paolo-best-practices-enforcer` | Coding standards, best practices | standards, best practices, lint, quality |
| `rex-code-reviewer` | Code review, design patterns | review, code quality, patterns |
| `luca-security-expert` | Security, vulnerabilities, OWASP | security, vulnerability, OWASP, pentest |
| `omri-data-scientist` | ML, data science, analytics | ML, data science, model, analytics |

### Data & Analytics

| Agent | Expertise | Keywords |
|-------|-----------|----------|
| `angela-da` | Data analysis | data analysis, metrics |
| `ava-analytics-insights-virtuoso` | Analytics, insights, dashboards | analytics, insights, dashboard, KPI |
| `ethan-da` | Data analysis | data, analysis |
| `evan-ic6da` | IC6 data analysis | IC6, data |

### Design & UX

| Agent | Expertise | Keywords |
|-------|-----------|----------|
| `jony-creative-director` | Creative direction, visual design | creative, design, visual, brand |
| `sara-ux-ui-designer` | UX/UI design, user research | UX, UI, user experience, wireframe |
| `stefano-design-thinking-facilitator` | Design thinking, workshops | design thinking, workshop, ideation |
| `jenny-inclusive-accessibility-champion` | Accessibility, WCAG, inclusive design | accessibility, WCAG, a11y, inclusive |

### Project & Program Management

| Agent | Expertise | Keywords |
|-------|-----------|----------|
| `davide-project-manager` | Project management, planning | project, planning, timeline, milestone |
| `luke-program-manager` | Program management, portfolio | program, portfolio, roadmap |
| `marcello-pm` | Product management | product, PM, roadmap, backlog |
| `oliver-pm` | Product management | product, features, requirements |
| `wanda-workflow-orchestrator` | Workflow, process automation | workflow, orchestration, automation |

### HR & Culture

| Agent | Expertise | Keywords |
|-------|-----------|----------|
| `giulia-hr-talent-acquisition` | HR, recruiting, talent | HR, recruiting, talent, hiring |
| `behice-cultural-coach` | Culture, team dynamics | culture, team, coaching |
| `coach-team-coach` | Team coaching, performance | coaching, team performance |

### Legal & Compliance

| Agent | Expertise | Keywords |
|-------|-----------|----------|
| `elena-legal-compliance-expert` | Legal, regulatory compliance | legal, compliance, regulation, contract |
| `dr-enzo-healthcare-compliance-manager` | Healthcare compliance, HIPAA | healthcare, HIPAA, medical, compliance |
| `sophia-govaffairs` | Government affairs, policy | government, policy, regulation, lobby |
| `guardian-ai-security-validator` | AI security, validation | AI security, validation, safety |

### Investment & Startups

| Agent | Expertise | Keywords |
|-------|-----------|----------|
| `michael-vc` | Venture capital, funding | VC, funding, investment, startup |
| `wiz-investor-venture-capital` | Investment analysis | investment, valuation, due diligence |
| `sam-startupper` | Startup strategy, MVP | startup, MVP, lean, pivot |

### Operations & Process

| Agent | Expertise | Keywords |
|-------|-----------|----------|
| `andrea-customer-success-manager` | Customer success, retention | customer success, retention, churn |
| `anna-executive-assistant` | Executive support, scheduling | assistant, scheduling, coordination |
| `dave-change-management-specialist` | Change management, transformation | change, transformation, adoption |
| `enrico-business-process-engineer` | Process optimization, BPM | process, BPM, optimization, workflow |

### Core Utility

| Agent | Expertise | Keywords |
|-------|-----------|----------|
| `socrates-first-principles-reasoning` | First principles, reasoning | reasoning, first principles, logic |
| `strategic-planner` | Strategic planning | planning, strategy, roadmap |
| `thor-quality-assurance-guardian` | Quality assurance, validation | QA, quality, validation, testing |
| `marcus-context-memory-keeper` | Context management | context, memory, history |
| `po-prompt-optimizer` | Prompt optimization | prompt, optimization |

---

## Routing Logic

```
1. Extract keywords from task description
2. Match keywords to domain catalog
3. If match found → Use MyConvergio specialist
4. If no match → Use ~/.claude default agent
5. If ambiguous → Ask user to clarify domain
```

---

## Skills Available

Path: `/Users/roberdan/GitHub/MyConvergio/skills/`

| Skill | Domain |
|-------|--------|
| architecture | System design |
| code-review | Code quality |
| debugging | Troubleshooting |
| orchestration | Workflow management |
| performance | Optimization |
| project-management | PM |
| release-management | Releases |
| security-audit | Security |
| strategic-analysis | Strategy |
