# Wave 3: MirrorBuddy Welcome Experience

**Owner**: Claude-B team (B1, B2, B3)
**Worktree**: `wt-welcome`
**Branch**: `feat/welcome-experience`
**Status**: Pending (blocked by Wave 0)

---

## Objective

Design and implement a welcome experience for MirrorBuddy that functions as a **real entry point to the system**, not a placeholder.

---

## Mandatory Requirements

1. **Two forms of welcome**:
   - Voice-based welcome
   - Traditional visual/UI welcome

2. **Visual welcome must be**:
   - A landing-style entry page
   - Visually recognizable as "the entrance"
   - Explanatory (what is MirrorBuddy)
   - Welcoming (tone, copy, flow)
   - Motivating (invites user to continue)

3. **Skip behavior**:
   - Welcome MUST be skippable
   - Skip behavior explicitly designed and documented

---

## Assumptions

- This is MirrorBuddy's main entry point
- Sets expectations, trust, and orientation
- NOT optional or cosmetic

---

## Information Architecture

```
/welcome
+-- VOICE PATH
|   +-- Melissa greets user
|   +-- Brief voice intro (30 sec max)
|   +-- Questions to gather student info
|   +-- Transition to main dashboard
|   +-- [Skip] -> Direct to Dashboard
|
+-- VISUAL PATH
    +-- Hero Section
    |   +-- MirrorBuddy Logo
    |   +-- Welcoming headline
    |   +-- Explanatory subheadline
    |   +-- CTA "Start" / "With voice"
    |
    +-- What is MirrorBuddy Section
    |   +-- 3-4 feature cards
    |   +-- Illustrative icons
    |   +-- Motivational copy
    |
    +-- Meet your Guides Section
    |   +-- Maestri preview
    |   +-- Coaches/Buddies preview
    |   +-- Personalities and roles
    |
    +-- Quick Start Section
    |   +-- "Start with voice"
    |   +-- "Start without voice"
    |   +-- "Skip and go to dashboard"
    |
    +-- Footer Section
        +-- Privacy/terms links
        +-- FightTheStroke info
```

---

## Behavior Flows

### First Launch (New User)
```
1. User arrives at /welcome
2. Sees visual landing
3. Chooses: Voice / Without Voice / Skip
4. If Voice: Melissa guides onboarding
5. If Without Voice: Guided form
6. If Skip: Direct dashboard + gentle reminder
7. Flag "onboarding_completed" saved
```

### Returning User
```
1. User arrives at /
2. Check: onboarding_completed?
3. If YES: Direct to Dashboard
4. If NO: Redirect to /welcome
```

### Skip Behavior
```
1. Skip available at EVERY moment
2. Click "Skip" -> light confirmation modal
3. Message: "You can always review the intro from Settings"
4. Redirect to Dashboard
5. Flag onboarding_skipped = true
6. In Settings: "Review introduction" link
```

---

## File Structure

| File | Purpose |
|------|---------|
| `src/app/welcome/page.tsx` | Main page (exists, to improve) |
| `src/app/welcome/components/hero-section.tsx` | Hero landing (NEW) |
| `src/app/welcome/components/features-section.tsx` | Feature cards (NEW) |
| `src/app/welcome/components/guides-section.tsx` | Maestri/coaches preview (NEW) |
| `src/app/welcome/components/quick-start.tsx` | Start CTAs (NEW) |
| `src/lib/stores/onboarding-store.ts` | Onboarding state |

---

## Execution Plan

| Step | Task | Owner | Files Touched | Parallel? | Dependencies |
|------|------|-------|---------------|-----------|--------------|
| 3.1 | hero-section.tsx | Claude-B1 | `welcome/components/hero-section.tsx` (NEW) | YES | 0.3 |
| 3.2 | features-section.tsx | Claude-B2 | `welcome/components/features-section.tsx` (NEW) | YES | 0.3 |
| 3.3 | guides-section.tsx | Claude-B3 | `welcome/components/guides-section.tsx` (NEW) | YES | 0.3 |
| 3.4 | quick-start.tsx | Claude-B1 | `welcome/components/quick-start.tsx` (NEW) | After 3.1 | 3.1 |
| 3.5 | Refactor page.tsx | Claude-B1 | `welcome/page.tsx` | NO | 3.1-3.4 |
| 3.6 | Skip flow | Claude-B1 | `welcome/page.tsx`, `onboarding-store.ts` | NO | 3.5 |
| 3.7 | Returning user logic | Claude-B1 | `app/page.tsx`, `onboarding-store.ts` | NO | 3.6 |
| 3.8 | Settings link | Claude-B1 | `settings/sections/*.tsx` | NO | 3.7 |
| 3.9 | E2E tests | Claude-B1 | `e2e/welcome.spec.ts` (NEW) | NO | 3.8 |

---

## Acceptance Criteria

- [ ] Visual landing implemented with all sections
- [ ] Voice path works end-to-end with Melissa
- [ ] Skip works at every point
- [ ] Onboarding flag saved correctly
- [ ] Returning user bypasses welcome
- [ ] "Review intro" link in Settings
- [ ] Responsive (mobile/tablet/desktop)
- [ ] Accessible (WCAG 2.1 AA)
- [ ] E2E tests cover all flows

---

## Sign-off Checklist

| Step | Task | Status | Date | Signature |
|------|------|--------|------|-----------|
| 3.1 | hero-section.tsx | [ ] | | Claude-B1 |
| 3.2 | features-section.tsx | [ ] | | Claude-B2 |
| 3.3 | guides-section.tsx | [ ] | | Claude-B3 |
| 3.4 | quick-start.tsx | [ ] | | Claude-B1 |
| 3.5 | Refactor page.tsx | [ ] | | Claude-B1 |
| 3.6 | Skip flow | [ ] | | Claude-B1 |
| 3.7 | Returning user logic | [ ] | | Claude-B1 |
| 3.8 | Settings link | [ ] | | Claude-B1 |
| 3.9 | E2E tests | [ ] | | Claude-B1 |
| - | PR created | [ ] | | Claude-B1 |

---

## Evidence Section (Thor Quality Gate)

| Check | Command | Result | Timestamp |
|-------|---------|--------|-----------|
| Typecheck | `npm run typecheck` | [ ] PASS / FAIL | |
| Lint | `npm run lint` | [ ] PASS / FAIL | |
| Build | `npm run build` | [ ] PASS / FAIL | |
| Workarounds | `grep -r "@ts-ignore\|TODO\|HACK" src/` | [ ] 0 matches | |
| Placeholders | `grep -ri "PLACEHOLDER\|MOCK_DATA" src/` | [ ] 0 matches | |
| E2E assertions | Manual review of test files | [ ] All tests have expect() | |
| Accessibility | WCAG 2.1 AA compliance check | [ ] PASS | |
| Responsive | Mobile/tablet/desktop tested | [ ] Done | |
| Manual testing | All flows tested (voice, visual, skip) | [ ] Done | |

**Verified by**: _________________ **Date**: _________________

**Thor Validation**: Before creating PR, invoke Thor quality gate:
```bash
# In worktree wt-welcome, before creating PR:
# Thor will verify all checks above + accessibility compliance
```

---

*Parent document: [TODAY.md](../TODAY.md)*
*Created: 3 January 2026*
