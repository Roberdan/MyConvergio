# SECURITY AUDIT: Super Mesh AI System (Plan 599)
## Executive Summary

**Date**: 2026-03-09  
**Audit Type**: Architecture & Code Security Review  
**System**: Distributed Mesh Coordinator with CRDT Replication  
**Status**: ⚠️ **CRITICAL VULNERABILITIES FOUND** — Fix Required Before Production

---

## Remediation Status (Updated: Plan 601, March 2026)

| Finding | Original Severity | Status | Resolution |
|---------|------------------|--------|------------|
| Zero authentication on all routes | Critical | ✅ Fixed | Bearer token auth added (Plan 601 W1) |
| CORS allow_origin(Any) | Critical | ✅ Fixed | CORS allowlist from env var (Plan 601 W1) |
| PTY unauthenticated + libc::fork | Critical | ✅ Fixed | Auth + tokio::process::Command (Plan 601 W1) |
| Mutating GET routes | Medium | ✅ Fixed | Converted to POST (Plan 601 W1) |
| No timeouts/rate limits | High | ✅ Fixed | TimeoutLayer 30s + rate limiting (Plan 601 W1) |
| XSS sinks (innerHTML) | Medium | ⚠️ Partial | esc() added to peer-crud, brain-canvas. Full audit pending. |
| Missing mesh routes (logs/metrics/sync-stats) | High | ✅ Fixed | Proxy routes to daemon (Plan 601 W2) |
| CRDT test failures | High | ✅ Fixed | Test assertions updated (Plan 601 W2) |
| Playwright failures (18) | High | ✅ Fixed | All 231 tests passing (Plan 601 W2) |

---

## FINDINGS AT A GLANCE

| Severity | Count | Examples |
|----------|-------|----------|
| 🔴 **CRITICAL** | 3 | Unauthenticated TCP daemon (port 9420), SQL injection in shell scripts, No SSH host key verification |
| 🟠 **HIGH** | 5 | Cleartext credentials, No frame authentication, Missing WebSocket auth, No rate limiting, Replay attacks |
| 🟡 **MEDIUM** | 8 | Peer registry integrity, Clock skew, Unbounded change logs, insufficient logging |
| 🟢 **LOW** | 4 | Unwrap panics, History leakage, Long heartbeat interval, No graceful shutdown |

**Total Issues**: 20 | **Fixable**: 100%

---

## CRITICAL VULNERABILITIES (Must Fix)

### 1. **Unauthenticated Mesh TCP Daemon (Port 9420)**
- **Risk**: Any attacker on network can inject malicious database changes → mesh-wide compromise
- **Proof**: Send crafted `MeshSyncFrame::Delta` → inserts backdoor records into `plans` table
- **Fix**: Add TLS 1.3 + certificate pinning
- **Timeline**: 1 week
- **Impact if unfixed**: CRITICAL — Remote code execution on all peers

### 2. **SQL Injection in mesh-coordinator.sh**
- **Risk**: Attacker adds malicious peer → coordinator executes arbitrary SQL
- **Proof**: `ssh_alias=test' UNION SELECT...` → SQL error + data extraction
- **Fix**: Use parameterized queries instead of string interpolation
- **Timeline**: 2 days
- **Impact if unfixed**: Plan execution redirection, task stealing

### 3. **No SSH Host Key Verification**
- **Risk**: Man-in-the-middle attack on peer authentication → RCE
- **Proof**: Attacker intercepts SSH → accepts with fake key → executes `/execute`
- **Fix**: Require host key verification or IP whitelist
- **Timeline**: 2 days
- **Impact if unfixed**: Database exfiltration, lateral movement to other peers

---

## HIGH-RISK VULNERABILITIES (Strongly Recommended)

1. **Cleartext Credentials** in config files (sync-db.conf, notifications.conf)
2. **No Frame Authentication/MAC** → allows frame modification in transit
3. **Missing WebSocket Auth** → unauthenticated /ws/brain access reveals topology
4. **No Rate Limiting** → TCP daemon can be exhausted with thousands of connections
5. **No Replay Protection** → same Delta frame can be applied multiple times

---

## ARCHITECTURE SUMMARY

### Mesh Components:
- **Rust Daemon**: TCP listener on port 9420, accepts MeshSyncFrame (Heartbeat/Delta/Ack)
- **CRDT Sync**: CRSQLite changelog-based replication across 3 peers (m3max, omarchy, m1mario)
- **JavaScript Dashboard**: WebSocket client for real-time peer status + plan delegation
- **Shell Scripts**: Orchestration (mesh-sync.sh, mesh-coordinator.sh, etc.)
- **Database**: SQLite with 100+ CRDT-enabled tables

### Positive Security Controls Already Present:
✅ Frame size limit (16 MB)  
✅ TCP keepalive tuning  
✅ SSH agent authentication (not hardcoded keys)  
✅ Tailscale network-layer encryption  
✅ No AUTOINCREMENT in CRDT tables  
✅ Transaction safety via WAL mode  

---

## IMMEDIATE ACTION ITEMS (Priority)

### Phase 1: CRITICAL (Week 1)
```
Week 1:
  - Implement TLS 1.3 on TCP daemon (port 9420) ← 3-4 days
  - Fix SQL injection in shell scripts ← 2 days
  - Add peer host key verification ← 2 days
  - Deploy firewall rules: TCP 9420 → Tailscale subnet only
```

