# Structured Research & Information Gathering

**Capability:** Systematic research and information synthesis across multiple sources with hypothesis-driven approach.

**Based on:** Anthropic Claude 4.5 Best Practices for Research and Information Gathering

---

## Core Principles

Claude 4.5 demonstrates exceptional agentic search capabilities and can find and synthesize information from multiple sources effectively. This skill provides a structured framework for complex research tasks.

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

**hypothesis-tree.json** (Structured):
```json
{
  "research_question": "What is the best approach for X?",
  "hypotheses": [
    {
      "id": 1,
      "statement": "Approach A is optimal",
      "confidence": 65,
      "evidence_for": [
        "Source 1: Performance benchmarks show 2x improvement",
        "Source 2: Industry standard in 2025"
      ],
      "evidence_against": [
        "Source 3: High complexity cost",
        "Source 4: Limited tool support"
      ],
      "sources": ["url1", "url2", "url3", "url4"]
    },
    {
      "id": 2,
      "statement": "Approach B is optimal",
      "confidence": 35,
      "evidence_for": ["..."],
      "evidence_against": ["..."],
      "sources": ["..."]
    }
  ],
  "contradictions": [
    "Source 1 vs Source 3 on performance metrics"
  ],
  "open_questions": [
    "What is the actual implementation cost?"
  ],
  "last_updated": "2026-01-04T21:30:00Z"
}
```

**research-notes.md** (Unstructured):
```markdown
# Research: [Question]

## Session 1 - 04 Gen 2026

### Search Strategy
- Started with official docs
- Expanded to community forums
- Checked academic papers for validation

### Key Findings
- Finding 1: [summary] (Source: X)
- Finding 2: [summary] (Source: Y)
- Contradiction found: X says A, Y says B

### Confidence Evolution
- Initial: 50% Hypothesis 1, 50% Hypothesis 2
- After docs: 70% H1, 30% H2 (reason: benchmark data)
- After forums: 65% H1, 35% H2 (reason: implementation challenges)

### Next Steps
- Verify performance claims with independent benchmarks
- Check for recent updates (last 6 months)
```

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

### Example 1: Technical Decision

**Question:** "Should we use REST or GraphQL for our API?"

**Approach:**
1. Hypotheses:
   - H1: REST is better (60% initial)
   - H2: GraphQL is better (40% initial)

2. Research areas:
   - Performance benchmarks
   - Developer experience
   - Tooling maturity
   - Our specific use case requirements

3. Sources:
   - Official docs (REST and GraphQL)
   - Independent benchmarks (2025)
   - Team experience surveys
   - Production case studies

4. Outcome:
   - Final: 70% REST, 30% GraphQL
   - Reasoning: Our use case (simple CRUD) favors REST
   - Caveat: GraphQL better if requirements change to complex querying

### Example 2: Market Research

**Question:** "What are the top 3 competitors in space X?"

**Approach:**
1. Generate initial list from:
   - Industry reports
   - Market cap data
   - Social mentions

2. Validate through:
   - Customer reviews
   - Feature comparisons
   - Growth metrics

3. Cross-reference:
   - Multiple market research firms
   - Direct competitor analysis
   - Customer surveys

4. Result:
   - Top 3 with confidence levels
   - Evidence for ranking
   - Emerging competitors to watch

## Anti-Patterns to Avoid

**Don't:**
- Commit to first hypothesis without testing alternatives
- Use single source as authoritative
- Ignore contradictory evidence
- Present 100% confidence without overwhelming evidence
- Skip self-critique step
- Leave research state undocumented

**Do:**
- Generate multiple competing hypotheses
- Verify across independent sources
- Update confidence iteratively
- Document reasoning and gaps
- Self-critique regularly
- Save research state for transparency

## Integration with Other Skills

**Works well with:**
- **Strategic Analysis:** Use for competitive research
- **Architecture:** Validate technology choices
- **Code Review:** Research best practices
- **Performance:** Benchmark validation

## Metrics

Track research effectiveness:
- Time to answer
- Number of sources checked
- Confidence calibration accuracy
- Contradictions resolved vs unresolved
- Open questions identified

## Advanced Techniques

### Hypothesis Tree Expansion
- Start with 2-4 top-level hypotheses
- Branch into sub-hypotheses as needed
- Prune low-confidence branches early

### Confidence Calibration
- Track predictions vs outcomes
- Adjust confidence based on evidence strength
- Use Bayesian updating for iterative refinement

### Source Authority Ranking
- Primary > Secondary > Tertiary
- Recent (2025+) > Older (2020-2024) > Ancient (<2020)
- Official > Independent > Anecdotal
- Quantitative > Qualitative (where appropriate)

---

**Remember:** The goal is not just to find AN answer, but to find the RIGHT answer with appropriate confidence and transparency about uncertainty.
