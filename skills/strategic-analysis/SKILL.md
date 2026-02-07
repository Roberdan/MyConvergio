# Strategic Analysis Skill

> Reusable workflow extracted from domik-mckinsey-strategic-decision-maker expertise.

## Purpose

Apply McKinsey-level strategic analysis using MECE frameworks, hypothesis-driven problem solving, and quantitative prioritization to drive transformational business decisions with executive-ready recommendations.

## When to Use

- Strategic initiative prioritization
- Business transformation planning
- Technology investment decisions
- Market entry/expansion strategy
- Digital transformation roadmaps
- M&A evaluation and due diligence
- Portfolio optimization
- Go/no-go decisions for major projects
- Executive decision support

## Workflow Steps

1. **Situation Assessment**
   - Define the strategic question clearly
   - Understand current state and context
   - Identify key stakeholders and their perspectives
   - Map competitive landscape
   - Gather relevant data and metrics
   - Document constraints and assumptions

2. **Issue Tree Construction (MECE)**
   - Break down the strategic question into components
   - Ensure Mutually Exclusive, Collectively Exhaustive structure
   - Create hypothesis-driven issue tree
   - Identify key decision drivers
   - Prioritize branches for deep dive analysis

3. **Hypothesis Formation**
   - Formulate testable hypotheses about the answer
   - Define what evidence would prove/disprove each
   - Create hypothesis tree with supporting logic
   - Identify critical assumptions
   - Plan data collection to test hypotheses

4. **Quantitative Analysis**
   - Gather data to test hypotheses
   - Apply ISE Prioritization Framework (if applicable)
   - Calculate financial impact (NPV, IRR, ROI)
   - Perform sensitivity analysis
   - Create scenario models (best/base/worst case)

5. **Qualitative Assessment**
   - Evaluate strategic fit with company vision
   - Assess organizational capability and readiness
   - Consider market timing and competitive dynamics
   - Evaluate execution risk and mitigation strategies
   - Assess stakeholder alignment

6. **Framework Application**
   - Apply relevant strategic frameworks:
     - Porter's Five Forces (competitive analysis)
     - 7S Framework (organizational alignment)
     - Three Horizons (innovation portfolio)
     - Value Chain Analysis (competitive advantage)
     - SWOT Analysis (strategic positioning)
   - Synthesize insights across frameworks

7. **Recommendation Development**
   - Synthesize analysis into clear recommendation
   - Create executive summary (three key messages)
   - Develop implementation roadmap
   - Identify quick wins and long-term plays
   - Define success metrics and KPIs

8. **Executive Communication**
   - Structure as situation-complication-question-answer
   - Lead with recommendation, support with analysis
   - Create visual "so what" slides
   - Prepare for objections and questions
   - Define clear next steps with ownership

## Inputs Required

- **Strategic Question**: Clear, specific decision to be made
- **Business Context**: Company strategy, market position, competitive landscape
- **Financial Data**: Revenue, costs, growth rates, market size
- **Organizational Context**: Capabilities, resources, constraints
- **Timeline**: Decision deadline, implementation window
- **Stakeholders**: Key decision-makers and their priorities

## Outputs Produced

- **Executive Summary**: Three key messages with recommendation
- **Strategic Analysis Report**: Detailed issue tree and hypothesis testing
- **Quantitative Models**: Financial projections, scenario analysis, ROI
- **Decision Framework Scorecards**: ISE or custom scoring with justification
- **Implementation Roadmap**: Phased plan with milestones and accountability
- **Risk Assessment**: Key risks with mitigation strategies
- **Presentation Deck**: Executive-ready slides for decision meeting

## MECE Framework Principles

Mutually Exclusive: No overlap, clear boundaries. Collectively Exhaustive: All possibilities covered.
Example: Market Entry? → 1) IS opportunity good? (size, competition, profit), 2) SHOULD we? (strategic fit, synergies, risk), 3) CAN we win? (advantage, capabilities, resources)

## ISE Prioritization Framework

Score 1-5 on six dimensions:
Customer Value (5=CxO-validated, 1=no impact) | Company Value (5=>$50M, 1=<$1M) | Ecosystem (5=blueprint, 0=not replicable)
Tech Innovation (5=transformational, 1=not novel) | Eng Time (5=<60d, 1=>1000d) | Time to Prod (5=≤2m, 1=>12m)

### Composite Score Calculation

```
Total Score = (Customer Value + Microsoft Value + Ecosystem Impact +
               Technical Innovation + Engineering Efficiency +
               Time to Production) / 6

Interpretation:
4.5-5.0: Strategic priority - immediate investment
3.5-4.4: Strong candidate - detailed planning
2.5-3.4: Conditional - requires optimization
1.5-2.4: Deferred - not currently strategic
<1.5: Decline - does not meet minimum criteria
```

## Executive Summary Template

Recommendation: [One sentence decision] | Three Messages: 1) [Why matters], 2) [Evidence], 3) [Meaning]
Rationale: [2-3 para why] | Impact: Financial/Strategic/Organizational
Roadmap: Phase 1 (1-3m), Phase 2 (4-6m), Phase 3 (7-12m) | Risks & Mitigation
Investment: $[amt], [FTE] people, [duration], [ROI%] | Metrics: [KPI targets] | Next: [Actions with owners/dates]

## Example Usage

Input: AI customer service platform? | Situation: $5M/year cost, 24h response, 3.2/5 satisfaction
Issue Tree: Opportunity (savings/CX/differentiation), Feasibility (AI/ML/data/integration), Business Case (cost/ROI/risk)
Hypothesis: 60% cost reduction, 4.5/5 satisfaction in 18m | Analysis: $2M dev, $3M/year savings, 8m payback, $12M 5y NPV
ISE Score: 4.0/5 (5+4+3+4+4+4/6) = STRONG PRIORITY | Porter's: AI = competitive moat
Output: ✅ RECOMMEND $2M investment, $3M annual savings, 150% ROI, kickoff Q2

## Strategic Frameworks

Porter's Five Forces: Entrants, Suppliers, Buyers, Substitutes, Rivalry
7S (McKinsey): Strategy, Structure, Systems, Shared Values, Style, Staff, Skills
Three Horizons: Core optimization (H1), Emerging opportunities (H2), Transformational bets (H3)
Value Chain: Primary (inbound/ops/outbound/marketing/service), Support (infra/HR/tech/procurement)
BCG Matrix: Stars, Cash Cows, Question Marks, Dogs

## Related Agents

- **domik-mckinsey-strategic-decision-maker** - Full agent with deep analysis
- **satya-board-of-directors** - System-thinking strategic guidance
- **antonio-strategy-expert** - Business strategy frameworks
- **amy-cfo** - Financial analysis and ROI modeling
- **ali-chief-of-staff** - Strategic initiative coordination

## Decision Quality Criteria

### Six Tests of a Good Decision

1. **Framing**: Right question being answered?
2. **Alternatives**: Multiple options considered?
3. **Information**: Reliable data gathered?
4. **Values**: Aligned with company values/strategy?
5. **Logic**: Sound reasoning and analysis?
6. **Commitment**: Stakeholders aligned and committed?

## ISE Engineering Fundamentals Alignment

- Architecture Decision Records (ADRs) for strategic tech decisions
- Trade studies before major investments
- Technical spikes for high-risk unknowns
- Data-driven decision making with metrics
- Iterative approach: pilot → scale → optimize
