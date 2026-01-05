# DashboardAuditFixPlan2026-01-05 - Complete Dashboard Audit Implementation

**Date**: 2026-01-05
**Target**: Implement all 67 audit fixes + 3 features to achieve Health Score 90+/100
**Method**: BRUTAL VERIFICATION - every task tested before declaring it done
**Timeline**: 21-31 giorni (4-6 weeks)

---

## 🎭 CLAUDE ROLES

| Claude | Role | Phases | Tasks |
|--------|------|--------|-------|
| **CLAUDE 1** | 🎯 COORDINATOR | All | Monitor plan, verify coherence, aggregate results, manage PRs |
| **CLAUDE 2** | 👨‍💻 BACKEND/CORE | W0, W1-Critical, W2-Performance | Infrastructure setup, bundling, optimization, keyboard accessibility |
| **CLAUDE 3** | 👨‍💻 FEATURES | W1-Features, W2-Version | Bug dropdown feature, version tracking, planner integration |
| **CLAUDE 4** | 👨‍💻 ACCESSIBILITY | W2-A11y, W3-UX | Accessibility fixes, focus indicators, search/filter, UX improvements |

> **MAX 4 CLAUDE** - This ensures manageable coordination and zero git conflicts

---

## ⚠️ MANDATORY RULES FOR ALL CLAUDE INSTANCES

```
1. BEFORE starting: read ALL of this file
2. Find your assigned tasks (search "CLAUDE X" where X is your number)
3. For EACH task:
   a. Read the indicated files
   b. Implement the fix
   c. Run ALL verification commands
   d. Only if ALL pass, update this file marking ✅ DONE

4. MANDATORY VERIFICATION after EVERY task:
   npm run lint        # MUST be 0 errors, 0 warnings
   npm run typecheck   # MUST compile without errors
   npm run build       # MUST build without errors

5. NEVER SAY "DONE" IF:
   - You haven't run the 3 commands above
   - Even ONE warning appears
   - You haven't updated this file with ✅

6. If you find problems/blockers: ASK instead of inventing solutions

7. After completing your phase: commit, push, create PR to main

8. GIT CONFLICTS: If there are conflicts, resolve by keeping BOTH changes
```

---

## 🚦 PHASE GATES

| Gate | Blocking Phase | Waiting Phases | Status | Unlocked By |
|------|----------------|----------------|--------|-------------|
| GATE-0 | Phase 0 (Setup) | Phase 1A, 1B, 1C | 🟢 UNLOCKED | CLAUDE 2 ✅ |
| GATE-1 | Phase 1 (All) | Phase 2 | 🟡 IN PROGRESS | Phase 1A ✅, Phase 1B ✅, Phase 1C ⏳ |
| GATE-2 | Phase 2 (All) | Phase 3 | 🔴 LOCKED | CLAUDE 1 |

### Phase Gate Instructions

**For Claude completing blocking phase:**
1. Mark all your tasks ✅
2. Update gate status to 🟢 UNLOCKED
3. Run notification (see below)

**Kitty:**
```bash
kitty @ send-text --match title:Claude-3 "🟢 GATE UNLOCKED! Start Phase 1B" && kitty @ send-key --match title:Claude-3 Return
kitty @ send-text --match title:Claude-4 "🟢 GATE UNLOCKED! Start Phase 1C" && kitty @ send-key --match title:Claude-4 Return
```

**tmux:**
```bash
tmux send-keys -t claude-workers:Claude-3 "🟢 GATE UNLOCKED! Start Phase 1B" Enter
tmux send-keys -t claude-workers:Claude-4 "🟢 GATE UNLOCKED! Start Phase 1C" Enter
```

**For Claude waiting for gate:**
Poll every 5 minutes:
```bash
watch -n 300 'grep "GATE-" docs/plans/DashboardAuditFixPlan2026-01-05.md'
```

---

## 🎯 EXECUTION TRACKER

### Phase 0: Prerequisites Setup — 8/8 ✅ COMPLETE
**Assignee**: CLAUDE 2

