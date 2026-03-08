#!/usr/bin/env python3
"""Migration 007: create chat_sessions, chat_messages, chat_requirements tables."""

from __future__ import annotations

import sys
from pathlib import Path

if __package__ in (None, ""):
    sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
    from scripts.dashboard_web.lib.chat_db import (  # pylint: disable=import-error
        DB_PATH,
        list_missing_chat_tables,
        ensure_chat_schema,
    )
else:
    from ..dashboard_web.lib.chat_db import DB_PATH, list_missing_chat_tables, ensure_chat_schema


def main() -> int:
    ensure_chat_schema(DB_PATH)
    missing = list_missing_chat_tables(DB_PATH)
    if missing:
        print(f"[ERROR] Missing chat tables after migration: {', '.join(missing)}")
        return 1
    print(f"[OK] Chat schema migration complete: {DB_PATH}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
