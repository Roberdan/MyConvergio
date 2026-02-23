---
name: design-quality
description: "Design critique (Nielsen heuristics) + accessibility audit (WCAG 2.2 AA)"
allowed-tools:
  - Read
  - Glob
  - Grep
  - WebSearch
context: fork
user-invocable: true
version: "1.0.0"
---

# Design Quality Skill

> Workflow from jony-creative-director: Design Critique + Accessibility Auditor

## Inputs

| Parameter     | Required    | Description                                |
| ------------- | ----------- | ------------------------------------------ |
| Design        | Yes         | Description, wireframe, or uploaded design |
| Platform      | Recommended | Web / iOS / Android / cross-platform       |
| Brand context | Recommended | Brand guidelines reference                 |

## Part A: Design Critique

### 1. Heuristic Evaluation (Nielsen's 10, score 1-5 each)

| #   | Heuristic                   | Evaluate                               |
| --- | --------------------------- | -------------------------------------- |
| 1   | Visibility of system status | Loading, progress, feedback indicators |
| 2   | Match system ↔ real world   | Language, concepts, conventions        |
| 3   | User control & freedom      | Undo, cancel, exit paths               |
| 4   | Consistency & standards     | Internal + platform consistency        |
| 5   | Error prevention            | Confirmations, constraints, defaults   |
| 6   | Recognition > recall        | Visible options, contextual help       |
| 7   | Flexibility & efficiency    | Shortcuts, customization, expert paths |
| 8   | Aesthetic & minimalist      | Signal-to-noise ratio                  |
| 9   | Error recovery              | Clear messages, actionable solutions   |
| 10  | Help & documentation        | Searchable, task-oriented, concise     |

### 2. Visual Hierarchy

- What does user see first? Is it correct?
- CTA hierarchy clear?
- Visual weights balanced?
- Adequate white space?

### 3. Typography Audit

- Font choices match brand?
- Type scale creates clear hierarchy?
- Line lengths 45-75 characters?
- Contrast sufficient for readability?

### 4. Color Analysis

- Palette supports brand personality?
- WCAG AA contrast (4.5:1 text, 3:1 UI)?
- Color used meaningfully, not just decoratively?
- Dark mode considerations?

### 5. Usability

- Cognitive load assessment
- Interaction clarity (what's clickable?)
- Touch targets minimum 44x44pt?
- Form usability (labels, validation)

### 6. Strategic Alignment

- Serves business goals?
- Serves user goals?
- Value proposition clear?
- Differentiates from competitors?

### 7. Prioritized Recommendations

| Priority  | Criteria               |
| --------- | ---------------------- |
| Critical  | Must fix before launch |
| Important | Fix in next iteration  |
| Polish    | Nice to have           |

### 8. Redesign Direction

2 alternative approaches with verbal sketches and rationale.

## Part B: Accessibility Audit (WCAG 2.2 AA)

### 1. Perceivable

| Check                | Standard                           |
| -------------------- | ---------------------------------- |
| Text alternatives    | Alt text for all images            |
| Captions/transcripts | All multimedia                     |
| Color independence   | Color not sole information carrier |
| Text contrast        | Normal 4.5:1, Large 3:1            |
| UI contrast          | Components 3:1                     |
| Text resize          | 200% without content loss          |
| No images of text    | Except logos                       |

### 2. Operable

| Check                     | Standard                         |
| ------------------------- | -------------------------------- |
| Keyboard access           | All functionality                |
| No keyboard traps         | Escape always works              |
| Skip links                | For repetitive content           |
| Page titles               | Descriptive and unique           |
| Focus order               | Logical and predictable          |
| Link purpose              | Clear from context               |
| Multiple navigation paths | Search, nav, sitemap             |
| Focus visible             | 2px outline, 3:1 contrast        |
| Pointer alternatives      | Single-pointer for all gestures  |
| Motion disable            | prefers-reduced-motion respected |
| No auto-playing audio     | User-initiated only              |
| Touch targets             | 44x44 CSS pixels minimum         |

### 3. Understandable

| Check                     | Standard                               |
| ------------------------- | -------------------------------------- |
| Page language             | `lang` attribute set                   |
| Parts language            | `lang` on foreign text                 |
| Consistent identification | Same function = same label             |
| Error identification      | Clear error messages                   |
| Error suggestions         | How to fix                             |
| Error prevention          | Confirm/reversible for legal/financial |
| Contextual help           | Available where needed                 |

### 4. Robust

| Check           | Standard                    |
| --------------- | --------------------------- |
| Valid markup    | Proper HTML                 |
| Name/role/value | All components programmatic |
| Status messages | ARIA live regions           |

### 5. Mobile-Specific

- Orientation not locked (responds to rotation)
- All input modalities (touch, mouse, keyboard, voice)
- Thumb zone placement considerations

### 6. Cognitive Accessibility

- Reading level: Flesch-Kincaid Grade 8 or below
- Consistent navigation placement
- Plain language error messages
- Time limits extendable/eliminable
- No flashing (max 3/second)

## Audit Deliverables

| Deliverable             | Content                             |
| ----------------------- | ----------------------------------- |
| Pass/fail checklist     | Every criterion scored              |
| Violation report        | Location, severity, description     |
| Remediation guide       | Code/design solutions per violation |
| Accessibility statement | Template for public statement       |
| QA testing checklist    | Screen reader flow descriptions     |

## Related

`/design-systems` (component a11y specs) | `/ui-design` (screen-level a11y) | `/brand-identity` (inclusive brand)
