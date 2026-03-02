"""Tests for dashboard-textual Python TUI scaffolding.

TDD: Written BEFORE implementation. Should fail initially.
"""

import sys
import os
import unittest

# Add scripts to path for import
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))


class TestModelsImport(unittest.TestCase):
    """F-01: models.py must define Plan, Wave, Task, Peer, TokenStats."""

    def test_import_plan(self):
        from dashboard_textual.models import Plan

        self.assertTrue(callable(Plan))

    def test_import_wave(self):
        from dashboard_textual.models import Wave

        self.assertTrue(callable(Wave))

    def test_import_task(self):
        from dashboard_textual.models import Task

        self.assertTrue(callable(Task))

    def test_import_peer(self):
        from dashboard_textual.models import Peer

        self.assertTrue(callable(Peer))

    def test_import_token_stats(self):
        from dashboard_textual.models import TokenStats

        self.assertTrue(callable(TokenStats))

    def test_plan_is_dataclass(self):
        import dataclasses
        from dashboard_textual.models import Plan

        self.assertTrue(dataclasses.is_dataclass(Plan))

    def test_plan_has_id(self):
        from dashboard_textual.models import Plan
        import dataclasses

        fields = {f.name for f in dataclasses.fields(Plan)}
        self.assertIn("id", fields)

    def test_plan_has_name(self):
        from dashboard_textual.models import Plan
        import dataclasses

        fields = {f.name for f in dataclasses.fields(Plan)}
        self.assertIn("name", fields)

    def test_plan_has_status(self):
        from dashboard_textual.models import Plan
        import dataclasses

        fields = {f.name for f in dataclasses.fields(Plan)}
        self.assertIn("status", fields)

    def test_wave_is_dataclass(self):
        import dataclasses
        from dashboard_textual.models import Wave

        self.assertTrue(dataclasses.is_dataclass(Wave))

    def test_task_is_dataclass(self):
        import dataclasses
        from dashboard_textual.models import Task

        self.assertTrue(dataclasses.is_dataclass(Task))

    def test_peer_is_dataclass(self):
        import dataclasses
        from dashboard_textual.models import Peer

        self.assertTrue(dataclasses.is_dataclass(Peer))

    def test_token_stats_is_dataclass(self):
        import dataclasses
        from dashboard_textual.models import TokenStats

        self.assertTrue(dataclasses.is_dataclass(TokenStats))

    def test_plan_instantiation(self):
        from dashboard_textual.models import Plan

        p = Plan(
            id=1,
            name="TestPlan",
            status="doing",
            tasks_done=2,
            tasks_total=5,
            worktree_path="/tmp/test",
            created_at="2026-01-01",
        )
        self.assertEqual(p.id, 1)
        self.assertEqual(p.name, "TestPlan")
        self.assertEqual(p.status, "doing")


