"""Tests for /api/tasks/blocked endpoint (TDD — RED before implementation)."""

import importlib.util
import sys
from pathlib import Path

# Load server module without running main()
spec = importlib.util.spec_from_file_location(
    "server",
    Path(__file__).parent / "server.py",
)
server = importlib.util.module_from_spec(spec)
spec.loader.exec_module(server)


def test_api_tasks_blocked_function_exists():
    """Function api_tasks_blocked must be defined in server module."""
    assert hasattr(
        server, "api_tasks_blocked"
    ), "api_tasks_blocked function not found in server.py"


def test_api_tasks_blocked_is_callable():
    """api_tasks_blocked must be callable."""
    assert callable(server.api_tasks_blocked), "api_tasks_blocked must be callable"


def test_api_tasks_blocked_registered_in_routes():
    """Route /api/tasks/blocked must be in ROUTES dict."""
    assert (
        "/api/tasks/blocked" in server.ROUTES
    ), "/api/tasks/blocked not found in ROUTES dict"


def test_api_tasks_blocked_routes_to_correct_function():
    """ROUTES['/api/tasks/blocked'] must point to api_tasks_blocked."""
    assert (
        server.ROUTES["/api/tasks/blocked"] is server.api_tasks_blocked
    ), "ROUTES['/api/tasks/blocked'] does not point to api_tasks_blocked"


def test_api_tasks_blocked_returns_list():
    """api_tasks_blocked() must return a list (may be empty if no blocked tasks)."""
    result = server.api_tasks_blocked()
    assert isinstance(result, list), f"Expected list, got {type(result).__name__}"


if __name__ == "__main__":
    import pytest

    pytest.main([__file__, "-v"])
