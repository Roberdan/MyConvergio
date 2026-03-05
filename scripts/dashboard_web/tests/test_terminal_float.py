"""Tests for terminal.js floating mode fix (T1-03).

Verifies:
- setMode('float') uses pixel values computed from window dimensions
- Math.round(window.innerWidth/Height * factor) + 'px' pattern present
- .term-float CSS has no bottom:0 (conflicts with top positioning)
- min-width/min-height constraints present in .term-float
"""

import re
from pathlib import Path

TERMINAL_JS = Path(__file__).parent.parent / "terminal.js"
STYLE_CSS = Path(__file__).parent.parent / "style.css"


def read_file(path: Path) -> str:
    return path.read_text(encoding="utf-8")


class TestTerminalFloatJS:
    """Tests for terminal.js setMode('float') pixel conversion."""

    def test_innerWidth_px_pattern_present(self):
        """setMode('float') should compute left/width from innerWidth in px."""
        content = read_file(TERMINAL_JS)
        # Must have patterns like: Math.round(window.innerWidth * 0.X) + 'px'
        assert re.search(
            r"innerWidth.*px|innerWidth.*\+\s*['\"]px['\"]", content
        ), "terminal.js must compute pixel values from window.innerWidth"

    def test_innerHeight_px_pattern_present(self):
        """setMode('float') should compute top/height from innerHeight in px."""
        content = read_file(TERMINAL_JS)
        assert re.search(
            r"innerHeight.*px|innerHeight.*\+\s*['\"]px['\"]", content
        ), "terminal.js must compute pixel values from window.innerHeight"

    def test_math_round_used_for_float_positioning(self):
        """Math.round should be used for pixel-precise float positioning."""
        content = read_file(TERMINAL_JS)
        # Find lines with Math.round that mention window dimensions
        math_round_lines = [
            line
            for line in content.splitlines()
            if "Math.round" in line and ("innerWidth" in line or "innerHeight" in line)
        ]
        assert len(math_round_lines) >= 4, (
            f"Expected at least 4 Math.round(window.inner*) lines for left/top/width/height, "
            f"got {len(math_round_lines)}: {math_round_lines}"
        )

    def test_no_percentage_in_float_mode(self):
        """setMode('float') must not set percentage values for positioning."""
        content = read_file(TERMINAL_JS)
        # Extract the float mode block
        float_block_match = re.search(
            r'if\s*\(\s*mode\s*===\s*["\']float["\']\s*\)(.*?)(?:}\s*else|}\s*setTimeout)',
            content,
            re.DOTALL,
        )
        if float_block_match:
            float_block = float_block_match.group(1)
            assert "10%" not in float_block, "Float mode must not use percentage '10%'"
            assert "80%" not in float_block, "Float mode must not use percentage '80%'"
            assert "60%" not in float_block, "Float mode must not use percentage '60%'"

    def test_left_computed_from_innerWidth_10pct(self):
        """left should be Math.round(window.innerWidth * 0.1) + 'px'."""
        content = read_file(TERMINAL_JS)
        assert re.search(
            r"innerWidth\s*\*\s*0\.1", content
        ), "left must be computed as Math.round(window.innerWidth * 0.1)"

    def test_top_computed_from_innerHeight_10pct(self):
        """top should be Math.round(window.innerHeight * 0.1) + 'px'."""
        content = read_file(TERMINAL_JS)
        assert re.search(
            r"innerHeight\s*\*\s*0\.1", content
        ), "top must be computed as Math.round(window.innerHeight * 0.1)"

    def test_width_computed_from_innerWidth_80pct(self):
        """width should be Math.round(window.innerWidth * 0.8) + 'px'."""
        content = read_file(TERMINAL_JS)
        assert re.search(
            r"innerWidth\s*\*\s*0\.8", content
        ), "width must be computed as Math.round(window.innerWidth * 0.8)"

    def test_height_computed_from_innerHeight_60pct(self):
        """height should be Math.round(window.innerHeight * 0.6) + 'px'."""
        content = read_file(TERMINAL_JS)
        assert re.search(
            r"innerHeight\s*\*\s*0\.6", content
        ), "height must be computed as Math.round(window.innerHeight * 0.6)"


class TestTerminalFloatCSS:
    """Tests for .term-float CSS correctness."""

    def _get_term_float_block(self, content: str) -> str:
        """Extract .term-float CSS block."""
        match = re.search(r"\.term-float\s*\{([^}]+)\}", content, re.DOTALL)
        return match.group(1) if match else ""

    def test_term_float_has_no_bottom_zero(self):
        """term-float CSS must not have bottom:0 (conflicts with top positioning)."""
        content = read_file(STYLE_CSS)
        float_block = self._get_term_float_block(content)
        assert float_block, ".term-float block must exist in style.css"
        # bottom:0 in term-float conflicts with top-based pixel positioning
        assert not re.search(
            r"bottom\s*:\s*0", float_block
        ), ".term-float must not have bottom:0 — it conflicts with top pixel positioning"

    def test_term_float_has_min_width(self):
        """term-float CSS must have min-width constraint."""
        content = read_file(STYLE_CSS)
        float_block = self._get_term_float_block(content)
        assert "min-width" in float_block, ".term-float must have min-width constraint"

    def test_term_float_has_min_height(self):
        """term-float CSS must have min-height constraint."""
        content = read_file(STYLE_CSS)
        float_block = self._get_term_float_block(content)
        assert (
            "min-height" in float_block
        ), ".term-float must have min-height constraint"