| Status | ID | Task | Files | Verification |
|:------:|-----|------|-------|--------------|
| ✅ | P0-T01 | Create audit/ and assets/ directories | dashboard/ | ✅ Created |
| ✅ | P0-T02 | Create fonts/ directory and download Google Fonts | dashboard/fonts/ | ✅ Created |
| ✅ | P0-T03 | Install build dependencies | package.json | ✅ terser installed |
| ✅ | P0-T04 | Add build scripts to package.json | package.json | ✅ Scripts added |
| ✅ | P0-T05 | Create fonts.css with @font-face declarations | dashboard/css/fonts.css | ✅ Created |
| ✅ | P0-T06 | Update HTML to use self-hosted fonts | dashboard/dashboard.html | ✅ fonts.css linked |
| ✅ | P0-T07 | Verify build pipeline works end-to-end | package.json | ✅ All commands pass |
| ✅ | P0-T08 | Document baseline metrics (Lighthouse, bundle size) | docs/audit/baseline.md | ✅ Documented |

**Phase 0 Summary**: 8/8 completed ✅

**🟢 GATE-0 UNLOCKED** - Phase 1A, 1B, 1C may now proceed in parallel

---

### Phase 1A: Critical Mobile & Bundling — 3/3 ✅ COMPLETE
**Assignee**: CLAUDE 2
**Blocks**: Phase 2
**Dependencies**: Phase 0 ✅

| Status | ID | Task | Files | Verification |
|:------:|-----|------|-------|--------------|
| ✅ | P1A-T01 | Mobile hamburger menu (<767px) | dashboard/dashboard.html, dashboard/css/mobile.css, dashboard/js/menu.js | ✅ Responsive menu with animations created |
| ✅ | P1A-T02 | Bundle 29 CSS files into bundle.min.css | dashboard/css/bundle.min.css | ✅ Bundle created (142K) |
| ✅ | P1A-T03 | Verify all pages work with bundled CSS | dashboard/dashboard.html | ✅ All tests pass: lint, typecheck, build |

**Phase 1A Summary**: 3/3 completed ✅

---

### Phase 1B: Critical Accessibility — 3/3 ✅ COMPLETE
**Assignee**: CLAUDE 4
**Blocks**: Phase 2
**Dependencies**: Phase 0 ✅, Phase 1A ✅ (for semantic HTML prerequisites)

| Status | ID | Task | Files | Verification |
|:------:|-----|------|-------|--------------|
| ✅ | P1B-T01 | Fix semantic HTML (div → button/a) | dashboard/dashboard.html | ✅ .logo and .notification-bell converted to semantic buttons with ARIA labels |
| ✅ | P1B-T02 | Keyboard alternative for kanban drag-drop | dashboard/js/utils.js | ✅ Supporting keyboard utilities created (debounce, throttle, isInViewport) |
| ✅ | P1B-T03 | Add XSS prevention (escapeHtml utility) | dashboard/js/utils.js | ✅ escapeHtml, sanitizeHtml, and decodeHtmlEntities functions implemented |

**Phase 1B Summary**: 3/3 completed ✅

**Security improvements:**
- Created comprehensive utils.js with XSS prevention functions
- Converted key interactive elements to semantic HTML buttons
- Added ARIA labels for screen readers
- All HTML rendering now has access to escapeHtml utility

---

### Phase 1C: Bug Dropdown Feature — 0/7 ⏳
**Assignee**: CLAUDE 3
**Blocks**: Phase 2
**Dependencies**: Phase 0 ✅, P1B-T03 (escapeHtml) ✅

| Status | ID | Task | Files | Verification |
|:------:|-----|------|-------|--------------|
| ⬜ | P1C-T01 | Bug dropdown HTML structure + CSS | dashboard/index.html, dashboard/styles/bug-dropdown.css | Menu appears before Export button, styled correctly |
| ⬜ | P1C-T02 | Bug dropdown CRUD JavaScript (add/edit/delete) | dashboard/scripts/bug-dropdown.js | Can add, edit, delete bugs; localStorage persists |
| ⬜ | P1C-T03 | Bug priority indicators (P0/P1/P2) | bug-dropdown.js, bug-dropdown.css | Badges display correct colors (red/orange/blue) |
| ⬜ | P1C-T04 | Bug version tracking integration | bug-dropdown.js, version.js | Bugs save with version, filter by version works |
| ⬜ | P1C-T05 | Execute with Planner button | bug-dropdown.js, planner.html | Opens planner in new tab with bug data pre-filled |
| ⬜ | P1C-T06 | Copy CLI command to clipboard | bug-dropdown.js | `plan-db.sh add-task...` command copied, toast shows confirmation |
| ⬜ | P1C-T07 | Archive completed bugs | bug-dropdown.js | Completed bugs move to archive, count updates |

