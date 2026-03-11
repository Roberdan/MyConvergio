/**
 * widget-drag.js — Pointer-based widget reordering on the dashboard grid.
 * Uses mousedown/mousemove/mouseup (works with body zoom).
 * Drag handle: .widget-header only. Persists layout in localStorage.
 */

(function () {
  const STORAGE_KEY = "dashWidgetLayoutV2";
  const LEGACY_STORAGE_KEY = "dashWidgetLayout";
  let dragging = null; // { el, ghost, startX, startY, offsetX, offsetY }
  let placeholder = null;

  function cols() {
    return Array.from(
      document.querySelectorAll(".dash-col-left, .dash-col-right"),
    );
  }

  function colKey(col) {
    return col.classList.contains("dash-col-left") ? "left" : "right";
  }

  function saveLayout() {
    const layout = {};
    cols().forEach((col) => {
      layout[colKey(col)] = Array.from(col.querySelectorAll(".widget"))
        .map((w) => w.id)
        .filter(Boolean);
    });
    localStorage.setItem(STORAGE_KEY, JSON.stringify(layout));
  }

  function restoreLayout() {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (!raw) return;
    try {
      const layout = JSON.parse(raw);
      const colMap = {};
      cols().forEach((c) => (colMap[colKey(c)] = c));
      ["left", "right"].forEach((k) => {
        const c = colMap[k];
        const ids = layout[k];
        if (!c || !ids) return;
        // Filter out ideajar — always pinned last in left column
        ids.filter(id => id !== 'ideajar-widget').forEach((id) => {
          const w = document.getElementById(id);
          if (w) c.appendChild(w);
        });
      });
      // Pin ideajar-widget as last child of left column
      const left = colMap['left'];
      const jar = document.getElementById('ideajar-widget');
      if (left && jar) left.appendChild(jar);
    } catch (_) {}
  }

  function makePlaceholder(h) {
    const el = document.createElement("div");
    el.className = "widget-drop-placeholder";
    el.style.height = h + "px";
    return el;
  }

  function makeGhost(el) {
    const ghost = el.cloneNode(true);
    const rect = el.getBoundingClientRect();
    const zoom = parseFloat(document.body.style.zoom) || 1;
    ghost.style.cssText =
      "position:fixed;pointer-events:none;z-index:99999;" +
      "opacity:0.85;width:" +
      rect.width / zoom +
      "px;" +
      "box-shadow:0 12px 40px rgba(0,229,255,0.3);" +
      "border:1px solid var(--cyan);border-radius:8px;" +
      "transition:none;transform:scale(1.02);";
    document.body.appendChild(ghost);
    return ghost;
  }

  function nearestSlot(col, y) {
    const widgets = Array.from(col.querySelectorAll(".widget"));
    for (const w of widgets) {
      if (w === (dragging && dragging.el)) continue;
      const r = w.getBoundingClientRect();
      if (y < r.top + r.height / 2) return w;
    }
    return null;
  }

  function closestCol(x, y) {
    let best = null;
    let bestDist = Infinity;
    cols().forEach((c) => {
      const r = c.getBoundingClientRect();
      const cx = r.left + r.width / 2;
      const cy = r.top + r.height / 2;
      const d = Math.abs(x - cx) + Math.abs(y - cy) * 0.3;
      if (d < bestDist) {
        bestDist = d;
        best = c;
      }
    });
    return best;
  }

  // --- Mouse handlers ---

  function onMouseDown(e) {
    // Only from widget-header, ignore buttons/inputs inside
    const hdr = e.target.closest(".widget-header");
    if (!hdr) return;
    if (e.target.closest("button, input, select, a, .widget-action-btn"))
      return;
    const widget = hdr.closest(".widget");
    if (!widget || !widget.id) return;

    e.preventDefault();
    const rect = widget.getBoundingClientRect();
    const zoom = parseFloat(document.body.style.zoom) || 1;

    dragging = {
      el: widget,
      ghost: null,
      startX: e.clientX,
      startY: e.clientY,
      offsetX: e.clientX - rect.left,
      offsetY: e.clientY - rect.top,
      started: false,
      zoom: zoom,
    };

    document.addEventListener("mousemove", onMouseMove);
    document.addEventListener("mouseup", onMouseUp);
  }

  function onMouseMove(e) {
    if (!dragging) return;
    const dx = e.clientX - dragging.startX;
    const dy = e.clientY - dragging.startY;

    // Threshold: 5px to start drag
    if (!dragging.started) {
      if (Math.abs(dx) + Math.abs(dy) < 5) return;
      dragging.started = true;
      dragging.ghost = makeGhost(dragging.el);
      const h = dragging.el.offsetHeight;
      placeholder = makePlaceholder(h);
      dragging.el.parentNode.insertBefore(placeholder, dragging.el);
      dragging.el.style.display = "none";
    }

    // Position ghost at cursor
    const z = dragging.zoom;
    dragging.ghost.style.left = (e.clientX - dragging.offsetX) / z + "px";
    dragging.ghost.style.top = (e.clientY - dragging.offsetY) / z + "px";

    // Find target column + position
    const col = closestCol(e.clientX, e.clientY);
    if (!col) return;

    cols().forEach((c) => c.classList.remove("col-drag-over"));
    col.classList.add("col-drag-over");

    const before = nearestSlot(col, e.clientY);
    if (placeholder.parentNode) placeholder.parentNode.removeChild(placeholder);
    if (before) {
      col.insertBefore(placeholder, before);
    } else {
      col.appendChild(placeholder);
    }
  }

  function onMouseUp() {
    document.removeEventListener("mousemove", onMouseMove);
    document.removeEventListener("mouseup", onMouseUp);
    if (!dragging) return;

    if (dragging.started) {
      // Drop widget where placeholder is
      if (placeholder && placeholder.parentNode) {
        placeholder.parentNode.insertBefore(dragging.el, placeholder);
        placeholder.parentNode.removeChild(placeholder);
      }
      dragging.el.style.display = "";
      if (dragging.ghost) dragging.ghost.remove();
      cols().forEach((c) => c.classList.remove("col-drag-over"));
      saveLayout();
    }

    dragging = null;
    placeholder = null;
  }

  // --- Init ---

  restoreLayout();
  document.addEventListener("mousedown", onMouseDown);

  window.enableWidgetDrag = function () {}; // no-op, always active
  window.resetWidgetLayout = function () {
    localStorage.removeItem(STORAGE_KEY);
    localStorage.removeItem(LEGACY_STORAGE_KEY);
    location.reload();
  };
})();
