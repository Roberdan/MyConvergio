---
name: presentation-builder
description: "Animated slide deck builder with React, Tailwind, HLS video backgrounds, and liquid glass aesthetics"
allowed-tools:
  - Read
  - Glob
  - Grep
  - WebSearch
  - Write
  - Edit
  - Bash
context: fork
user-invocable: true
version: "1.0.0"
---

# Presentation Builder Skill

> Build full-screen animated slide deck web apps optimized for live presentation.

## Inputs

| Parameter         | Required | Description                     |
| ----------------- | -------- | ------------------------------- |
| Slide count       | Yes      | Number of slides                |
| Theme             | Yes      | dark / light / custom           |
| Content per slide | Yes      | Title, body, media, layout type |
| Video backgrounds | Optional | HLS stream URLs per slide       |
| Brand assets      | Optional | Logo SVG, fonts, colors         |

## Tech Stack

| Package           | Purpose                                  |
| ----------------- | ---------------------------------------- |
| React             | Component framework                      |
| Tailwind CSS      | Utility-first styling                    |
| hls.js            | HLS video background streaming           |
| lucide-react      | Icon library                             |
| Plus Jakarta Sans | Default presentation font (Google Fonts) |

## Design System

### Global Rules

- **Font**: Plus Jakarta Sans (400, 500, 700) via Google Fonts import
- **Theme**: Dark/black throughout, all text white
- **Font sizes**: Responsive `clamp()` values (e.g., `clamp(12px, 1.05vw, 20px)`)
- **Spacing**: Percentage-based (e.g., `px-[5.2%]`, `pt-[4%]`) for full responsiveness
- **No shadows**: Use liquid glass aesthetic instead

### Liquid Glass Aesthetic

```css
backdrop-filter: blur(24px) saturate(1.4);
background: linear-gradient(
  135deg,
  rgba(255, 255, 255, 0.08),
  rgba(255, 255, 255, 0.03)
);
border: 1px solid rgba(255, 255, 255, 0.12);
/* Subtle radial specular highlight at top-left */
```

## Component Architecture

### Presentation.tsx (Framework)

**Props**: Array of slide React elements, renders full-screen.

**Keyboard Navigation**:

| Key                            | Action            |
| ------------------------------ | ----------------- |
| ArrowRight / ArrowDown / Space | Next slide        |
| ArrowLeft / ArrowUp            | Previous slide    |
| F                              | Toggle fullscreen |
| Escape                         | Exit fullscreen   |

**Transitions**: 500ms ease-in-out opacity fade + subtle scale (0.95 past, 1.05 future, 1 current).

**Auto-hiding Controls** (appear on mouse move, hide after 3s inactivity, 300ms fade):

| Position      | Element                                                                       |
| ------------- | ----------------------------------------------------------------------------- |
| Bottom-left   | Slide counter ("1 / 5", white/50, 13px, tabular-nums)                         |
| Bottom-center | Progress dots (6px circles, active = 24px pill white/90, inactive = white/30) |
| Bottom-right  | Prev/next chevrons + divider + fullscreen toggle (white/50, hover white/90)   |
| Top-right     | Keyboard hints ("Arrow Navigate, F Fullscreen", 11px, white/40)               |

### Video Background Pattern (per slide)

Identical implementation across all video slides:

```typescript
// HLS.js: if supported, create instance, load source, attach, auto-play on MANIFEST_PARSED
// Safari fallback: native HLS on <video src={url}>
// <video>: absolute inset-0 w-full h-full object-cover, autoPlay loop muted playsInline
// No overlay, no dimming, 100% opacity
// Content sits on top via relative z-10
```

## Slide Types

### Cover Slide

- Video background (HLS)
- Header: logo left, label right
- Center: title (clamp 32px-96px), subtitle (clamp 20px-48px), author (clamp 14px-24px)
- Footer: year centered

### Content Slide (Multi-Column)

- Video background (HLS)
- Header: logo, title, page number
- Title section
- 2-3 column layout with stats, paragraphs, mini charts (SVG)

### Card Grid Slide

- Video background (HLS)
- Header + centered title
- Card grid: top row (3 cards) + bottom row (2 cards)
- Liquid glass cards with icon, title, description
- Icons from lucide-react (white stroke)

### Quote Slide

- Video background (HLS)
- Centered: attribution + quote (smart quotes)
- Max-width 70%

### Contact/Outro Slide

- Video background (HLS)
- Title + description paragraph
- Contact items: icon + text, stacked vertically
- Social icons: custom SVG paths for Instagram/Facebook

## Workflow

1. **Gather content**: slides, media, brand assets
2. **Scaffold**: Presentation.tsx + individual slide components
3. **Implement video**: HLS.js pattern per slide
4. **Style**: Liquid glass cards, clamp() typography, percentage spacing
5. **Navigation**: Keyboard handlers, progress dots, auto-hide controls
6. **Wire**: App.tsx imports all slides into Presentation component

## Output

| Deliverable      | Description                                        |
| ---------------- | -------------------------------------------------- |
| Presentation.tsx | Framework with navigation, transitions, controls   |
| [Name]Slide.tsx  | One component per slide                            |
| App.tsx          | Wires slides into Presentation                     |
| index.css        | Global styles, font import, liquid glass utilities |

## Quality Checklist

- [ ] All font sizes use `clamp()`
- [ ] All spacing uses percentage values
- [ ] No shadows (liquid glass only)
- [ ] HLS.js with Safari fallback on all video slides
- [ ] Keyboard navigation working (arrows, F, Escape)
- [ ] Controls auto-hide after 3s
- [ ] Transitions smooth (500ms ease-in-out)
- [ ] Responsive at all viewport sizes
- [ ] Content readable over video backgrounds

## Related

`/brand-identity` (brand strategy + presentation design) | `/ui-design` (component specs) | `/design-systems` (design tokens)