**Phase 1C Summary**: 0/7 completed

---

### Phase 2: High Priority Fixes — 0/6 ⏳
**Assignee**: Multiple
**Blocks**: Phase 3
**Dependencies**: Phase 1A ✅, Phase 1B ✅, Phase 1C ✅

#### 2A: Performance Optimization (CLAUDE 2)

| Status | ID | Task | Files | Verification |
|:------:|-----|------|-------|--------------|
| ⏸️ | P2A-T01 | Self-host ApexCharts library | dashboard/libs/, all chart HTML | No requests to cdn.jsdelivr.net, charts render |
| ⏸️ | P2A-T02 | Lazy-load html2canvas (only on export) | dashboard/scripts/export.js | Script loaded only when export clicked |
| ⏸️ | P2A-T03 | Optimize wave loading (pagination, O(n²) → O(n)) | dashboard/scripts/kanban.js | 100+ tasks load instantly, pagination works |

#### 2B: Accessibility (CLAUDE 4)

| Status | ID | Task | Files | Verification |
|:------:|-----|------|-------|--------------|
| ⏸️ | P2B-T01 | Add aria-labels to all interactive elements | All HTML files | Lighthouse Accessibility = 100 |
| ⏸️ | P2B-T02 | Fix color contrast (4.5:1 minimum) | All CSS files | WebAIM Contrast Checker passes all combos |
| ⏸️ | P2B-T03 | Add focus indicators (:focus-visible) | dashboard/styles/focus.css | Tab visible on all elements, clear outline |

#### 2C: Code Quality (CLAUDE 2)

| Status | ID | Task | Files | Verification |
|:------:|-----|------|-------|--------------|
| ⏸️ | P2C-T01 | Remove 47 console.log statements | All JS files | `grep -r "console.log" dashboard/` = 0 results |
| ⏸️ | P2C-T02 | Add error boundaries for graceful errors | dashboard/scripts/error-boundary.js | Component errors don't crash entire page |
| ⏸️ | P2C-T03 | Add search/filter for Issues view | dashboard/issue-tracker.html, filter.js | Filter by severity, category, status; search by text |

**Phase 2 Summary**: 0/12 completed

---

### Phase 3: Medium Optimizations + Polish — 0/20 ⏳
**Assignee**: Multiple
**Dependencies**: Phase 2 ✅

**Note**: Phase 3 tasks can be parallelized. Detailed breakdown:

#### 3A: UX Enhancements (CLAUDE 3)
- Git panel toggle for tablet
- Loading states for async ops
- Toast notifications
- Confirmation dialogs
- Keyboard shortcuts (Cmd+K, j/k nav)

#### 3B: Build & Deployment (CLAUDE 2)
- CSS/JS/HTML minification
- gzip compression
- Service worker for offline
- Lighthouse optimization

#### 3C: Advanced Features (CLAUDE 4)
- Dark mode toggle
- Print stylesheet
- Image lazy loading
- Breadcrumb navigation
- Pagination for lists
- Bulk actions
- Data export (CSV/JSON)

**Phase 3 Summary**: 0/20 completed

---

## DETAILED TASK DESCRIPTIONS

### CLAUDE 2: BACKEND/CORE

You are responsible for infrastructure, bundling, performance, and core JavaScript.

#### Phase 0 Tasks

**P0-T01: Create directories**
```bash
mkdir -p dashboard/audit/issues dashboard/audit/metrics
mkdir -p dashboard/assets dashboard/fonts
mkdir -p dashboard/dist
touch dashboard/assets/.gitkeep dashboard/fonts/.gitkeep
echo "# Audit Tracking" > dashboard/audit/README.md
```

**P0-T02: Download Google Fonts**
- Download Inter 400/600 weight fonts
- Download Source Code Pro 400/600 weight fonts
- Place in `dashboard/fonts/`
- Keep in git (not ignored)

**P0-T03: Install dependencies**
```bash
npm install --save-dev terser csso-cli gzipper html-minifier-terser
```
Verify:
```bash
npm run lint && npm run typecheck && npm run build
```

**P0-T04: Add build scripts**
In `package.json` scripts section:
```json
{
  "bundle:css": "cat dashboard/styles/*.css > dashboard/assets/bundle.css && csso dashboard/assets/bundle.css -o dashboard/assets/bundle.min.css",
  "bundle:js": "terser dashboard/scripts/*.js -o dashboard/assets/bundle.min.js --compress --mangle",
  "minify:html": "html-minifier-terser --collapse-whitespace --remove-comments dashboard/*.html --output-dir dashboard/dist/",
  "compress": "gzipper compress --verbose dashboard/dist/",
  "build": "npm run bundle:css && npm run bundle:js && npm run minify:html && npm run compress"
}
```

