/**
 * idea-jar-physics.js — Slip animation logic for the Idea Jar canvas
 * v1.0.0
 */

(function () {
  'use strict';

  /**
   * Create initial state for a single slip.
   * @param {Object} idea  - idea object {id, title, priority}
   * @param {number} index - slip index (used to spread initial positions)
   * @param {Object} jarBounds - {x, y, width, height} of jar body interior
   * @returns {Object} slip state
   */
  function createSlipState(idea, index, jarBounds) {
    const slipW = 48;
    const slipH = 18;

    // Spread slips across the jar interior using a grid-ish distribution
    const cols = Math.max(1, Math.floor(jarBounds.width / (slipW + 8)));
    const col = index % cols;
    const row = Math.floor(index / cols);
    const spreadX = jarBounds.x + 10 + col * (slipW + 8);
    const spreadY = jarBounds.y + 12 + row * (slipH + 10);

    // Clamp to jar interior
    const maxX = jarBounds.x + jarBounds.width - slipW - 4;
    const maxY = jarBounds.y + jarBounds.height - slipH - 4;

    return {
      id: idea.id,
      idea,
      // Dimensions
      w: slipW,
      h: slipH,
      // Base position (oscillates around this)
      baseX: Math.min(spreadX, maxX),
      baseY: Math.min(spreadY, maxY),
      // Current rendered position
      x: Math.min(spreadX, maxX),
      y: Math.min(spreadY, maxY),
      // Animation parameters — each slip unique
      phaseY: (index * 1.618) % (Math.PI * 2),
      phaseX: (index * 0.927) % (Math.PI * 2),
      phaseRot: (index * 2.341) % (Math.PI * 2),
      ampY: 3 + (index % 5) * 1.1,          // 3–8px vertical amplitude
      ampX: 1.5 + (index % 3) * 0.8,        // 1.5–4px horizontal amplitude
      ampRot: 0.04 + (index % 4) * 0.015,   // subtle rotation amplitude (rad)
      freqY: (2 + (index % 6) * 0.5) * 0.001,  // period 2–5s (ms-based freq)
      freqX: (1.5 + (index % 4) * 0.4) * 0.001,
      freqRot: (1.2 + (index % 5) * 0.35) * 0.001,
      driftSpeed: 0.2 + (index % 5) * 0.06, // px/s horizontal drift
      driftDir: index % 2 === 0 ? 1 : -1,
      rotation: 0,
    };
  }

  /**
   * Update all slip positions for the current timestamp.
   * Slips float with sine-wave Y oscillation, gentle X drift, and slight rotation.
   * Each slip bounces off jar wall bounds.
   *
   * @param {Array}  slips     - array of slip states (mutated in place)
   * @param {number} time      - current timestamp in ms (from rAF)
   * @param {Object} jarBounds - {x, y, width, height} of jar interior
   */
  function updateSlipPositions(slips, time, jarBounds) {
    slips.forEach(function (s) {
      // Sine-wave vertical oscillation around base position
      s.y = s.baseY + Math.sin(time * s.freqY * Math.PI * 2 + s.phaseY) * s.ampY;

      // Horizontal: sine + slow drift, base drifts and wraps/bounces
      const driftDelta = s.driftSpeed * 0.016 * s.driftDir; // ~60fps delta
      s.baseX += driftDelta;

      const minX = jarBounds.x + 4;
      const maxX = jarBounds.x + jarBounds.width - s.w - 4;
      if (s.baseX < minX) { s.baseX = minX; s.driftDir = 1; }
      if (s.baseX > maxX) { s.baseX = maxX; s.driftDir = -1; }

      s.x = s.baseX + Math.sin(time * s.freqX * Math.PI * 2 + s.phaseX) * s.ampX;

      // Rotation oscillation
      s.rotation = Math.sin(time * s.freqRot * Math.PI * 2 + s.phaseRot) * s.ampRot;

      // Clamp Y within jar
      const minY = jarBounds.y + 4;
      const maxY = jarBounds.y + jarBounds.height - s.h - 4;
      if (s.y < minY) s.y = minY;
      if (s.y > maxY) s.y = maxY;
    });
  }

  // Public API
  window.JarPhysics = {
    createSlipState,
    updateSlipPositions,
  };
})();
