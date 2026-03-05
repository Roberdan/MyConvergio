"""Cyberpunk theme definitions for the Control Center TUI."""

from __future__ import annotations

from textual.design import ColorSystem

NEON_GRID = ColorSystem(
    primary="#00ffff",
    secondary="#ff00ff",
    accent="#ffd700",
    warning="#ffd700",
    error="#ff0055",
    success="#00ff66",
    background="#0a0a1a",
    surface="#111128",
    panel="#1a1a3e",
    dark=True,
)

SYNTHWAVE = ColorSystem(
    primary="#b362ff",
    secondary="#ff6eb4",
    accent="#ffe566",
    warning="#ffaa55",
    error="#ff3388",
    success="#33ffaa",
    background="#1a0a2e",
    surface="#2a1848",
    panel="#351e5a",
    dark=True,
)

GHOST_SHELL = ColorSystem(
    primary="#22cc44",
    secondary="#55ff55",
    accent="#ccff00",
    warning="#ccff00",
    error="#cc2200",
    success="#00ff44",
    background="#0a0f0a",
    surface="#0f1a0f",
    panel="#162016",
    dark=True,
)

THEMES = {
    "neon-grid": NEON_GRID,
    "synthwave": SYNTHWAVE,
    "ghost-shell": GHOST_SHELL,
}

THEME_NAMES = list(THEMES.keys())
