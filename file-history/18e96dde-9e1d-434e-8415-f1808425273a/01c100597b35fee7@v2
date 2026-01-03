# Wave 1-2: Bug Fixes

**Owner**: Claude-A
**Worktree**: `wt-bugfixes`
**Branch**: `fix/wave-1-2-bugs`
**Status**: Pending (blocked by Wave 0)

---

## Open Issues (10 Total - ALL Must Be Fixed)

### [ ] C-1: STT Discrepancy (BUG 2) - P1

**Problem**: Agent understands correctly, but chat transcription is wrong.

**Examples**:
- Said: "vai" -> Chat shows: "bye"
- Said: "la Spezia" -> Agent responds well, chat shows something else

**Hypothesis**: Two separate STT systems? One for agent, one for UI.

**Investigation**: Check `use-voice-recognition.ts`, `api/chat/route.ts`, `materiali-conversation.tsx` - are there 2 STT paths?
**Decision**: If dual STT → unify; if single → debug sync; if missing → implement Azure Speech + Web Speech fallback
**Outcome**: Chat transcript = AI transcript (100% match)

### [ ] C-2: Session Recap + Memory (BUG 4) - P1

**Problem**: When closing voice conversation, missing:
1. Automatic recap of what was done
2. Correct memory save
3. Parent insights generated
4. Remember previous session on next open

**Note**: Feature should already exist - verify it works.

**Files involved**: `conversation-memory.ts`, session summary logic

### [ ] C-3: Input Bar + Voice Panel Not Fixed (BUG 9) - P1

**Problem**: In chat/voice with maestros, elements that should be fixed scroll with content.

**Expected Layout**:
```
+-------------------------------------+--------------+
|                                     |              |
|    CHAT MESSAGES (SCROLLS)          |  VOICE PANEL |
|    + TOOL CONTENT                   |  (FIXED)     |
|                                     |              |
+-------------------------------------+              |
| [Tool buttons] [Input "Parla..."]   |              |
| (FIXED AT BOTTOM - sticky/fixed)    |              |
+-------------------------------------+--------------+
```

**Likely fix**: CSS sticky/fixed positioning

### [ ] C-4: Azure OpenAI Costs Empty (BUG 24) - P1

**Problem**: In Settings -> Statistics, "Azure OpenAI Costs" card is empty.

**Expected**: Tokens used, estimated cost, breakdown by model, trend.

**Investigation**: Check `diagnostics-tab.tsx`, `azure-openai.ts`, `telemetry-store.ts` for token tracking
**Decision**: If exists → fix display; if partial → complete; if missing → create issue + show "Coming soon"; if unavailable → document limitation

**Expected outcome**: Either working cost display OR documented reason why not available

### [ ] C-5: Conversation History per Coach/Buddy (BUG 32) - P0

**Problem**: Conversation history is GLOBAL instead of per-character.

**Current state**:
- Talk to Melissa about X
- Switch to Andrea
- Andrea sees Melissa's history (WRONG)

**Expected**: Each Coach/Buddy has separate history. Zero leak between characters.

**Files involved**: Conversation storage, memory system, character context

### [ ] C-6: Timer + XP Bar (BUG 3) - P2

**Requirements**: Conversation timer in voice panel + XP progress bar showing level-up progress
**Implementation**: Add elapsed time to voice panel, calculate XP % (current vs next level), store session start in conversation state
**Files**: Voice panel component, XP/gamification store, conversation state

### [ ] C-7: Demo Tool Non Rispetta Accessibilita (BUG 10) - P1

**Problem**: Demo tool ignores user accessibility settings (dyslexic font, high contrast, font size, spacing)
**Implementation**: Inject CSS with accessibility settings into Demo iframe from user profile/store
**Files**: `demo-renderer.tsx`, `src/lib/accessibility/` profiles, CSS injection logic

### [ ] C-8: Audio Ambientale Cafe Non Realistico (BUG 25) - P2

**Problem**: The "Starbucks" ambient sound doesn't resemble a bar/coffee shop at all.

**Expected**:
- People chattering in background
- Typical bar sounds (cups, coffee machine, door opening)
- Realistic coffee shop atmosphere

**Current**: Unidentifiable/unrealistic sound

