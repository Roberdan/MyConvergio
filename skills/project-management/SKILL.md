# Project Management Skill

> Reusable workflow extracted from davide-project-manager expertise.

## Purpose

Execute comprehensive project planning, tracking, and delivery using proven methodologies (Agile, Waterfall, Hybrid) to ensure on-time, on-budget delivery while maintaining quality and stakeholder satisfaction.

## When to Use

- New project initiation and planning
- Sprint planning for Agile teams
- Waterfall project execution
- Risk management and mitigation
- Stakeholder communication and reporting
- Resource allocation and optimization
- Budget management and cost control
- Project status assessment
- Project closure and retrospectives

## Workflow Steps

1. **Project Initiation**
   - Define project objectives and success criteria
   - Identify key stakeholders and their roles
   - Establish project scope and boundaries
   - Document constraints (time, budget, resources)
   - Obtain project charter approval
   - Set up project infrastructure (tools, repositories)

2. **Work Breakdown Structure (WBS)**
   - Decompose project into phases and deliverables
   - Break deliverables into tasks and subtasks
   - Identify dependencies between tasks
   - Estimate effort for each task (hours/days)
   - Assign task owners and backup resources
   - Define acceptance criteria for each deliverable

3. **Schedule Development**
   - Create project timeline with milestones
   - Identify critical path using CPM
   - Build Gantt chart with dependencies
   - Calculate float/slack time
   - Define sprint cadence (if Agile)
   - Set milestone dates and review points

4. **Resource Planning**
   - Identify required skills and roles
   - Allocate team members to tasks
   - Calculate resource utilization (avoid >80%)
   - Plan for peak resource needs
   - Identify skill gaps and training needs
   - Arrange for external resources if needed

5. **Risk Management**
   - Identify potential risks (technical, schedule, resource, external)
   - Assess likelihood and impact for each risk
   - Calculate risk scores (Likelihood × Impact)
   - Develop mitigation strategies
   - Assign risk owners
   - Create contingency plans
   - Monitor risk triggers

6. **Budget Management**
   - Estimate project costs (labor, tools, infrastructure)
   - Create detailed budget breakdown
   - Establish cost baseline
   - Track actual vs planned spending
   - Forecast final costs regularly
   - Manage change requests with budget impact

7. **Execution & Monitoring**
   - Conduct daily standups (Agile) or weekly status meetings
   - Track task completion and update progress
   - Monitor schedule adherence (earned value analysis)
   - Review and approve deliverables
   - Manage scope changes through change control
   - Remove blockers and impediments
   - Facilitate team collaboration

8. **Stakeholder Communication**
   - Create communication plan (who, what, when, how)
   - Send regular status reports (weekly/bi-weekly)
   - Conduct stakeholder review meetings
   - Escalate issues and risks appropriately
   - Manage expectations proactively
   - Celebrate milestones and wins

9. **Quality Management**
   - Define quality standards and acceptance criteria
   - Implement quality gates at milestones
   - Conduct code reviews and testing
   - Track defects and resolution rates
   - Ensure documentation completeness
   - Validate deliverables against requirements

10. **Project Closure**
    - Verify all deliverables completed and accepted
    - Conduct project retrospective (lessons learned)
    - Document successes and improvement areas
    - Release resources and close contracts
    - Archive project documentation
    - Celebrate team success
    - Create project closure report

## Inputs Required

- **Project requirements**: Goals, scope, success criteria
- **Stakeholders**: Sponsor, product owner, team members, customers
- **Constraints**: Budget, timeline, resource availability
- **Methodology**: Agile, Waterfall, or Hybrid approach
- **Tools**: Project management software (Jira, Trello, MS Project)

## Outputs Produced

- **Project Charter**: Objectives, scope, stakeholders, success criteria
- **Project Plan**: WBS, schedule, budget, resource allocation
- **Risk Register**: Risks with likelihood, impact, mitigation strategies
- **Status Reports**: Weekly/bi-weekly progress updates
- **Gantt Chart**: Visual timeline with dependencies and milestones
- **Budget Tracking**: Actual vs planned spending, forecast
- **Retrospective Report**: Lessons learned, improvements for next project

## Sprint Planning Template (Agile)

Sprint {N}: {Goal} | Capacity: {count} devs × {weeks}w = {hours}h @ 80% = {planned}h
Stories: US-{id} ({points}SP, {owner}) | DoD: Code+Tests+Docs+Staging+PO approval
Risks: {risk} → Mitigation: {strategy} | Ceremonies: Daily 9AM, Review/Retro {dates}

## Risk Assessment Matrix

Risk Score = Likelihood (1-5) × Impact (1-5)
Likelihood: 1=<10%, 2=10-30%, 3=30-50%, 4=50-70%, 5=>70%
Impact: 1=<1d/<$1K, 2=1-3d/<$5K, 3=1w/<$20K, 4=2-4w/<$50K, 5=>1m/>$50K
Priority: Critical(20-25)=immediate, High(15-19)=7d, Medium(8-14)=30d, Low(1-7)=accept

