---
name: report
description: "Convergio Think Tank - Professional research reports in Morgan Stanley style"
invocable: true
---

# /report - Convergio Think Tank

## Usage

```
/report [topic]
```

## Description

**Convergio Think Tank (CTT)** generates professional research reports following Morgan Stanley equity research methodology. Supports multiple report types with LaTeX output for high-quality PDFs.

## Report Types

| Type                | Command                                | Description                           |
| ------------------- | -------------------------------------- | ------------------------------------- |
| Equity Research     | `/report equity AAPL`                  | Company analysis, earnings, valuation |
| Industry Analysis   | `/report industry "AI Infrastructure"` | Sector trends, competitive landscape  |
| Market Report       | `/report market "US Tech"`             | Economic trends, macro factors        |
| Technology Analysis | `/report tech "Large Language Models"` | Product/platform assessment           |
| General Research    | `/report "Climate Policy 2026"`        | Any topic with structured analysis    |

## Workflow

The report generator follows a 5-phase workflow:

1. **Intake**: Gather topic, sources, requirements
2. **Research**: Web search, document analysis, data extraction
3. **Analysis**: Synthesis, thesis development, KPI selection
4. **Structuring**: Organize into Morgan Stanley template
5. **Generation**: Produce LaTeX document

## Examples

```bash
# Equity research on a company
/report equity NVDA

# Industry analysis
/report industry "Electric Vehicles"

# General research topic
/report "Impact of AI on Software Development"
```

## Output

CTT-branded deliverables:

- `ctt-[topic]-[date].tex` - Main LaTeX document
- `ctt-[topic]-[date].pdf` - Compiled PDF report
- `tables/` - Data tables in LaTeX format
- `sources.bib` - Bibliography file

## Instructions

When this skill is invoked, use the `research-report-generator` agent to:

1. Ask the user for topic details and report type
2. Collect any documents or sources they want to include
3. Perform web research to gather current data
4. Analyze and synthesize findings
5. Generate a professional LaTeX report following the Morgan Stanley template

Key questions to ask:

- What is the primary subject of the report?
- What type of report? (equity/industry/market/tech/general)
- What time period should this cover?
- Do you have specific sources or documents to include?
- Are there comparables or benchmarks to analyze?
- Who is the target audience?

Generate the report using the template at:
`~/.claude/agents/research_report/templates/morgan-stanley-report.tex`

Configuration is in:
`~/.claude/agents/research_report/config/report-config.yaml`