**Steps**: Download CC0 cafe audio (Freesound/Pixabay) → Save as `public/audio/ambient/cafe-ambience-loop.mp3` → Update `ambient-sounds.ts` config → Test
**Files**: `cafe-ambience-loop.mp3` (NEW), `ambient-sounds.ts` (config)

### [ ] C-9: Contatori Header Non Si Aggiornano (BUG 28) - P0

**Problem**: Header counters (Streak, Flashcard, Tempo, XP) always show 0
**Expected**: Real-time updates - time increments during use, XP after activities, streak shows consecutive days
**Correlation**: Related to BUG 22/23 (telemetria)
**Files**: Header component, stats store, real-time updates, telemetry

### [ ] C-10: Demo/Tools Si Aprono in Nuova Pagina (BUG 20) - P1

**Problem**: Interactive demos open in new browser tab instead of in-app frame/modal
**Expected**: Demos open in frame/panel, never new tabs, seamless experience
**Files**: Link handling, demo viewer component, demo-renderer.tsx

---

## Execution Plan

### Wave 1: P0 Bug Fixes (Sequential)

| Step | Task | Owner | Files Touched | Dependencies |
|------|------|-------|---------------|--------------|
| 1.1 | C-5: History per Coach/Buddy | Claude-A | `conversation-flow-store.ts`, `conversation-memory.ts` | Wave 0.3 |
| 1.2 | C-9: Header Counters Real-time | Claude-A | Header, stats store, telemetry | 1.1 |

### Wave 2: P1 + P2 Bug Fixes (Sequential)

| Step | Task | Owner | Files Touched | Dependencies |
|------|------|-------|---------------|--------------|
| 2.1 | C-2: Session Recap + Memory | Claude-A | `conversation-memory.ts`, session logic | 1.1 |
| 2.2 | C-3: Layout sticky | Claude-A | `materiali-conversation.tsx` (CSS only) | 1.1 |
| 2.3 | C-4: Azure costs | Claude-A | `diagnostics-tab.tsx`, Azure API | 1.1 |
| 2.4 | C-1: STT investigation | Claude-A | Voice transcription files | 1.1 |
| 2.5 | C-6: Timer + XP Bar | Claude-A | Voice panel, XP store | 2.1 |
| 2.6 | C-7: Demo Accessibility | Claude-A | `demo-renderer.tsx`, accessibility lib | 2.1 |
| 2.7 | C-8: Cafe Audio | Claude-A | `public/audio/`, audio config | 2.1 |
| 2.8 | C-10: Demo in frame (not new tab) | Claude-A | `demo-renderer.tsx`, link handling | 2.6 |

### Completion Criteria

- [ ] All 10 issues resolved
- [ ] `npm run typecheck && npm run lint && npm run build` passes
- [ ] PR `fix/wave-1-2-bugs` created
- [ ] Status updated in TODAY.md

---

## Sign-off Checklist

| Step | Task | Status | Date | Signature |
|------|------|--------|------|-----------|
| 1.1 | C-5: History per Coach/Buddy (P0) | [ ] | | Claude-A |
| 1.2 | C-9: Header Counters Real-time (P0) | [ ] | | Claude-A |
| 2.1 | C-2: Session Recap + Memory (P1) | [ ] | | Claude-A |
| 2.2 | C-3: Layout sticky (P1) | [ ] | | Claude-A |
| 2.3 | C-4: Azure costs (P1) | [ ] | | Claude-A |
| 2.4 | C-1: STT Discrepancy (P1) | [ ] | | Claude-A |
| 2.5 | C-6: Timer + XP Bar (P2) | [ ] | | Claude-A |
| 2.6 | C-7: Demo Accessibility (P1) | [ ] | | Claude-A |
| 2.7 | C-8: Cafe Audio (P2) | [ ] | | Claude-A |
| 2.8 | C-10: Demo in frame (P1) | [ ] | | Claude-A |
| - | PR created | [ ] | | Claude-A |

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
| Manual testing | Each bug verified fixed | [ ] Done | |

**Verified by**: _________________ **Date**: _________________

**Thor Validation**: Before creating PR, invoke Thor quality gate:
```bash
# In worktree wt-bugfixes, before creating PR:
# Thor will verify all checks above automatically
```

---

*Parent document: [TODAY.md](../TODAY.md)*
*Created: 3 January 2026*
*Updated: 3 January 2026 (Added BUG 3, 10, 25, 28, 20 - zero deferred)*
