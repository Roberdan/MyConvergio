<!-- v2.0.0 -->

# Ethical Guidelines

> MyConvergio agent ecosystem rule. Complements [CONSTITUTION.md](../CONSTITUTION.md)

## Privacy (GDPR/CCPA)

**Data minimization** | Explicit consent | Clear privacy policies | Privacy by design/default | User access, modify, delete rights | Encrypt at rest/transit | Regular privacy impact assessments

## Accessibility (WCAG 2.1 AA)

**All UIs keyboard navigable** | Text alternatives for non-text | 4.5:1 contrast | Screen reader support | Captions for audio/video | 200% text resize | Design for diverse abilities (motor, visual, auditory, cognitive) | Test with actual users with disabilities

## Inclusive Language

Gender-neutral | blocklist/allowlist (not black/whitelist) | primary/replica (not master/slave) | Person-first for disabilities | No cultural assumptions | i18n/l10n support | Cultural sensitivities in imagery | Clear, simple language

## Non-Discriminatory Algorithms

Audit for bias across protected characteristics | Diverse training data | Test for disparate impact | Document AI/ML limitations and biases | Explain automated decisions | Human review for high-stakes | Monitor for emerging biases

## AI Transparency

Disclose AI interactions | Explain recommendations | Allow opt-out | Document capabilities/limitations | Transparent training sources (when appropriate) | Confidence scores | User feedback on decisions

## Consent & Control

Informed consent | Plain language | Granular options (not all-or-nothing) | Easy privacy controls | Respect Do Not Track | Withdrawal anytime | No dark patterns

## Security as User Protection

Protect users, not just systems | Prompt breach notification | Secure defaults (opt-in sharing) | Regular audits/pentests | Vulnerability disclosure program | User security education

## Environmental Responsibility

Optimize for energy efficiency | Consider carbon footprint | Renewable energy hosting | Efficient caching/data transfer | Monitor resource consumption

## Honesty & Integrity

Never mislead about capabilities | Communicate limitations/risks | Fix mistakes promptly | No deceptive patterns | Transparent business model | Honest marketing

## Examples

```typescript
// Good: Clear consent, granular control
interface PrivacySettings {
  analytics: boolean;          // Opt-in for analytics
  marketing: boolean;           // Opt-in for marketing
  thirdPartySharing: boolean;   // Opt-in for sharing
}

// Good: Accessible design
<button
  aria-label="Submit form"
  onClick={handleSubmit}
  className="min-contrast-4.5"
>
  Submit
</button>

// Good: AI transparency
{
  prediction: "likely interested",
  confidence: 0.73,
  explanation: "Based on browsing history and preferences",
  canOptOut: true
}
```

## Anti-Patterns

❌ All-or-nothing consent | ❌ Dark patterns | ❌ Hidden privacy settings | ❌ Misleading capabilities | ❌ Unexplained AI decisions | ❌ Inaccessible UIs | ❌ Discriminatory defaults | ❌ Unlimited data collection
