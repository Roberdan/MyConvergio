# Migration Checklist
Rules for backend migrations (Python→Rust, framework changes, API rewrites).

## Pre-Migration
- [ ] Map ALL API endpoints and their response shapes
- [ ] Document JS render function input expectations
- [ ] Add ALL tables to init-db.sql (schema source of truth)
- [ ] Write real-server E2E tests (not mocked)

## During Migration  
- [ ] Per-endpoint: curl response → compare with JS expectations
- [ ] Run Playwright against REAL server after each batch of changes
- [ ] Test with production DB (not empty test DB)
- [ ] Verify DB migration runs on existing tables (ALTER TABLE, not just CREATE)

## Post-Migration
- [ ] Full Playwright navigation audit (every tab, button, overlay)
- [ ] Zero console errors (JS + network)
- [ ] Zero "Loading..." widgets remaining
- [ ] Health endpoint returns ok:true
- [ ] Write KB entries for every issue discovered
