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
