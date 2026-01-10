---
name: ali-parallel-patterns
description: Parallel execution patterns and agent groups for ali-chief-of-staff. Reference module.
version: "2.0.0"
---

# Advanced Orchestration Protocols

## Parallel Execution Patterns

### When to Use Parallel Execution
Use parallel agent invocation when tasks are **independent**:
- Independent analysis of different aspects
- Gathering diverse perspectives concurrently
- Time-critical decisions needing rapid insights
- Comprehensive reviews (code, security, performance)

### How to Invoke Multiple Agents in Parallel
```markdown
# Example: Parallel Technical Review
@Task("Get code review from Rex", agent="rex-code-reviewer")
@Task("Security audit from Luca", agent="luca-security-expert")
@Task("Performance analysis from Otto", agent="otto-performance-optimizer")
```

**Benefits:**
- **3x Faster**: Complete analysis in 1/3 the time
- **Independent Insights**: Unbiased perspectives
- **Comprehensive Coverage**: All aspects simultaneously

### When NOT to Use Parallel Execution
Avoid when tasks have **dependencies**:
- Sequential workflows (A feeds B)
- Iterative refinement
- Complex orchestration with intermediate decisions

---

## Agent Groups for Parallel Invocation

### Technical Review Team
**Use Case**: Code review, security audit, performance optimization
- **rex-code-reviewer**: Code quality, patterns
- **luca-security-expert**: Security vulnerabilities, OWASP
- **otto-performance-optimizer**: Performance profiling
- **paolo-best-practices-enforcer**: Standards, consistency

### Strategic Analysis Team
**Use Case**: Strategic decisions, market analysis
- **domik-mckinsey**: ISE framework, executive decisions
- **antonio-strategy-expert**: OKR, Lean, SWOT
- **matteo-strategic-business-architect**: Business strategy
- **amy-cfo**: Financial strategy, ROI

### Project Management Team
**Use Case**: Project planning, process optimization
- **davide-project-manager**: Project planning
- **luke-program-manager**: Portfolio, agile delivery
- **marcello-pm**: Execution, timelines
- **enrico-business-process-engineer**: Process design

### Architecture & Infrastructure Team
**Use Case**: System architecture, DevOps strategy
- **baccio-tech-architect**: System design
- **marco-devops-engineer**: CI/CD, IaC
- **dan-engineering-gm**: Technical strategy

### Customer & Market Team
**Use Case**: Marketing, customer success
- **sofia-marketing-strategist**: Digital marketing
- **andrea-customer-success-manager**: Customer lifecycle
- **fiona-market-analyst**: Financial markets
- **fabio-sales-business-development**: Revenue, partnerships

### Data & Analytics Team
**Use Case**: Data analysis, predictive modeling
- **omri-data-scientist**: ML, statistical analysis
- **angela-da**: Business impact analysis
- **ava-analytics-insights-virtuoso**: Pattern recognition

### Design & UX Team
**Use Case**: Product design, user research
- **sara-ux-ui-designer**: User-centered design
- **jony-creative-director**: Creative strategy
- **stefano-design-thinking-facilitator**: Design workshops

### Compliance & Legal Team
**Use Case**: Legal review, security validation
- **elena-legal-compliance-expert**: Legal guidance
- **luca-security-expert**: Security threats
- **dr-enzo-healthcare-compliance-manager**: Healthcare compliance

---

## RACI-Based Agent Coordination

1. **Challenge Assessment**: Analyze complexity, determine agent combinations
2. **Agent Selection**: Deploy based on RACI matrix and expertise
3. **Coordination Planning**: Coordinate with clear R-A-C-I roles
4. **Integration Framework**: Synthesize contributions
5. **Quality Assurance**: Validate through Thor and domain experts
6. **Executive Synthesis**: Deliver integrated solutions

---

## Specialized Orchestration Scenarios

### Complex Strategic Initiatives
**Example**: "Launch global software platform"
- **Strategic Decision**: Domik(R), Satya(A), Matteo(C), Amy(C)
- **Technology**: Baccio(R), Dan(A), Marco(C), Luca(C)
- **Market**: Sofia(R), Fabio(A), Andrea(C), Sam(C)
- **Execution**: Luke(R), Davide(A), Enrico(C), Thor(C)
- **Integration**: Ali coordinates all tiers

### Product Development & Innovation
**Example**: "Design AI-powered customer platform"
- **Design**: Sara(R), Jony(A), Stefano(C), Jenny(C)
- **Technology**: Dan(R), Baccio(A), Marco(C), Po(C)
- **User Research**: Omri(R), Sara(A), Behice(C)
- **Strategy**: Antonio(R), Matteo(A), Domik(C)

### Organizational Transformation
**Example**: "Scale remote-first culture 10x"
- **Culture**: Behice(R), Giulia(A), Coach(C), Jenny(C)
- **Talent**: Giulia(R), Coach(A), Behice(C), Dan(C)
- **Process**: Enrico(R), Luke(A), Marco(C), Thor(C)
- **Communication**: Steve(R), Riccardo(A), Sofia(C)

### Crisis Management
**Example**: "Security incident with media attention"
- **Security**: Luca(R), Dan(A), Marco(C), Elena(C)
- **Legal**: Elena(R), Ali(A), Luca(C), Amy(C)
- **Communication**: Steve(R), Riccardo(A), Sofia(C)
- **Customer**: Andrea(R), Fabio(A), Coach(C)

---

## Changelog

- **2.0.0** (2026-01-10): Extracted from ali-chief-of-staff.md for modularity
