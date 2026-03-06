"""Tests for font CSS paths and cancel/reset JS functions."""

import os
import re

import pytest

BASE = os.path.join(os.path.dirname(__file__), "..")


def read(name):
    with open(os.path.join(BASE, name)) as f:
        return f.read()


# --- Font loading ---


class TestFontLoading:
    def test_font_face_declaration_exists(self):
        src = read("css/base.css")
        assert "@font-face" in src

    def test_font_path_uses_parent_directory(self):
        """CSS in css/ dir must use ../fonts/ to reach fonts/."""
        src = read("css/base.css")
        assert (
            "../fonts/" in src
        ), "font path must use ../fonts/ (relative to css/ subdir)"

    def test_font_path_not_bare_fonts_dir(self):
        """Must NOT use bare fonts/ (wrong resolution from css/ subdir)."""
        src = read("css/base.css")
        face_block = src[
            src.find("@font-face") : src.find("}", src.find("@font-face")) + 1
        ]
        # Should not have url("fonts/...) without the ../
        assert (
            'url("fonts/' not in face_block
        ), "font URL must not use bare fonts/ path from css/ subdir"

    def test_nerd_font_in_font_mono_variable(self):
        src = read("css/base.css")
        mono_match = re.search(r"--font-mono:\s*(.+?);", src)
        assert mono_match, "--font-mono CSS variable must be defined"
        assert "Nerd Font" in mono_match.group(
            1
        ), "JetBrainsMono Nerd Font must be first in --font-mono"

    def test_font_woff2_file_exists(self):
        font_dir = os.path.join(BASE, "fonts")
        if os.path.isdir(font_dir):
            woff2_files = [f for f in os.listdir(font_dir) if f.endswith(".woff2")]
            assert len(woff2_files) > 0, "At least one .woff2 font file must exist"


# --- Cancel/Reset JS functions ---


class TestCancelResetJS:
    def test_cancelPlan_defined(self):
        src = read("mesh-plan-ops.js")
        assert "cancelPlan" in src, "cancelPlan must be defined"

    def test_resetPlan_defined(self):
        src = read("mesh-plan-ops.js")
        assert "resetPlan" in src, "resetPlan must be defined"

    def test_cancelPlan_calls_api_cancel(self):
        src = read("mesh-plan-ops.js")
        assert "/api/plan/cancel" in src, "cancelPlan must call /api/plan/cancel"

    def test_resetPlan_calls_api_reset(self):
        src = read("mesh-plan-ops.js")
        assert "/api/plan/reset" in src, "resetPlan must call /api/plan/reset"

    def test_cancelPlan_uses_modal_confirmation(self):
        src = read("mesh-plan-ops.js")
        idx = src.find("cancelPlan")
        snippet = src[idx : idx + 1000]
        assert "modal" in snippet.lower(), "cancelPlan must show confirmation modal"

    def test_resetPlan_uses_modal_confirmation(self):
        src = read("mesh-plan-ops.js")
        idx = src.find("resetPlan")
        snippet = src[idx : idx + 1000]
        assert "modal" in snippet.lower(), "resetPlan must show confirmation modal"


# --- Activity.js: sidebar action buttons ---


class TestActivitySidebarButtons:
    def test_sidebar_has_reset_button(self):
        src = read("activity.js")
        assert "resetPlan" in src, "activity.js must wire resetPlan button"

    def test_sidebar_has_cancel_button(self):
        src = read("activity.js")
        assert "cancelPlan" in src, "activity.js must wire cancelPlan button"

    def test_buttons_conditional_on_status(self):
        """Buttons should only show for non-done/cancelled plans."""
        src = read("activity.js")
        assert (
            "done" in src and "cancelled" in src
        ), "activity.js must check plan status before showing buttons"


# --- CSS button styles ---


class TestButtonStyles:
    def test_plan_action_btn_exists(self):
        src = read("css/components-3.css")
        assert ".plan-action-btn" in src

    def test_plan_action_reset_style(self):
        src = read("css/components-3.css")
        assert ".plan-action-reset" in src
        idx = src.find(".plan-action-reset")
        snippet = src[idx : idx + 200]
        assert "gold" in snippet, "Reset button must use gold color"

    def test_plan_action_cancel_style(self):
        src = read("css/components-3.css")
        assert ".plan-action-cancel" in src
        idx = src.find(".plan-action-cancel")
        snippet = src[idx : idx + 200]
        assert "red" in snippet, "Cancel button must use red color"


# --- KPI.js: resumePlanExecution ---


class TestResumeFunction:
    def test_resume_function_exists(self):
        src = read("mission.js")
        assert "resumePlanExecution" in src

    def test_resume_uses_polling(self):
        """Must use setInterval polling, not setTimeout."""
        src = read("mission.js")
        idx = src.find("window.resumePlanExecution")
        snippet = src[idx : idx + 2000]
        assert (
            "setInterval" in snippet
        ), "resumePlanExecution must poll WS state with setInterval"

    def test_resume_does_not_overwrite_onopen(self):
        """Must NOT overwrite ws.onopen (addTab needs it)."""
        src = read("mission.js")
        idx = src.find("window.resumePlanExecution")
        snippet = src[idx : idx + 2000]
        assert (
            "tab.ws.onopen =" not in snippet
        ), "resumePlanExecution must not overwrite ws.onopen"

    def test_resume_uses_claude_command(self):
        src = read("mission.js")
        idx = src.find("window.resumePlanExecution")
        snippet = src[idx : idx + 2000]
        assert "claude" in snippet, "resumePlanExecution must use claude CLI"
        assert "/execute" in snippet, "resumePlanExecution must invoke /execute skill"

    def test_open_plan_terminal_exists(self):
        src = read("mission.js")
        assert "openPlanTerminal" in src

    def test_terminal_open_returns_tab_id(self):
        src = read("terminal.js")
        # open() must return the tab ID from addTab
        idx = src.find("open(peer")
        snippet = src[idx : idx + 300]
        assert "return" in snippet, "open() must return tab ID from addTab"
