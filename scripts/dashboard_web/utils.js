/**
 * Shared utility functions for the dashboard web UI.
 * Loaded via <script> before app.js and mesh-actions.js.
 */

/** HTML-escape a string to prevent XSS in innerHTML assignments. */
function esc(s) {
  const d = document.createElement("div");
  d.textContent = s;
  return d.innerHTML;
}

/** Debounce a function — returns a wrapper that delays execution until ms have passed */
function debounce(fn, ms = 1000) {
  let timer;
  return function (...args) {
    const ctx = this;
    clearTimeout(timer);
    timer = setTimeout(() => fn.apply(ctx, args), ms);
  };
}
