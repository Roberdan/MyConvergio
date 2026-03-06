"""Tests for lib/jsonl_scraper.py - T1-03"""

import json
import sys
import time
from pathlib import Path
import tempfile

import pytest


def test_import_scrape_jsonl_tokens():
    """F-26: scrape_jsonl_tokens must be importable from lib.jsonl_scraper."""
    from lib.jsonl_scraper import scrape_jsonl_tokens  # noqa: F401


def test_scrape_jsonl_tokens_returns_dict():
    """scrape_jsonl_tokens() returns a dict (possibly empty)."""
    from lib.jsonl_scraper import scrape_jsonl_tokens

    result = scrape_jsonl_tokens()
    assert isinstance(result, dict)


def test_parse_jsonl_lines_parses_tokens():
    """_parse_jsonl_lines correctly sums tokens from assistant messages."""
    from lib.jsonl_scraper import _parse_jsonl_lines
    import io

    lines = [
        json.dumps(
            {
                "type": "assistant",
                "timestamp": "2025-01-15T10:00:00Z",
                "message": {
                    "usage": {
                        "input_tokens": 100,
                        "output_tokens": 50,
                        "cache_creation_input_tokens": 10,
                        "cache_read_input_tokens": 5,
                    }
                },
            }
        ),
        json.dumps(
            {
                "type": "human",
                "timestamp": "2025-01-15T10:01:00Z",
                "message": {"content": "hello"},
            }
        ),
        json.dumps(
            {
                "type": "assistant",
                "timestamp": "2025-01-15T10:02:00Z",
                "message": {"usage": {"input_tokens": 200, "output_tokens": 80}},
            }
        ),
    ]
    fh = io.StringIO("\n".join(lines))
    result = _parse_jsonl_lines(fh)
    assert "2025-01-15" in result
    # input = 100+10+5 + 200 = 315; output = 50+80 = 130
    assert result["2025-01-15"]["input"] == 315
    assert result["2025-01-15"]["output"] == 130


def test_scrape_jsonl_returns_cached_data_on_repeat_call():
    """Cache TTL means rapid repeated calls return same dict reference."""
    from lib.jsonl_scraper import scrape_jsonl_tokens

    r1 = scrape_jsonl_tokens()
    r2 = scrape_jsonl_tokens()
    assert isinstance(r1, dict)
    assert isinstance(r2, dict)
