# Migrating from MyConvergio v10 to v11

## What's New in v11
- Expanded guardrails with a full operational baseline: hooks increased from 2 to 13.
- New rules and enforcement modules were added to standardize workflows and quality gates.
- Installation and bootstrap flow were updated for stronger safety checks and clearer setup paths.
- Agent assets and routing definitions were reorganized, with larger curated reference packs.
- Versioning format was normalized for stricter policy alignment and migration traceability.

## What Breaks
| Component | v10 Behavior | v11 Behavior | Action Required |
| --- | --- | --- | --- |
| Hooks | Minimal hook set (2 hooks) | Extended hook suite (13 hooks) with stricter enforcement | Review local workflow scripts and align to new hook expectations before daily use |
| Rules | Smaller baseline rule set | New rule modules and mandatory workflow constraints | Read updated rules and remove any local bypass assumptions |
| Install flow | Simpler setup path with fewer pre-checks | Hardened install/migration path with validation and safety steps | Use official migration script and run health checks after migration |
| Agent sizes | Leaner agent/reference footprint | Larger structured agent and reference inventories | Ensure local environment has capacity and sync all required agent files |
| VERSION format | Legacy version conventions accepted | Standardized version policy and stricter format interpretation | Update internal tooling/scripts that parse VERSION values |

## Prerequisites
- Backup tool installed (included in v10.7.0+)
- gh CLI authenticated
- ~500MB free disk for backup

## Step-by-Step Migration

### 1. Backup (MANDATORY)
```bash
myconvergio backup
# or: ./scripts/myconvergio-backup.sh
```

### 2. Run Migration
```bash
./scripts/migrate-v10-to-v11.sh
# or: ./scripts/migrate-v10-to-v11.sh --dry-run  (preview first)
```

### 3. Verify
```bash
myconvergio doctor
```

## Rollback (If Something Goes Wrong)
```bash
myconvergio rollback
# or: ./scripts/myconvergio-restore.sh --latest --full
```

## Troubleshooting
| Problem | Cause | Fix |
| --- | --- | --- |
| Migration script stops with backup error | No valid backup detected or backup tool missing | Run `myconvergio backup` first, then rerun migration |
| Doctor reports failed checks after migration | Partial migration or local overrides conflicting with v11 rules/hooks | Re-run migration with `--dry-run` to inspect changes, then execute full run again |
| Hook-related commands fail unexpectedly | Local scripts rely on v10 two-hook assumptions | Update local automation to support v11 hook suite and re-test |
| Version parsing errors in custom scripts | Custom tooling expects legacy VERSION format | Update regex/parser logic to v11 versioning policy and retry |
| Restore does not recover expected state | Wrong backup snapshot selected | Run `./scripts/myconvergio-restore.sh --latest --full` or choose the correct backup explicitly |

## FAQ
- **Q: Will I lose my custom agents?**  
  **A:** No. The migration preserves custom agents and user customizations while updating core framework assets.
- **Q: What about my plan database?**  
  **A:** It is backed up separately with integrity checks as part of the migration safety flow.
- **Q: Can I skip the backup?**  
  **A:** No. Migration is designed to refuse execution without a valid backup.