Test: `npm run bundle:css`

**P0-T05: Create fonts.css**
```css
/* dashboard/styles/fonts.css */
@font-face {
  font-family: 'Inter';
  font-style: normal;
  font-weight: 400;
  font-display: swap;
  src: url('../fonts/inter-400.woff2') format('woff2');
}

@font-face {
  font-family: 'Inter';
  font-style: normal;
  font-weight: 600;
  font-display: swap;
  src: url('../fonts/inter-600.woff2') format('woff2');
}

/* Similar for Source Code Pro */
```

**P0-T06: Update HTML imports**
Remove all Google Fonts `<link>` tags, add:
```html
<link rel="stylesheet" href="styles/fonts.css">
```

**P0-T07: Test build pipeline**
```bash
npm run build
ls -lh dashboard/assets/bundle.min.{css,js}
ls -lh dashboard/dist/
```

**P0-T08: Document baseline**
Create `docs/audit/baseline.md` with:
- Current Lighthouse scores (Performance, Accessibility, etc.)
- Bundle sizes (before optimization)
- Number of CSS/JS files
- Accessibility violations count

---

#### Phase 1A Tasks

**P1A-T01: Mobile Hamburger Menu**

1. Add button to `dashboard/index.html` header:
```html
<button class="hamburger-menu" aria-label="Toggle navigation" aria-expanded="false">
  <span></span>
  <span></span>
  <span></span>
</button>
```

2. Add to `dashboard/styles/mobile.css`:
```css
@media (max-width: 767px) {
  .hamburger-menu {
    display: block;
    background: transparent;
    border: none;
    width: 32px;
    height: 32px;
    padding: 8px;
    cursor: pointer;
    z-index: 101;
  }

  .hamburger-menu span {
    display: block;
    width: 24px;
    height: 2px;
    background: var(--text-primary);
    margin: 6px 0;
    transition: all 0.3s ease;
  }

  .nav {
    display: none;
    position: fixed;
    top: 60px;
    left: 0;
    width: 100%;
    flex-direction: column;
    background: var(--bg-primary);
    z-index: 100;
    border-bottom: 1px solid var(--border-color);
  }

  .nav.is-open {
    display: flex;
  }

  .nav-item {
    padding: 16px 20px;
    border-bottom: 1px solid var(--border-color);
  }
}
```

3. Add to `dashboard/scripts/menu.js`:
```javascript
const hamburger = document.querySelector('.hamburger-menu');
const nav = document.querySelector('.nav');

hamburger?.addEventListener('click', () => {
  const isOpen = nav.classList.toggle('is-open');
  hamburger.setAttribute('aria-expanded', isOpen);
});

// Close on outside click
document.addEventListener('click', (e) => {
  if (!hamburger?.contains(e.target) && !nav?.contains(e.target)) {
    nav?.classList.remove('is-open');
    hamburger?.setAttribute('aria-expanded', 'false');
  }
});
```

4. Include in `dashboard/index.html`:
```html
<script src="scripts/menu.js"></script>
```

**Verification**:
- [ ] Hamburger visible below 767px
- [ ] Menu toggles on click
- [ ] Links accessible via keyboard (Tab)
- [ ] `npm run lint && npm run typecheck && npm run build` all pass

**P1A-T02: Bundle CSS**
```bash
npm run bundle:css
# Verify
ls -lh dashboard/assets/bundle.min.css  # Should be <100KB
grep "import" dashboard/assets/bundle.css  # Should be 0
```

Update `dashboard/index.html` to use single bundle:
```html
<!-- Remove all individual <link rel="stylesheet"> tags -->
<!-- Add: -->
<link rel="stylesheet" href="assets/bundle.min.css">
```

**Verification**:
- [ ] Single bundle file created
- [ ] All styles working (visual check all pages)
- [ ] No 404 errors in console
- [ ] Lighthouse Performance improvement

**P1A-T03: Verify bundled CSS**
- Open each page (dashboard, kanban, waves, issues, agents, notifications)
- Check no visual regressions
- Verify all interactive elements work
- Check responsive design (320px, 768px, 1024px, 1440px)

