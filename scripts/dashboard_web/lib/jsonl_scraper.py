"""JSONL token scraper for Claude session files.

Reads ~/.claude/projects/*/session.jsonl files and merges token data
into the daily token view as a supplement to the DB records.
"""

import json
import threading
import time
from collections import defaultdict
from pathlib import Path


_jsonl_cache: dict = {"data": {}, "ts": 0, "file_state": {}}
_JSONL_CACHE_TTL = 600  # JSONL is a fallback supplement; DB hooks are primary
_jsonl_lock = threading.Lock()
_jsonl_bg_running = False


def _parse_jsonl_lines(fh) -> dict[str, dict]:
    """Parse token usage from JSONL lines. Returns {date: {input, output}}."""
    daily: dict[str, dict] = defaultdict(lambda: {"input": 0, "output": 0})
    for line in fh:
        try:
            obj = json.loads(line)
        except (json.JSONDecodeError, ValueError):
            continue
        if obj.get("type") != "assistant":
            continue
        msg = obj.get("message")
        if not isinstance(msg, dict):
            continue
        usage = msg.get("usage")
        if not usage:
            continue
        ts = obj.get("timestamp", "")
        if len(ts) < 10:
            continue
        day = ts[:10]
        inp = (
            usage.get("input_tokens", 0)
            + usage.get("cache_creation_input_tokens", 0)
            + usage.get("cache_read_input_tokens", 0)
        )
        out = usage.get("output_tokens", 0)
        daily[day]["input"] += inp
        daily[day]["output"] += out
    return dict(daily)


def _scrape_jsonl_tokens_sync() -> dict[str, dict]:
    """Internal: do the actual JSONL scan (called from background thread)."""
    base = Path.home() / ".claude" / "projects"
    if not base.exists():
        return _jsonl_cache.get("data") or {}

    now = time.time()
    cutoff = now - 35 * 86400
    prev_state: dict = _jsonl_cache.get("file_state", {})
    merged: dict[str, dict] = defaultdict(lambda: {"input": 0, "output": 0})

    prev_file_data: dict = _jsonl_cache.get("file_data", {})

    current_files: set[str] = set()
    new_file_state: dict = {}
    new_file_data: dict = {}

    for jsonl_path in base.rglob("*.jsonl"):
        try:
            st = jsonl_path.stat()
            if st.st_mtime < cutoff:
                continue
        except (OSError, PermissionError):
            continue

        key = str(jsonl_path)
        current_files.add(key)
        prev = prev_state.get(key)
        cur_mtime = st.st_mtime
        cur_size = st.st_size

        if prev and prev["mtime"] == cur_mtime and prev["size"] == cur_size:
            new_file_state[key] = prev
            if key in prev_file_data:
                new_file_data[key] = prev_file_data[key]
            continue

        try:
            if prev and cur_size >= prev["size"] and prev.get("offset", 0) > 0:
                with open(jsonl_path, "r", encoding="utf-8", errors="ignore") as fh:
                    fh.seek(prev["offset"])
                    new_daily = _parse_jsonl_lines(fh)
                    new_offset = fh.tell()
                file_daily = dict(prev_file_data.get(key, {}))
                for day, vals in new_daily.items():
                    if day in file_daily:
                        file_daily[day] = {
                            "input": file_daily[day]["input"] + vals["input"],
                            "output": file_daily[day]["output"] + vals["output"],
                        }
                    else:
                        file_daily[day] = vals
            else:
                with open(jsonl_path, "r", encoding="utf-8", errors="ignore") as fh:
                    file_daily = _parse_jsonl_lines(fh)
                    new_offset = fh.tell()

            new_file_state[key] = {
                "mtime": cur_mtime,
                "size": cur_size,
                "offset": new_offset,
            }
            new_file_data[key] = file_daily
        except (OSError, PermissionError):
            continue

    for key in current_files:
        fd = new_file_data.get(key, prev_file_data.get(key, {}))
        if fd:
            new_file_data.setdefault(key, fd)
            for day, vals in fd.items():
                merged[day]["input"] += vals["input"]
                merged[day]["output"] += vals["output"]

    result = dict(merged)
    with _jsonl_lock:
        _jsonl_cache.update(
            {
                "data": result,
                "ts": time.time(),
                "file_state": new_file_state,
                "file_data": new_file_data,
            }
        )
    return result


def _scrape_jsonl_bg():
    """Run JSONL scan in background thread — never blocks HTTP."""
    global _jsonl_bg_running
    try:
        _scrape_jsonl_tokens_sync()
    finally:
        _jsonl_bg_running = False


def scrape_jsonl_tokens() -> dict[str, dict]:
    """Non-blocking JSONL scraper. Returns cached data immediately;
    triggers background refresh if cache is stale."""
    global _jsonl_bg_running
    now = time.time()
    with _jsonl_lock:
        if _jsonl_cache["data"] and (now - _jsonl_cache["ts"]) < _JSONL_CACHE_TTL:
            return _jsonl_cache["data"]
    # Cache stale — kick off background scan, return stale data immediately
    if not _jsonl_bg_running:
        _jsonl_bg_running = True
        threading.Thread(target=_scrape_jsonl_bg, daemon=True).start()
    return _jsonl_cache.get("data") or {}
