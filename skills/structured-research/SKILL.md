# Structured Research & Information Gathering

**Capability:** Systematic research and information synthesis across multiple sources with hypothesis-driven approach.

**Based on:** Anthropic Best Practices for Research and Information Gathering

---

## Core Principles

Claude demonstrates exceptional agentic search capabilities and can find and synthesize information from multiple sources effectively. This skill provides a structured framework for complex research tasks.

## When to Use

- Complex research questions requiring multiple sources
- Information synthesis across large corpora
- Hypothesis validation tasks
- Competitive analysis or market research
- Technical deep-dives requiring source verification
- Any research where confidence calibration matters

## Methodology

### 1. Define Success Criteria

Before starting research, establish:

- What constitutes a successful answer?
- What level of confidence is required?
- What sources are authoritative?
- What contradictions need resolution?

### 2. Structured Research Approach

<structured_research_protocol>
Search for information in a structured way:

1. **Develop competing hypotheses**
   - Generate 2-4 initial hypotheses about the answer
   - Don't commit to one hypothesis too early
   - Track evidence for and against each

2. **Track confidence levels**
   - Assign confidence scores (0-100%) to each hypothesis
   - Update confidence as you gather evidence
   - Document reasoning for confidence changes
   - Improve calibration through self-critique

3. **Maintain research state**
   - Create/update `research-notes.md` with findings
   - Use `hypothesis-tree.json` for structured hypothesis tracking
   - Provide transparency into research progress

4. **Iterative self-critique**
   - Regularly critique your approach
   - Ask: "Am I searching the right places?"
   - Ask: "What assumptions am I making?"
   - Ask: "What contradictory evidence am I missing?"

5. **Source verification**
   - Verify information across multiple independent sources
   - Check source authority and recency
   - Note when sources conflict
   - Prefer primary sources over secondary
     </structured_research_protocol>

### 3. Research State Files

**hypothesis-tree.json**: {question, hypotheses:[{id, statement, confidence%, evidence_for[], evidence_against[], sources[]}], contradictions[], open_questions[], last_updated}

**research-notes.md**: Session date → Search strategy → Key findings (source citations) → Confidence evolution with reasons → Next steps

## Research Workflow

### Phase 1: Setup (5-10%)

1. Define research question clearly
2. Establish success criteria
3. Generate initial hypotheses (2-4)
4. Identify key sources to check

### Phase 2: Initial Sweep (20-30%)

1. Search official documentation
2. Check authoritative sources
3. Build initial hypothesis confidence
4. Note contradictions and gaps

### Phase 3: Deep Dive (40-50%)

1. Investigate contradictions
2. Verify claims across sources
3. Update hypothesis confidence
4. Self-critique: "Am I missing something?"

### Phase 4: Synthesis (20-30%)

1. Resolve contradictions if possible
2. Document unresolved questions
3. Provide final answer with confidence level
4. List key sources and reasoning

## Quality Checklist

Before completing research:

- [ ] Multiple independent sources checked (minimum 3)
- [ ] Contradictions identified and investigated
- [ ] Confidence levels calibrated (not just 0% or 100%)
- [ ] Primary sources cited where possible
- [ ] Source recency verified (especially for technical topics)
- [ ] Competing hypotheses considered
- [ ] Self-critique performed: "What could I be wrong about?"
- [ ] Open questions documented
- [ ] Research state saved for future reference

## Examples

**Technical Decision**: REST vs GraphQL? → H1: REST (60%), H2: GraphQL (40%) → Research benchmarks/DX/tooling/use-case → Final: 70% REST (simple CRUD favors it), 30% GraphQL (better for complex queries)

**Market Research**: Top 3 competitors? → Initial list from reports/market-cap/social → Validate via reviews/features/growth → Cross-ref firms/analysis/surveys → Result: Top 3 ranked with confidence + emerging threats

## Anti-Patterns

Avoid: First hypothesis bias, single source reliance, ignoring contradictions, false certainty (100%), skipping self-critique, undocumented state
Do: Multiple hypotheses, independent source verification, iterative confidence updates, document reasoning/gaps, regular self-critique, transparent state

## Integration with Other Skills

**Works well with:**

- **Strategic Analysis:** Use for competitive research
- **Architecture:** Validate technology choices
- **Code Review:** Research best practices
- **Performance:** Benchmark validation

## Advanced Techniques

Hypothesis Tree: Start 2-4 top-level → branch sub-hypotheses → prune low-confidence early
Confidence: Track predictions vs outcomes, Bayesian updating
Source Ranking: Primary>Secondary>Tertiary | Recent>Older | Official>Independent>Anecdotal | Quantitative>Qualitative

---

**Remember:** The goal is not just to find AN answer, but to find the RIGHT answer with appropriate confidence and transparency about uncertainty.