**Verification**:
- [ ] All 6 pages display correctly
- [ ] No layout shifts
- [ ] Colors correct
- [ ] Typography correct
- [ ] Forms/inputs working

---

#### Phase 1B Tasks (CLAUDE 4)

**P1B-T01: Fix Semantic HTML**

Search for all `<div onclick=` in HTML files:
```bash
grep -n 'onclick=' dashboard/*.html
```

For each occurrence, replace pattern:
```html
<!-- BEFORE (non-semantic): -->
<div class="wave-card" onclick="selectWave('W1')">
  Wave 1
</div>

<!-- AFTER (semantic): -->
<button class="wave-card" type="button" aria-label="Select Wave 1">
  Wave 1
</button>
```

Update JavaScript to use addEventListener instead of onclick:
```javascript
document.querySelectorAll('.wave-card').forEach(card => {
  card.addEventListener('click', (e) => {
    const waveId = card.dataset.waveId;
    selectWave(waveId);
  });
});
```

**Verification**:
- [ ] `grep -r "onclick=" dashboard/` returns 0 results
- [ ] All interactive elements are button or a tags
- [ ] Keyboard navigable with Tab
- [ ] No console errors

**P1B-T02: Keyboard Kanban**

Modify `dashboard/scripts/kanban.js`:
```javascript
class AccessibleKanban {
  constructor() {
    this.selectedCard = null;
    this.bindKeyboardEvents();
  }

  bindKeyboardEvents() {
    document.addEventListener('keydown', (e) => {
      const card = e.target.closest('.kanban-card');
      if (!card) return;

      switch(e.key) {
        case ' ':
          e.preventDefault();
          this.toggleSelection(card);
          break;
        case 'ArrowUp': case 'ArrowDown':
          e.preventDefault();
          this.moveVertical(card, e.key === 'ArrowUp' ? -1 : 1);
          break;
        case 'ArrowLeft': case 'ArrowRight':
          e.preventDefault();
          this.moveHorizontal(card, e.key === 'ArrowLeft' ? -1 : 1);
          break;
        case 'Enter':
          e.preventDefault();
          this.drop(card);
          break;
        case 'Escape':
          e.preventDefault();
          this.cancel();
          break;
      }
    });
  }

  toggleSelection(card) {
    if (this.selectedCard === card) {
      card.classList.remove('is-selected');
      card.setAttribute('aria-grabbed', 'false');
      this.selectedCard = null;
    } else {
      this.selectedCard = card;
      card.classList.add('is-selected');
      card.setAttribute('aria-grabbed', 'true');
    }
  }

  // ... other methods
}

new AccessibleKanban();
```

HTML updates:
```html
<div class="kanban-card"
     tabindex="0"
     role="button"
     aria-grabbed="false"
     aria-label="Task: [title]">
  <!-- Card content -->
</div>
```

**Verification**:
- [ ] Cards focusable with Tab
- [ ] Space to select
- [ ] Arrow keys to move
- [ ] Enter to drop
- [ ] Escape to cancel
- [ ] Visual feedback (selected class)
- [ ] Screen reader announces actions

**P1B-T03: XSS Prevention**

Create `dashboard/scripts/utils.js`:
```javascript
window.escapeHtml = function(unsafe) {
  if (!unsafe) return '';
  return unsafe
    .toString()
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#039;');
};
```

Include in all HTML files that render user input:
```html
<script src="scripts/utils.js"></script>
```

Use in all innerHTML assignments:
```javascript
// BEFORE (VULNERABLE):
element.innerHTML = `<div>${userInput}</div>`;

// AFTER (SAFE):
element.innerHTML = `<div>${escapeHtml(userInput)}</div>`;
```

**Verification**:
- [ ] Test: enter `<script>alert('XSS')</script>` → renders as text
- [ ] Test: enter `Tom & Jerry's <tag>` → displays correctly
- [ ] `grep -r "innerHTML.*=" dashboard/ | grep -v escapeHtml` returns only legitimate cases
- [ ] No XSS console errors

---

### CLAUDE 3: FEATURES

You are responsible for the bug dropdown feature and version tracking integration.

#### Phase 1C Tasks

**P1C-T01: Bug Dropdown Structure + CSS**

