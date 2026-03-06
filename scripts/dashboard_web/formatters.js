/**
 * Shared formatting utilities — loaded before kpi.js and all consumers.
 * Functions exposed as window globals for use across dashboard scripts.
 */

function fmt(n) {
  if (!n && n !== 0) return "—";
  if (n >= 1e6) return (n / 1e6).toFixed(1) + "M";
  if (n >= 1e3) return (n / 1e3).toFixed(1) + "K";
  return String(n);
}

function statusColor(s) {
  return (
    {
      done: "#00cc55",
      in_progress: "#ffb700",
      submitted: "#00b8d4",
      blocked: "#ee3344",
      pending: "#5a6080",
      cancelled: "#ee3344",
      skipped: "#5a6080",
      doing: "#00b8d4",
      todo: "#5a6080",
      merging: "#9c27b0",
    }[s] || "#5a6080"
  );
}

function statusDot(s) {
  const cls =
    {
      done: "dot-done",
      in_progress: "dot-active",
      submitted: "dot-submitted",
      blocked: "dot-blocked",
      pending: "dot-pending",
      cancelled: "dot-cancelled",
      skipped: "dot-skipped",
      merging: "dot-submitted",
    }[s] || "dot-pending";
  return `<span class="status-dot ${cls}"></span>`;
}

function thorIcon(v) {
  const c = v ? "#00cc55" : "#ee3344";
  return `<svg xmlns="http://www.w3.org/2000/svg" width="14" height="14" viewBox="0 0 24 24" fill="${c}" style="vertical-align:-2px" title="${v ? "Thor validated" : "Not validated"}"><path d="M12 1L8 5v3H5l-2 4h4l-3 11h2l7-9H9l3-5h5l3-4h-4l1-4h-5z"/></svg>`;
}

window.fmt = fmt;
window.statusColor = statusColor;
window.statusDot = statusDot;
window.thorIcon = thorIcon;