class TestDBImport(unittest.TestCase):
    """F-02: db.py must define DashboardDB with graceful error handling."""

    def test_import_dashboard_db(self):
        from dashboard_textual.db import DashboardDB

        self.assertTrue(callable(DashboardDB))

    def test_dashboard_db_instantiation(self):
        from dashboard_textual.db import DashboardDB

        # Should not raise even with non-existent DB
        db = DashboardDB("/tmp/nonexistent-test-db.db")
        self.assertIsNotNone(db)

    def test_get_overview_returns_dict(self):
        from dashboard_textual.db import DashboardDB

        db = DashboardDB("/tmp/nonexistent-test-db.db")
        result = db.get_overview()
        self.assertIsInstance(result, dict)

    def test_get_active_plans_returns_list(self):
        from dashboard_textual.db import DashboardDB

        db = DashboardDB("/tmp/nonexistent-test-db.db")
        result = db.get_active_plans()
        self.assertIsInstance(result, list)

    def test_get_completed_plans_returns_list(self):
        from dashboard_textual.db import DashboardDB

        db = DashboardDB("/tmp/nonexistent-test-db.db")
        result = db.get_completed_plans()
        self.assertIsInstance(result, list)

    def test_get_peers_returns_list(self):
        from dashboard_textual.db import DashboardDB

        db = DashboardDB("/tmp/nonexistent-test-db.db")
        result = db.get_peers()
        self.assertIsInstance(result, list)

    def test_get_token_stats_returns_token_stats(self):
        from dashboard_textual.db import DashboardDB
        from dashboard_textual.models import TokenStats

        db = DashboardDB("/tmp/nonexistent-test-db.db")
        result = db.get_token_stats()
        self.assertIsInstance(result, TokenStats)

    def test_get_plan_waves_returns_list(self):
        from dashboard_textual.db import DashboardDB

        db = DashboardDB("/tmp/nonexistent-test-db.db")
        result = db.get_plan_waves(999)
        self.assertIsInstance(result, list)

    def test_get_wave_tasks_returns_list(self):
        from dashboard_textual.db import DashboardDB

        db = DashboardDB("/tmp/nonexistent-test-db.db")
        result = db.get_wave_tasks(999)
        self.assertIsInstance(result, list)

    def test_operational_error_is_handled(self):
        """DB that raises OperationalError must return empty, not crash."""
        from dashboard_textual.db import DashboardDB

        db = DashboardDB("/tmp/nonexistent-test-db.db")
        # All methods must return gracefully
        overview = db.get_overview()
        plans = db.get_active_plans()
        peers = db.get_peers()
        self.assertIsNotNone(overview)
        self.assertIsNotNone(plans)
        self.assertIsNotNone(peers)


class TestPackageStructure(unittest.TestCase):
    """F-03: Package structure requirements."""

    def test_package_importable(self):
        import dashboard_textual

        self.assertIsNotNone(dashboard_textual)

    def test_requirements_file_exists(self):
        req_path = os.path.join(
            os.path.dirname(__file__), "..", "dashboard-textual", "requirements.txt"
        )
        self.assertTrue(
            os.path.exists(req_path), f"requirements.txt not found at {req_path}"
        )

    def test_requirements_has_textual(self):
        req_path = os.path.join(
            os.path.dirname(__file__), "..", "dashboard-textual", "requirements.txt"
        )
        if os.path.exists(req_path):
            with open(req_path) as f:
                content = f.read()
            self.assertIn("textual", content.lower())

    def test_requirements_has_plotext(self):
        req_path = os.path.join(
            os.path.dirname(__file__), "..", "dashboard-textual", "requirements.txt"
        )
        if os.path.exists(req_path):
            with open(req_path) as f:
                content = f.read()
            self.assertIn("plotext", content.lower())

    def test_main_module_exists(self):
        main_path = os.path.join(
            os.path.dirname(__file__), "..", "dashboard-textual", "__main__.py"
        )
        self.assertTrue(os.path.exists(main_path))

    def test_app_module_importable(self):
        from dashboard_textual.app import ControlCenterApp

        self.assertTrue(callable(ControlCenterApp))

    def test_app_has_keybindings_defined(self):
        from dashboard_textual.app import ControlCenterApp

        # Check BINDINGS class attribute exists
        self.assertTrue(hasattr(ControlCenterApp, "BINDINGS"))


class TestFileSizeLimits(unittest.TestCase):
    """F-04: Each Python file < 250 lines."""

    def _count_lines(self, filename):
        base = os.path.join(os.path.dirname(__file__), "..", "dashboard-textual")
        path = os.path.join(base, filename)
        if not os.path.exists(path):
            return 0
        with open(path) as f:
            return sum(1 for _ in f)

    def test_models_under_250_lines(self):
        count = self._count_lines("models.py")
        self.assertLessEqual(count, 250, f"models.py has {count} lines (max 250)")

    def test_db_under_250_lines(self):
        count = self._count_lines("db.py")
        self.assertLessEqual(count, 250, f"db.py has {count} lines (max 250)")

    def test_app_under_250_lines(self):
        count = self._count_lines("app.py")
        self.assertLessEqual(count, 250, f"app.py has {count} lines (max 250)")


if __name__ == "__main__":
    unittest.main(verbosity=2)
