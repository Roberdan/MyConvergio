---
name: design-systems
description: "Design system creation (Apple HIG) + Figma auto-layout specifications"
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

# Design Systems Skill

> Workflow from jony-creative-director: Design System Architect + Figma Expert

## Inputs

| Parameter          | Required | Description                                         |
| ------------------ | -------- | --------------------------------------------------- |
| Brand/product name | Yes      | Target brand or product                             |
| Personality        | Yes      | MINIMALIST / BOLD / PLAYFUL / PROFESSIONAL / LUXURY |
| Primary emotion    | Yes      | TRUST / EXCITEMENT / CALM / URGENCY                 |
| Target audience    | Yes      | Demographics + psychographics                       |

## Phase 1: Foundations

### Color System

| Deliverable     | Specification                                         |
| --------------- | ----------------------------------------------------- |
| Primary palette | 6 colors: hex, RGB, HSL, WCAG contrast ratings        |
| Semantic colors | success, warning, error, info with hex values         |
| Dark mode       | Equivalents for all colors, contrast ratios verified  |
| Usage rules     | When/where each color applies, forbidden combinations |

### Typography

| Level                      | Specify                                                  |
| -------------------------- | -------------------------------------------------------- |
| Display, Headline, Title   | Size, weight, line height, letter spacing per breakpoint |
| Body, Callout, Subheadline | Desktop (1440px), tablet (768px), mobile (375px)         |
| Footnote, Caption          | Font pairing strategy, minimum legibility sizes          |

Primary font family with 9 weights. Type scale with exact values.

### Layout Grid

12-column responsive: desktop 1440px / tablet 768px / mobile 375px. Specify gutters, margins, breakpoints, safe areas (notched devices).

### Spacing System

8px base unit scale: 4, 8, 12, 16, 24, 32, 48, 64, 96, 128. Usage guideline per step.

## Phase 2: Components (30+ with variants)

| Category     | Components                                                                         |
| ------------ | ---------------------------------------------------------------------------------- |
| Navigation   | Header, Tab bar, Sidebar, Breadcrumbs                                              |
| Input        | Buttons (6 variants), Text fields, Dropdowns, Toggles, Checkboxes, Radios, Sliders |
| Feedback     | Alerts, Toasts, Modals, Progress indicators, Skeleton screens                      |
| Data display | Cards, Tables, Lists, Stats, Charts                                                |
| Media        | Image containers, Video players, Avatars                                           |

### Per Component Spec

| Aspect        | Detail                                                  |
| ------------- | ------------------------------------------------------- |
| Anatomy       | Parts breakdown with names                              |
| States        | default, hover, active, disabled, loading, error        |
| Usage         | When to use, when NOT to use                            |
| Accessibility | ARIA labels, keyboard nav, focus states                 |
| Code-ready    | padding, margins, border-radius, shadows (exact values) |

## Phase 3: Patterns

- **Page templates**: Landing, Dashboard, Settings, Profile, Checkout
- **User flows**: Onboarding, Auth, Search, Filtering, Empty states
- **Feedback**: Success, Error, Loading, Empty state patterns

## Phase 4: Design Tokens

Complete JSON structure for developer handoff: color (primitive + semantic), typography, spacing, shadow/elevation, border-radius tokens.

## Phase 5: Figma Specifications

### Auto-Layout (per component)

| Property     | Values to specify                     |
| ------------ | ------------------------------------- |
| Direction    | vertical / horizontal                 |
| Padding      | top, right, bottom, left              |
| Item spacing | exact px value                        |
| Distribution | packed / space-between                |
| Alignment    | start / center / end / stretch        |
| Resizing     | hug contents / fill container / fixed |

### Component Architecture

- Master component structure with variant properties (boolean, instance swap, text)
- Variant matrix example: `Type × State × Size` (e.g., Button: Primary/Secondary × Default/Hover/Disabled × S/M/L)
- Component properties: text, boolean, instance swap, variant

### Prototype & Handoff

| Aspect        | Specification                                       |
| ------------- | --------------------------------------------------- |
| Interactions  | Map flows, triggers (click/hover/drag), animations  |
| Timing        | Easing curves, duration, delays                     |
| Export        | 1x/2x/3x/SVG/PDF settings, asset naming conventions |
| CSS           | Properties for key elements, inspect organization   |
| Accessibility | Focus order, ARIA labels, contrast annotations      |

## Phase 6: Documentation

- 3 core design principles with examples
- 10 Do's and Don'ts with visual descriptions
- Developer implementation guide

## Outputs

| Deliverable       | Format                               |
| ----------------- | ------------------------------------ |
| Foundations spec  | Markdown with exact values           |
| Component library | Per-component spec sheets            |
| Design tokens     | JSON token file                      |
| Figma guide       | Auto-layout + component architecture |
| Documentation     | Principles + guidelines              |

## Related

`/brand-identity` (brand strategy) | `/ui-design` (screen application) | `/design-quality` (a11y validation)
