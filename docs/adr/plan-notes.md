# Plan 115: InterWaveCommunication - Running Notes

## W1: Schema Migration

- Decision: TEXT libre for executor_agent (no CHECK constraint) — allows future agents without migration
- Decision: nullable precondition JSON on waves — NULL means always execute (backward compatible)
- Decision: ALTER TABLE + init-db-v4.sql dual approach for migration + fresh installs