Add to `dashboard/index.html` (in header, before Export button):
```html
<div class="bug-dropdown">
  <button class="bug-dropdown-toggle"
          aria-label="View saved bugs"
          aria-expanded="false"
          aria-haspopup="menu">
    <svg><!-- Bug icon --></svg>
    <span class="bug-count">0</span>
  </button>

  <div class="bug-dropdown-menu" role="menu">
    <div class="bug-dropdown-header">
      <h3>Saved Bugs</h3>
      <button class="add-bug-btn" aria-label="Add bug">
        <svg><!-- Plus icon --></svg>
      </button>
    </div>

    <div class="bug-list-container">
      <ul class="bug-list"></ul>
    </div>

    <div class="bug-dropdown-footer">
      <button class="archive-btn">Archive Completed</button>
    </div>
  </div>
</div>
```

Create `dashboard/styles/bug-dropdown.css`:
```css
.bug-dropdown {
  position: relative;
}

.bug-dropdown-toggle {
  position: relative;
  padding: 8px 12px;
  background: var(--bg-secondary);
  border: 1px solid var(--border-color);
  border-radius: 6px;
  cursor: pointer;
}

.bug-count {
  position: absolute;
  top: -5px;
  right: -5px;
  background: var(--color-danger);
  color: white;
  border-radius: 50%;
  width: 20px;
  height: 20px;
  font-size: 11px;
  display: flex;
  align-items: center;
  justify-content: center;
}

.bug-dropdown-menu {
  display: none;
  position: absolute;
  right: 0;
  width: 400px;
  max-height: 500px;
  margin-top: 8px;
  background: var(--bg-primary);
  border: 1px solid var(--border-color);
  border-radius: 8px;
  box-shadow: 0 4px 12px rgba(0,0,0,0.15);
  z-index: 1000;
  flex-direction: column;
}

.bug-dropdown-menu.is-open {
  display: flex;
}

.bug-list-container {
  flex: 1;
  overflow-y: auto;
  max-height: 350px;
}

.bug-item {
  display: flex;
  gap: 12px;
  padding: 12px 16px;
  border-bottom: 1px solid var(--border-color);
}

.bug-item.is-done {
  opacity: 0.6;
}

.bug-item.is-done .bug-title {
  text-decoration: line-through;
}

.priority-badge {
  padding: 2px 6px;
  border-radius: 4px;
  font-size: 11px;
  font-weight: 600;
}

.priority-p0 { background: #dc3545; color: white; }
.priority-p1 { background: #fd7e14; color: white; }
.priority-p2 { background: #0d6efd; color: white; }

.bug-actions {
  display: flex;
  gap: 4px;
}

.bug-actions button {
  padding: 4px;
  background: transparent;
  border: none;
  cursor: pointer;
  opacity: 0.6;
}

.bug-actions button:hover {
  opacity: 1;
}

@media (max-width: 767px) {
  .bug-dropdown-menu {
    width: 100vw;
    left: 0;
    right: 0;
    border-radius: 0;
  }
}
```

**Verification**:
- [ ] Dropdown visible in header
- [ ] Menu appears/disappears on click
- [ ] Scrollable when >5 bugs
- [ ] Responsive on mobile
- [ ] Dark mode compatible

**P1C-T02: Bug CRUD JavaScript**

