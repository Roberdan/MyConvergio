---
name: ui-design
description: "UI/UX screen design (Apple HIG) + design-to-code translation"
allowed-tools:
  - Read
  - Glob
  - Grep
  - WebSearch
  - Write
  - Edit
context: fork
user-invocable: true
version: "1.0.0"
---

# UI Design Skill

> Workflow from jony-creative-director: UI Design (Apple HIG) + Design-to-Code

## Inputs

| Parameter             | Required | Description                                      |
| --------------------- | -------- | ------------------------------------------------ |
| Platform              | Yes      | iOS / macOS / web                                |
| App type              | Yes      | e.g., fintech dashboard, social app, e-commerce  |
| Primary user persona  | Yes      | Demographics, goals, context                     |
| Top 3 user goals      | Yes      | Priority tasks                                   |
| Current pain points   | Yes      | Problems to solve                                |
| Tech stack (for code) | If code  | React / Vue / Svelte / Next.js / Tailwind / etc. |

## Phase 1: Hierarchy & Layout

- Visual hierarchy strategy (what users see 1st, 2nd, 3rd)
- F-pattern / Z-pattern application
- Content density decisions (breathing room vs information density)
- Liquid Glass principles (iOS 26, if applicable)

## Phase 2: Platform Patterns

| Pattern       | Specification                             |
| ------------- | ----------------------------------------- |
| Navigation    | Tab bar / Sidebar / Navigation stack      |
| Modals        | Presentation guidelines                   |
| Gestures      | Swipe, pinch, pull-to-refresh definitions |
| Context menus | Action sheets, context menus              |

## Phase 3: Screen Designs (8 key screens)

| #   | Screen              | Purpose              |
| --- | ------------------- | -------------------- |
| 1   | Onboarding/Welcome  | First-run experience |
| 2   | Home/Dashboard      | Primary landing      |
| 3   | Primary task        | Core user action     |
| 4   | Detail view         | Content deep-dive    |
| 5   | Settings/Profile    | User preferences     |
| 6   | Search/Filter       | Content discovery    |
| 7   | Checkout/Completion | Action flow end      |
| 8   | Error/Empty state   | Edge cases           |

### Per Screen Spec

| Aspect       | Detail                           |
| ------------ | -------------------------------- |
| Wireframe    | Layout structure description     |
| Components   | Every element inventory          |
| Interactions | Tap, swipe, long-press behaviors |
| Empty state  | What shows with no data          |
| Error state  | Failure handling UI              |
| Loading      | Skeleton screens, indicators     |

## Phase 4: Component Hierarchy

- Button hierarchy: Primary, Secondary, Tertiary, Destructive
- Form patterns: validation, error messaging, success states
- Card layouts with content prioritization
- Data visualization components (if applicable)

## Phase 5: Accessibility (MANDATORY)

| Requirement      | Standard                                     |
| ---------------- | -------------------------------------------- |
| Dynamic Type     | Font scaling to 310%                         |
| VoiceOver        | Labels + hints for every interactive element |
| Color contrast   | WCAG AA: 4.5:1 text, 3:1 UI components       |
| Reduce Motion    | Alternatives for all animations              |
| Focus indicators | Visible keyboard navigation                  |

## Phase 6: Micro-Interactions

| Aspect      | Specification                                 |
| ----------- | --------------------------------------------- |
| Transitions | Duration, easing curves (ease-in-out, spring) |
| Haptics     | Feedback mapping per interaction type         |
| Sound       | Design guidelines (optional)                  |

## Phase 7: Responsive Behavior

Breakpoint adaptations (mobile → tablet → desktop), orientation handling, foldable device considerations.

## Phase 8: Design-to-Code Translation

### Component Architecture

- Component hierarchy tree
- Props interface (TypeScript)
- State management strategy
- Data flow diagram

### Production Code

Per component: complete copy-paste ready code, responsive (mobile-first), ARIA attributes, error boundaries, loading states, animations.

### Styling

| Aspect        | Specification                          |
| ------------- | -------------------------------------- |
| CSS/Tailwind  | Classes mapped to design tokens        |
| CSS variables | Theming support                        |
| Dark mode     | Implementation strategy                |
| Breakpoints   | Responsive rules                       |
| States        | hover / focus / active implementations |

### Design Token Integration

Map tokens to CSS variables: colors, typography (sizes, weights, line heights), spacing (padding, margin, gap), shadows, border-radius.

### Performance

- Code splitting recommendations
- Bundle size optimization
- React.memo / useMemo / useCallback where needed
- Image optimization (next/image or equivalent)
- Lazy loading strategy

### Testing

| Type              | Scope                                |
| ----------------- | ------------------------------------ |
| Unit              | React Testing Library, per component |
| Visual regression | Snapshot comparison scenarios        |
| Accessibility     | axe-core integration                 |
| Responsive        | Breakpoint test cases                |

### Documentation

JSDoc for all props, 3 usage examples per component, Do's and Don'ts.

Include "Designer's Intent" comments explaining why code decisions preserve design vision.

## Outputs

| Deliverable     | Format                              |
| --------------- | ----------------------------------- |
| Screen designs  | 8 detailed screen specs             |
| Component specs | Hierarchy + interaction definitions |
| Accessibility   | Full compliance checklist           |
| Production code | Copy-paste components + styles      |
| Design tokens   | CSS variables / JSON                |
| Test suite      | Unit + visual + a11y tests          |

## Related

`/design-systems` (token foundation) | `/design-quality` (critique + a11y audit) | `/brand-identity` (visual language)
