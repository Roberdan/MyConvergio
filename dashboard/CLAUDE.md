# Dashboard - Claude Code Control Center

## Overview
Web dashboard for monitoring plans, tasks, waves, and notifications. Express server with SQLite backend.

## Entry Points
- `server.js` - Express API server (port 31415)
- `dashboard.html` - Single-page frontend
- `reboot.js` - PM2/standalone restart script

## Architecture

```
dashboard/
├── server.js              # Main Express server
├── server/                # API routes (modular)
│   ├── db.js              # SQLite connection + helpers
│   ├── routes-plans*.js   # Plan/wave/task CRUD
│   ├── routes-git*.js     # Git integration
│   ├── routes-github.js   # GitHub API proxy
│   ├── routes-notifications.js
│   └── routes-system.js   # Health, shutdown
├── js/                    # Frontend modules
│   ├── init.js            # App bootstrap
│   ├── state.js           # Global state management
│   ├── theme.js           # Theme switching (voltrex/midnight/frost/dawn)
│   ├── toast.js           # Toast notifications
│   ├── notifications.js   # Notification panel
│   ├── render.js          # Main render functions
│   ├── charts.js          # Chart.js integration
│   ├── gantt-*.js         # Gantt view (core/render/view)
│   ├── views-*.js         # View modes (kanban/waves/secondary)
│   ├── git-*.js           # Git panel components
│   ├── bug-*.js           # Bug tracker dropdown
│   └── drilldown.js       # Task detail modal
├── css/                   # Styles (modular)
│   ├── variables.css      # Theme variables (4 themes)
│   ├── layout.css         # Main layout
│   ├── simplified-nav.css # Top navigation + settings dropdown
│   ├── toast.css          # Toast notifications
│   └── [component].css    # Component-specific styles
└── data/                  # Runtime data (gitignored)
```

## Themes
Defined in `css/variables.css`:
- `voltrex` (default dark - purple)
- `midnight` (dark - navy/teal)
- `frost` (light - cool gray)
- `dawn` (light - warm cream)

Theme switching: `js/theme.js` sets `data-theme` attribute on `<html>`.
Light theme overrides needed in CSS files for `[data-theme="frost"]` and `[data-theme="dawn"]`.

## Key Patterns

### State Management
Global `window.state` object in `js/state.js`. Modules read/write directly.

### API Routes
All routes in `server/routes-*.js`, mounted in `server.js`.
Pattern: `GET/POST/PUT/DELETE /api/{resource}`.

### Toast Notifications
`js/toast.js` - `showToast(message, type, options)`.
Click handler navigates based on notification data.

### CSS Variables
All colors use CSS variables from `variables.css`.
Light themes need explicit overrides: `[data-theme="frost"]`, `[data-theme="dawn"]`.

## Database
SQLite at `~/.claude/data/dashboard.db`.
Tables: projects, plans, waves, tasks, notifications, triggers.

## Commands
```bash
~/.claude/server.sh start|stop|restart|status|logs
curl http://localhost:31415/api/health
```