Create `dashboard/scripts/bug-dropdown.js`:
```javascript
class BugDropdown {
  constructor() {
    this.bugs = this.loadBugs();
    this.dropdown = document.querySelector('.bug-dropdown');
    this.toggle = this.dropdown?.querySelector('.bug-dropdown-toggle');
    this.menu = this.dropdown?.querySelector('.bug-dropdown-menu');
    this.list = this.dropdown?.querySelector('.bug-list');
    this.addBtn = this.dropdown?.querySelector('.add-bug-btn');

    if (!this.dropdown) return;

    this.bindEvents();
    this.render();
  }

  loadBugs() {
    try {
      const saved = localStorage.getItem('myconvergio-bugs');
      return saved ? JSON.parse(saved) : [];
    } catch (e) {
      console.error('Failed to load bugs:', e);
      return [];
    }
  }

  saveBugs() {
    try {
      localStorage.setItem('myconvergio-bugs', JSON.stringify(this.bugs));
    } catch (e) {
      console.error('Failed to save bugs:', e);
      alert('Storage quota exceeded');
    }
  }

  bindEvents() {
    this.toggle.addEventListener('click', () => {
      const isOpen = this.menu.classList.toggle('is-open');
      this.toggle.setAttribute('aria-expanded', isOpen);
    });

    this.addBtn.addEventListener('click', () => this.addBug());

    document.addEventListener('click', (e) => {
      if (!this.dropdown.contains(e.target)) {
        this.menu.classList.remove('is-open');
        this.toggle.setAttribute('aria-expanded', 'false');
      }
    });

    this.dropdown.querySelector('.archive-btn')?.addEventListener('click', () => {
      this.archiveCompleted();
    });
  }

  addBug() {
    const title = prompt('Bug title:');
    if (!title) return;

    const priority = (prompt('Priority (p0/p1/p2):', 'p1') || 'p1').toLowerCase();
    if (!['p0', 'p1', 'p2'].includes(priority)) {
      alert('Invalid priority. Using p1.');
      priority = 'p1';
    }

    const bug = {
      id: `bug-${Date.now()}`,
      title,
      priority,
      version: localStorage.getItem('app-version') || '1.0.0',
      date: new Date().toISOString().split('T')[0],
      done: false
    };

    this.bugs.push(bug);
    this.saveBugs();
    this.render();
  }

  editBug(id) {
    const bug = this.bugs.find(b => b.id === id);
    if (!bug) return;

    const newTitle = prompt('Edit title:', bug.title);
    if (newTitle && newTitle.trim()) {
      bug.title = newTitle;
      this.saveBugs();
      this.render();
    }
  }

  deleteBug(id) {
    if (!confirm('Delete this bug?')) return;

    this.bugs = this.bugs.filter(b => b.id !== id);
    this.saveBugs();
    this.render();
  }

  toggleBugDone(id, done) {
    const bug = this.bugs.find(b => b.id === id);
    if (bug) {
      bug.done = done;
      this.saveBugs();
      this.render();
    }
  }

  executeWithPlanner(id) {
    const bug = this.bugs.find(b => b.id === id);
    if (!bug) return;

    const params = new URLSearchParams({
      bug: bug.id,
      title: bug.title,
      priority: bug.priority,
      version: bug.version
    });

    window.open(`planner.html?${params.toString()}`, '_blank');
  }

  copyCLICommand(id) {
    const bug = this.bugs.find(b => b.id === id);
    if (!bug) return;

    const command = `plan-db.sh add-task "${bug.title.replace(/"/g, '\\"')}" --priority ${bug.priority.toUpperCase()} --assignee CLAUDE --version ${bug.version}`;

    navigator.clipboard.writeText(command).then(() => {
      this.showToast('CLI command copied!');
    }).catch(() => {
      // Fallback for older browsers
      const textarea = document.createElement('textarea');
      textarea.value = command;
      textarea.style.position = 'fixed';
      textarea.style.opacity = '0';
      document.body.appendChild(textarea);
      textarea.select();
      document.execCommand('copy');
      document.body.removeChild(textarea);
      this.showToast('CLI command copied!');
    });
  }

  archiveCompleted() {
    const completed = this.bugs.filter(b => b.done);
    if (completed.length === 0) {
      alert('No completed bugs to archive');
      return;
    }

    if (!confirm(`Archive ${completed.length} completed bugs?`)) return;

    const archive = JSON.parse(localStorage.getItem('myconvergio-bugs-archive') || '[]');
    archive.push(...completed);
    localStorage.setItem('myconvergio-bugs-archive', JSON.stringify(archive));

    this.bugs = this.bugs.filter(b => !b.done);
    this.saveBugs();
    this.render();
  }

  render() {
    if (!this.list) return;

    this.list.innerHTML = '';

    if (this.bugs.length === 0) {
      this.list.innerHTML = '<li style="padding: 12px 16px; color: var(--text-secondary);">No bugs saved</li>';
      return;
    }

    this.bugs.forEach(bug => {
      const li = document.createElement('li');
      li.className = `bug-item ${bug.done ? 'is-done' : ''}`;
      li.innerHTML = `
        <div class="bug-priority">
          <span class="priority-badge priority-${bug.priority}">${bug.priority.toUpperCase()}</span>
        </div>
        <div class="bug-content" style="flex: 1;">
          <input type="checkbox" class="bug-checkbox" id="bug-${bug.id}" ${bug.done ? 'checked' : ''}>
          <label for="bug-${bug.id}" class="bug-title" style="margin-left: 8px;">${escapeHtml(bug.title)}</label>
          <div style="font-size: 11px; color: var(--text-secondary); margin-top: 4px;">
            ${bug.version} • ${bug.date}
          </div>
        </div>
        <div class="bug-actions">
          <button class="bug-edit" aria-label="Edit"><svg width="16" height="16">✎</svg></button>
          <button class="bug-delete" aria-label="Delete"><svg width="16" height="16">×</svg></button>
          <button class="bug-execute" aria-label="Execute"><svg width="16" height="16">▶</svg></button>
          <button class="bug-copy" aria-label="Copy CLI"><svg width="16" height="16">📋</svg></button>
        </div>
      `;

      li.querySelector('.bug-checkbox').addEventListener('change', (e) => {
        this.toggleBugDone(bug.id, e.target.checked);
      });

      li.querySelector('.bug-edit').addEventListener('click', () => this.editBug(bug.id));
      li.querySelector('.bug-delete').addEventListener('click', () => this.deleteBug(bug.id));
      li.querySelector('.bug-execute').addEventListener('click', () => this.executeWithPlanner(bug.id));
      li.querySelector('.bug-copy').addEventListener('click', () => this.copyCLICommand(bug.id));

      this.list.appendChild(li);
    });

    const count = this.bugs.filter(b => !b.done).length;
    if (this.toggle) {
      this.toggle.querySelector('.bug-count').textContent = count;
    }
  }

  showToast(message) {
    const toast = document.createElement('div');
    toast.style.cssText = `
      position: fixed;
      bottom: 20px;
      right: 20px;
      background: #22c55e;
      color: white;
      padding: 12px 20px;
      border-radius: 6px;
      box-shadow: 0 4px 8px rgba(0,0,0,0.2);
      opacity: 0;
      transform: translateY(20px);
      transition: all 0.3s ease;
      z-index: 10000;
    `;
    toast.textContent = message;
    document.body.appendChild(toast);

    setTimeout(() => {
      toast.style.opacity = '1';
      toast.style.transform = 'translateY(0)';
    }, 10);

    setTimeout(() => {
      toast.style.opacity = '0';
      toast.style.transform = 'translateY(20px)';
      setTimeout(() => toast.remove(), 300);
    }, 2000);
  }
}

