# Migration & Architecture Change Checklist
Rules for ANY change that touches infrastructure: backend migrations, new services, schema changes, mesh topology.

## Holistic Impact Analysis (MANDATORY before planning)
- [ ] **Mesh nodes**: Does this change need deploying to ALL nodes? Binary, config, schema?
- [ ] **Legacy scripts**: Which existing scripts/hooks become obsolete? Which need updating?
- [ ] **DB schema**: Is init-db.sql updated? Are remote node DBs compatible?
- [ ] **Sync pipeline**: Does db-pull/autosync/mesh-heartbeat still work or break?
- [ ] **Frontend contract**: Do API response shapes match JS render functions?
- [ ] **Daemon lifecycle**: Which daemons need restart/redeploy across the mesh?
- [ ] **IF IN DOUBT → ASK THE USER.** Don't assume scope, ask.

## Pre-Migration
- [ ] Map ALL API endpoints and their response shapes
- [ ] Add ALL tables to init-db.sql + init-db-migrate.sql
- [ ] Write real-server E2E tests (not mocked)
- [ ] Inventory scripts/hooks affected — mark obsolete vs needs-update

## During Migration  
- [ ] Per-endpoint: curl response → compare with JS expectations
- [ ] Run Playwright against REAL server after each batch
- [ ] Test with production DB (not empty test DB)
- [ ] Verify on remote nodes (SSH + test), not just local

## Post-Migration
- [ ] Full Playwright navigation audit — zero errors
- [ ] Deploy binary/config to ALL mesh nodes
- [ ] Start/restart daemons on ALL nodes
- [ ] Disable/archive obsolete scripts
- [ ] Health endpoint returns ok:true on ALL nodes
- [ ] Write KB entries for every issue discovered
