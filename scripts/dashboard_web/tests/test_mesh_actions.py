"""
Tests for T2-02: inline mesh action toolbar (mesh-actions.js).
Verifies file existence, CSS rules, data-peer attributes, and script tag.
"""

import os
import re
import pytest

BASE = os.path.join(os.path.dirname(__file__), "..")


def read(name):
    with open(os.path.join(BASE, name)) as f:
        return f.read()


# --- File existence ---


def test_mesh_actions_js_exists():
    assert os.path.isfile(
        os.path.join(BASE, "mesh-actions.js")
    ), "mesh-actions.js must exist"


# --- mesh-actions.js content ---


def test_mesh_actions_exports_meshAction():
    src = read("mesh-actions.js")
    assert "meshAction" in src, "meshAction must be defined in mesh-actions.js"


def test_mesh_actions_exports_showMovePlanDialog():
    src = read("mesh-actions.js")
    assert "showMovePlanDialog" in src


def test_mesh_actions_exports_movePlan():
    src = read("mesh-actions.js")
    assert "movePlan" in src


def test_mesh_actions_exports_showOutputModal():
    src = read("mesh-actions.js")
    assert "showOutputModal" in src


def test_mesh_actions_uses_data_peer_delegation():
    """Event delegation must use data-peer, not inline onclick with user strings."""
    src = read("mesh-actions.js")
    assert "data-peer" in src, "mesh-actions.js must read data-peer attribute"
    assert (
        "dataset.peer" in src or "getAttribute('data-peer')" in src
    ), "mesh-actions.js must read peer from dataset.peer or getAttribute"


def test_mesh_actions_event_delegation():
    src = read("mesh-actions.js")
    assert "addEventListener" in src, "event delegation must use addEventListener"
    assert "closest" in src, "event delegation must use .closest() to find button"


def test_mesh_actions_no_inline_onclick_with_user_string():
    """No inline onclick that embeds user-controlled strings (XSS risk)."""
    src = read("mesh-actions.js")
    # Should NOT have onclick="meshAction('...')" with variable peer string injected
    # Pattern: onclick with string concatenation of peer name
    bad_pattern = re.compile(r"onclick=['\"]meshAction\([^)]*\+")
    assert not bad_pattern.search(
        src
    ), "mesh-actions.js must not use string-concatenated onclick handlers"


# --- style.css ---


def test_css_mn_actions_exists():
    src = read("style.css")
    assert ".mn-actions" in src, ".mn-actions must be defined in style.css"


def test_css_mn_actions_horizontal_layout():
    """User directive: horizontal always-visible icons (not vertical absolute)."""
    src = read("style.css")
    idx = src.find(".mn-actions")
    assert idx >= 0
    snippet = src[idx : idx + 300]
    assert (
        "justify-content" in snippet
    ), ".mn-actions must use justify-content (horizontal)"


def test_css_mn_act_btn_exists():
    src = read("style.css")
    assert ".mn-act-btn" in src, ".mn-act-btn must be defined in style.css"


def test_css_mn_act_btn_size():
    src = read("style.css")
    idx = src.find(".mn-act-btn")
    snippet = src[idx : idx + 200]
    assert "24px" in snippet, ".mn-act-btn must be 24px wide/high (user directive)"


# --- app.js: functions moved out ---


def test_app_js_no_showPeerActions():
    src = read("app.js")
    assert "showPeerActions" not in src, "showPeerActions must be removed from app.js"


def test_app_js_no_meshAction_definition():
    src = read("app.js")
    # meshAction must not be defined (window.meshAction = ) in app.js
    assert (
        "window.meshAction" not in src
    ), "meshAction definition must be moved to mesh-actions.js"


def test_app_js_no_showMovePlanDialog_definition():
    src = read("app.js")
    assert (
        "window.showMovePlanDialog" not in src
    ), "showMovePlanDialog must be moved to mesh-actions.js"


def test_app_js_mn_actions_toolbar_in_renderMeshStrip():
    src = read("app.js")
    assert (
        "mn-actions" in src
    ), "renderMeshStrip must render .mn-actions toolbar inside each node"


def test_app_js_data_peer_on_action_buttons():
    src = read("app.js")
    assert (
        "data-peer" in src or "data-action" in src
    ), "action buttons must use data-peer / data-action attributes"


def test_app_js_no_onclick_showPeerActions():
    src = read("app.js")
    assert (
        'onclick="showPeerActions' not in src and "onclick='showPeerActions" not in src
    ), "mesh-node onclick must not call showPeerActions"


# --- index.html ---


def test_index_html_mesh_actions_script_tag():
    src = read("index.html")
    assert (
        "mesh-actions.js" in src
    ), 'index.html must include <script src="mesh-actions.js"></script>'