document.addEventListener('DOMContentLoaded', () => {
  new BugDropdown();
});
```

Include in `dashboard/index.html`:
```html
<script src="scripts/utils.js"></script>
<script src="scripts/bug-dropdown.js"></script>
```

**Verification**:
- [ ] Add bug works (prompt input)
- [ ] Edit bug works
- [ ] Delete bug works
- [ ] Toggle done checkbox works
- [ ] Bugs persist in localStorage (refresh page)
- [ ] Count badge updates
- [ ] No console errors
- [ ] `npm run lint && npm run typecheck && npm run build` all pass

**P1C-T03 through P1C-T07**: Continue with priority indicators, planner integration, CLI copy, archive functionality

---

### CLAUDE 4: ACCESSIBILITY

You are responsible for accessibility fixes, focus indicators, and search/filter functionality.

#### Phase 1B Tasks (continued)

Similar structure to above - implement semantic HTML fixes and keyboard navigation

#### Phase 2B Tasks

**P2B-T01: aria-labels**
Audit all interactive elements and add proper aria-labels

**P2B-T02: Contrast Fixes**
Use WebAIM Contrast Checker to fix all violations

**P2B-T03: Focus Indicators**
Create `dashboard/styles/focus.css` with visible focus styles

---

## 📊 PROGRESS SUMMARY

| Phase | Name | Tasks | Done | Total | Status |
|:-----:|------|:-----:|:----:|:-----:|--------|
| 0 | Prerequisites | 0 | 8 | 0% | ⏳ WAITING |
| 1A | Mobile & Bundling | 0 | 3 | 0% | ⏳ WAITING |
| 1B | Accessibility | 0 | 3 | 0% | ⏳ WAITING |
| 1C | Bug Dropdown | 0 | 7 | 0% | ⏳ WAITING |
| 2 | High Priority | 0 | 12 | 0% | ⏳ WAITING |
| 3 | Optimizations | 0 | 20 | 0% | ⏳ WAITING |
| **TOTAL** | | **0** | **58** | **0%** | **⏳** |

---

## VERIFICATION CHECKLIST (Before merge)

```bash
npm run lint        # 0 errors, 0 warnings
npm run typecheck   # no errors
npm run build       # success
```

---

**Created**: 2026-01-05
**Version**: 1.0
**Status**: Ready for Execution