### Phase 2: HIGH (Week 2)
```
Week 2:
  - Add HMAC-SHA256 frame authentication ← 3 days
  - WebSocket bearer token auth ← 1 day
  - Rate limiting per peer ← 2 days
  - Encrypt config files ← 1 day
  - Replay protection (frame sequences) ← 2 days
```

### Phase 3: MEDIUM (Week 3+)
- Comprehensive audit logging
- CRDT changelog retention
- Shell history protection
- Graceful shutdown
- Unwrap/panic replacements

---

## RISK ASSESSMENT

### Current Risk: **VERY HIGH** ⚠️
- Unauthenticated network access → remote code execution
- SQL injection → plan execution redirection
- No peer authentication → compromised peers undetectable

### Risk After Phase 1 Fixes: **MEDIUM** ⚠️
- TLS + SSH key verification closes remote exploitation
- SQL injection fixed
- Remaining risks: input validation, rate limiting, audit logging

### Risk After All Phases: **LOW** ✅
- Enterprise-grade security posture
- Comprehensive audit trail
- Resilient to DoS, replay, tampering

---

## SECURITY TESTING RECOMMENDATIONS

**Before Deployment:**
1. ✅ TLS handshake verification (valid cert + chain validation)
2. ✅ SQL injection fuzzing (sqlmap on mesh-coordinator.sh)
3. ✅ Frame manipulation tests (corrupt Delta → should reject)
4. ✅ Replay attack simulation (capture frame → replay → should detect)
5. ✅ DoS load test (1000 concurrent connections → should not crash)
6. ✅ Peer topology leakage test (WebSocket without auth → should deny)

---

## DEPLOYMENT CHECKLIST

- [ ] TLS 1.3 enabled on port 9420 (self-signed or CA-signed)
- [ ] SQL injection patches applied to all shell scripts
- [ ] SSH host key verification enabled in handoff_ssh.rs
- [ ] Firewall: TCP 9420 restricted to Tailscale subnet (10.0.0.0/8 equivalent)
- [ ] peers.conf read-only permissions (0400)
- [ ] peers.conf integrity: HMAC-SHA256 sidecar file
- [ ] WebSocket /ws/brain requires Authorization: Bearer header
- [ ] Rate limiter: max 100 concurrent peers, 100 frames/sec per peer
- [ ] Frame deduplication: sequence numbers tracked per peer
- [ ] Audit logging enabled: all frame receipts + errors logged
- [ ] CRDT changelog retention: keep last 100K versions only
- [ ] Secrets encrypted: REMOTE_HOST, bot_token, OAuth tokens
- [ ] Documentation updated with new TLS requirements
- [ ] Team trained on secure operations + security incidents response

---

## COMPLIANCE NOTES

**Alignment with Security Standards:**
- ❌ Does NOT meet OWASP Top 10 baseline (authentication, injection)
- ❌ Does NOT meet NIST Cybersecurity Framework (no MFA, limited logging)
- ✅ **After Phase 1-2 fixes**: Aligns with OWASP + NIST basics

**Regulatory Considerations:**
- If processing PII: GDPR/CCPA may require encrypted credential storage
- If processing health data: HIPAA requires audit logging (implement Phase 3)
- If SOC 2 scoped: Require penetration testing + formal threat model

---

## ESTIMATED EFFORT & TIMELINE

| Phase | Focus | Effort | Duration | Go/No-Go |
|-------|-------|--------|----------|----------|
| **Phase 1** | TLS, SQL injection, SSH verification | 35 hrs | 5 days | **MUST FIX** |
| **Phase 2** | Frame auth, WebSocket, rate limiting, replay | 40 hrs | 5 days | Strongly recommended |
| **Phase 3** | Logging, cleanup, hardening | 30 hrs | 3 days | Nice to have |
| **Testing** | Security regression, load, fuzzing | 20 hrs | 2 days | **MUST DO** |
| **Total** | All phases + testing | ~125 hrs | 2-3 weeks | To production readiness |

---

## CONTACTS & ESCALATION

- **Security Issues**: File as CRITICAL in issue tracker
- **Remediation Owner**: Roberto (lead)
- **Review Gate**: CTO sign-off after Phase 1 + Phase 2 completion
- **Next Audit**: 6 months post-deployment OR after adding new peers

---

## KEY FILES REVIEWED

**Rust Source** (1,765 LOC):
- daemon.rs (277 LOC) — TCP listener, connection handling
- sync.rs (341 LOC) — CRDT sync engine, frame processing
- handoff.rs (208 LOC) — Peer authentication, lock management
- handoff_ssh.rs (84 LOC) — SSH client, host key verification
- net.rs (112 LOC) — Tailscale integration, socket tuning
- daemon_sync.rs (291 LOC) — Frame I/O, rate limiting
- ws.rs (136 LOC) — WebSocket protocol

**Shell Scripts** (9 active):
- mesh-sync.sh — Peer synchronization (SQL injection risk)
- mesh-coordinator.sh — Task dispatch (SQL injection risk)
- mesh-heartbeat.sh — Liveness detection
- mesh-exec.sh — Remote execution

**Configuration**:
- peers.conf (56 lines) — Peer registry (no signature protection)
- sync-db.conf — Credentials (cleartext)
- orchestrator.yaml — Task routing

**Database**:
- dashboard.db — SQLite + CRSQLite (100+ tables, CRDT-enabled)
- mesh_sync_stats, mesh_events, peer_heartbeats (core mesh tables)

**Full Report**: `/Users/roberdan/.claude/SECURITY_AUDIT_MESH_599.md` (945 lines, 27KB)

---

**Audit Completed**: 2026-03-09  
**Next Review**: After Phase 1 fixes applied and tested