## Status Report Template

Status: {🟢/🟡/🔴} | Highlights: {accomplishments} | Completed: {count} tasks ({%})
Milestones: {name} {planned} → {forecast} {status} | Budget: ${spent}K/${total}K ({%})
Top Risks: {risk} - Impact: {impact}, Mitigation: {strategy}
Decisions Needed: {decision by date} | Next Focus: {objectives}

## Example Usage

```
Input: Plan new e-commerce feature launch - payment integration

Workflow Execution:
1. Initiation:
   - Goal: Integrate Stripe payment in checkout flow
   - Stakeholders: Product, Engineering, Finance, Legal
   - Success: Process payments with <1% failure rate
   - Timeline: 8 weeks
   - Budget: $80K

2. WBS:
   - Phase 1: Design (1 week)
     - Payment flow UX design
     - Security architecture review
   - Phase 2: Development (4 weeks)
     - Backend API integration
     - Frontend checkout UI
     - Payment validation
   - Phase 3: Testing (2 weeks)
     - Unit and integration tests
     - PCI-DSS compliance validation
   - Phase 4: Deployment (1 week)
     - Staged rollout to 10%/50%/100%

3. Schedule:
   - Critical path: Backend API → Frontend → Testing
   - Milestones: Design review (week 1), Dev complete (week 5)
   - Sprint cadence: 2-week sprints

4. Resources:
   - 2 backend devs, 1 frontend dev, 1 QA
   - Security consultant (week 2-3)
   - 80% capacity = 128 hours/sprint

5. Risks:
   - 🔴 HIGH (Score: 16): Stripe API changes during integration
     - Mitigation: Use stable API version, monitor changelog
   - 🟡 MEDIUM (Score: 9): PCI compliance gaps found
     - Mitigation: Early security review, buffer time

6. Budget:
   - Labor: $60K (4 devs × 8 weeks)
   - Tools: $5K (Stripe fees, testing)
   - Security audit: $10K
   - Contingency: $5K (6%)

7. Execution:
   - Daily standups at 9 AM
   - Weekly stakeholder demo on Fridays
   - Bi-weekly sprint planning

8. Communication:
   - Weekly status email to stakeholders
   - Slack channel for real-time updates
   - Monthly steering committee presentation

9. Quality:
   - Code review required for all PRs
   - >80% test coverage required
   - Security scan before each deployment

10. Closure:
    - All deliverables met, launched to 100% users
    - Retrospective: Payment failures 0.3% (beat 1% target)
    - Lesson: Early security review prevented late delays

Output:
✅ Project delivered ON TIME, ON BUDGET
Timeline: 8 weeks (as planned)
Budget: $78K spent ($80K budget, 2.5% under)
Quality: 0.3% payment failure rate (target: <1%)
Stakeholder satisfaction: 4.8/5.0
```

## Resource Allocation Guidelines

### Optimal Utilization Levels

- **70-80%**: Ideal - allows for slack, meetings, emergencies
- **80-90%**: High - sustainable for short periods only
- **90-100%**: Overutilized - risk of burnout, quality issues
- **>100%**: Critical - immediate intervention required

### Load Balancing Strategies

- Cross-train team members for flexibility
- Maintain 20% buffer for unplanned work
- Balance workload across sprints
- Plan for PTO and holidays
- Avoid single points of failure

## Change Request Process

```markdown
# Change Request: {ID}

## Requested By

{Name}, {Date}

## Description

{What is the requested change?}

## Justification

{Why is this change needed?}

## Impact Analysis

- **Scope**: {How does this affect deliverables?}
- **Schedule**: {Delay in days/weeks}
- **Budget**: {Additional cost}
- **Resources**: {Additional people/skills needed}
- **Quality**: {Impact on quality/testing}
- **Risk**: {New risks introduced}

## Decision

☐ Approved - {Reason}
☐ Rejected - {Reason}
☐ Deferred - {To when and why}

## Approval

- Project Sponsor: {Name}, {Date}
- Product Owner: {Name}, {Date}
```

## Related Agents

- **davide-project-manager** - Full agent with reasoning and adaptation
- **luke-program-manager** - Multi-project portfolio management
- **ali-chief-of-staff** - Cross-functional coordination
- **thor-quality-assurance-guardian** - Quality standards
- **enrico-business-process-engineer** - Process optimization

## ISE Engineering Fundamentals Alignment

- Value quality and precision over speed
- Ship incremental value in small chunks
- Collective code ownership - everyone can contribute
- Every PR reviewed before merge
- Code without tests is incomplete
- Comprehensive logging for debugging
- Blameless post-mortems for continuous improvement
