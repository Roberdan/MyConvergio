# Plan Business Advisor — Output Schemas

## 1) Traditional Effort

```json
{
  "traditional_effort_days": 0,
  "breakdown": [
    { "task": "T1-01", "type": "new-module", "estimate_days": 0, "rationale": "..." }
  ],
  "assumptions": ["Senior dev with domain context", "Existing CI/CD"]
}
```

## 2) Complexity

```json
{
  "complexity_rating": 0,
  "label": "...",
  "justification": "...",
  "factors": {
    "files_touched": 0,
    "cross_cutting_concerns": [],
    "new_patterns": [],
    "external_dependencies": []
  }
}
```

## 3) Business Value

```json
{
  "business_value_score": 0.0,
  "dimensions": {
    "impact": { "score": 0, "rationale": "..." },
    "reach": { "score": 0, "rationale": "..." },
    "risk": { "score": 0, "rationale": "..." }
  },
  "weighted_formula": "(impact * 0.4) + (reach * 0.3) + (risk * 0.3)"
}
```

## 4) Risk Assessment

```json
{
  "risk_assessment": {
    "technical": [{ "risk": "...", "probability": "medium", "impact": "high", "mitigation": "..." }],
    "dependency": [{ "risk": "...", "probability": "low", "impact": "medium", "mitigation": "..." }],
    "scope": [{ "risk": "...", "probability": "low", "impact": "low", "mitigation": "..." }]
  },
  "overall_risk_level": "low|medium|high",
  "top_risk": "..."
}
```

## 5) ROI Projection

```json
{
  "roi_projection": {
    "traditional": { "effort_days": 0, "estimated_cost_usd": 0, "cost_basis": "Senior dev at $800/day" },
    "estimated_ai": {
      "effort_days": 0,
      "compute_cost_usd": 0,
      "human_oversight_days": 0,
      "total_cost_usd": 0,
      "agent_teams_cost_usd": 0,
      "agent_teams_note": "Agent Teams estimate"
    },
    "savings": { "days_saved": 0, "cost_saved_usd": 0, "acceleration_factor": 0.0 }
  }
}
```

## Final Consolidated Report

```json
{
  "plan_id": "{plan_id}",
  "analyzed_at": "ISO-8601",
  "traditional_effort_days": 0,
  "complexity_rating": 0,
  "complexity_label": "...",
  "business_value_score": 0.0,
  "risk_assessment": { "technical": [], "dependency": [], "scope": [] },
  "overall_risk_level": "low|medium|high",
  "roi_projection": {
    "traditional": { "effort_days": 0, "estimated_cost_usd": 0 },
    "estimated_ai": { "effort_days": 0, "total_cost_usd": 0 },
    "savings": { "days_saved": 0, "acceleration_factor": 0.0 }
  },
  "recommendation": "GO|CAUTION|NO-GO",
  "summary": "Executive summary"
}
```
