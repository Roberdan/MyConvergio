// mission-details.js — wave gantt + task flow rendering (loaded after mission.js)

function _progressRing(pct, size, color) {
  const r = (size - 8) / 2,
    c = 2 * Math.PI * r,
    o = c - (pct / 100) * c;
  return `<div class="mission-ring" style="width:${size}px;height:${size}px"><svg width="${size}" height="${size}" viewBox="0 0 ${size} ${size}"><defs><linearGradient id="ring-grad-${pct}" x1="0" y1="0" x2="1" y2="1"><stop offset="0%" stop-color="${pct < 50 ? '#ee3344' : '#e6a117'}"/><stop offset="100%" stop-color="${color}"/></linearGradient></defs><circle class="mission-ring-bg" cx="${size / 2}" cy="${size / 2}" r="${r}"/><circle class="mission-ring-fill" cx="${size / 2}" cy="${size / 2}" r="${r}" stroke="url(#ring-grad-${pct})" stroke-dasharray="${c}" stroke-dashoffset="${o}"/></svg><div class="mission-ring-pct" style="color:${color}">${pct}%</div></div>`;
}

function _shortModel(m) {
  if (!m) return "";
  return m
    .replace("claude-", "")
    .replace("gpt-", "")
    .replace("-codex", "")
    .replace("-fast", "F")
    .replace("opus-4.6", "opus")
    .replace("sonnet-4.6", "sonnet")
    .replace("haiku-4.5", "haiku");
}

function _renderOneTask(t) {
  const model = _shortModel(t.model || t.executor_agent || ""),
    agent = t.executor_agent || "",
    isClaud = /claude|opus|sonnet|haiku/i.test(agent + model),
    isCopilot = /copilot|gpt|codex/i.test(agent + model),
    agentLabel = isCopilot ? "Copilot" : isClaud ? "Claude" : agent || "?",
    agentCls = isCopilot ? "agent-copilot" : "agent-claude";
  const steps = [
    { key: "exec", label: "Execute" },
    { key: "submit", label: "Submit" },
    { key: "thor", label: "Thor" },
    { key: "done", label: "Done" },
  ];
  let active = "exec";
  if (t.status === "submitted") active = "thor";
  if (t.validated_at) active = "done";
  return `<div class="task-flow"><div class="task-flow-id">${esc(t.task_id || "")}</div><div class="task-flow-agent ${agentCls}"><span class="task-flow-agent-icon">${isCopilot ? "&#9883;" : "&#9672;"}</span>${esc(agentLabel)}${model ? ` <span class="task-flow-model">${esc(model)}</span>` : ""}</div><div class="task-flow-pipe">${steps
    .map((s, i) => {
      const ai = s.key === active,
        pi = steps.findIndex((x) => x.key === active) > i,
        cls = ai ? "step-active" : pi ? "step-done" : "step-pending";
      return `<div class="flow-step ${cls}"><div class="flow-dot"></div><div class="flow-label">${s.label}</div></div>${i < steps.length - 1 ? `<div class="flow-conn ${pi ? "conn-done" : ai ? "conn-active" : ""}"></div>` : ""}`;
    })
    .join("")}</div></div>`;
}

function _renderWaveGanttSvg(waves) {
  if (!waves || !waves.length) return "";
  const rowHeight = 28,
    barHeight = 24,
    totalHeight = waves.length * rowHeight,
    byWaveId = Object.fromEntries(waves.map((w, i) => [w.wave_id, { w, i }]));
  const rows = waves
    .map((w) => {
      const total = Number(w.tasks_total || 0),
        done = Number(w.tasks_done || 0),
        pct =
          total > 0
            ? Math.round((100 * done) / total)
            : w.status === "done" || w.status === "merging"
              ? 100
              : 0,
        width = Math.max(4, Math.min(100, pct)),
        statusCls = w.status === "merging" ? "done" : (w.status || "pending"),
        name = w.name ? ` — ${w.name}` : "";
      return `<div class="wave-gantt-row" style="height:${rowHeight}px"><div class="wave-gantt-bar wave-gantt-${esc(statusCls)}" style="height:${barHeight}px;width:${width}%"><span><strong>${esc(w.wave_id)}</strong>${esc(name)}</span></div></div>`;
    })
    .join("");
  const arrows = waves
    .map((w, i) => {
      const rawDeps = Array.isArray(w.depends_on)
          ? w.depends_on
          : typeof w.depends_on === "string"
            ? w.depends_on
                .split(",")
                .map((s) => s.trim())
                .filter(Boolean)
            : w.depends_on
              ? [String(w.depends_on)]
              : [],
        dy = i * rowHeight + barHeight / 2;
      return rawDeps
        .map((depId) => {
          const src = byWaveId[depId];
          if (!src) return "";
          const swTotal = Number(src.w.tasks_total || 0),
            swDone = Number(src.w.tasks_done || 0),
            swPct =
              swTotal > 0
                ? Math.round((100 * swDone) / swTotal)
                : src.w.status === "done" || src.w.status === "merging"
                  ? 100
                  : 0,
            sx = Math.max(4, Math.min(100, swPct)),
            sy = src.i * rowHeight + barHeight / 2,
            dx = 0,
            c1x = Math.min(100, sx + 8),
            c2x = Math.max(0, dx - 8),
            stroke =
              src.w.status === "done" || src.w.status === "merging"
                ? "var(--green)"
                : src.w.status === "pending"
                  ? "var(--text-dim)"
                  : "var(--cyan)";
          return `<path class="wave-gantt-arrow" d="M ${sx} ${sy} C ${c1x} ${sy}, ${c2x} ${dy}, ${dx} ${dy}" style="stroke:${stroke}"></path>`;
        })
        .join("");
    })
    .join("");
  return `<div class="wave-gantt">${rows}<svg class="wave-gantt-svg" viewBox="0 0 100 ${totalHeight}" preserveAspectRatio="none"><defs><marker id="arrow" markerWidth="8" markerHeight="6" refX="7" refY="3" orient="auto"><path d="M0,0 L8,3 L0,6 Z" fill="var(--cyan)"></path></marker></defs>${arrows}</svg></div>`;
}

// Public: wave rows + optional gantt for a plan card
function renderWaveGantt(waves, p) {
  if (!waves || !waves.length) return "";
  let html = '<div style="margin-top:8px">';
  const activeWaves = waves.filter(
    (w) => w.status !== "pending" || (w.tasks_done && w.tasks_done > 0),
  );
  const pendingWaves = waves.filter(
    (w) => w.status === "pending" && (!w.tasks_done || w.tasks_done === 0),
  );
  activeWaves.forEach((w) => {
    const wp =
        w.tasks_total > 0
          ? Math.round((100 * w.tasks_done) / w.tasks_total)
          : 0,
      wValidated = !!w.validated_at,
      wPct = wp >= 100 && !wValidated ? 95 : wp,
      wg = _progressGradient(wPct),
      wName = w.name ? ` — ${(w.name || "").substring(0, 35)}` : "",
      cls =
        w.status === "done" || w.status === "merging"
          ? "done"
          : w.status === "in_progress"
            ? "in_progress"
            : "pending";
    html += `<div class="wave-row"><div class="wave-label">${statusDot(w.status)} <strong>${esc(w.wave_id)}</strong><span class="wave-name">${esc(wName)}</span></div><div class="wave-bar"><div class="wave-fill ${cls}" style="width:${wPct}%;background:${wg.gradient}"></div></div><div class="wave-pct" style="color:${wg.color}">${wPct}%</div><div style="margin-left:4px">${thorIcon(w.validated_at)}</div></div>`;
  });
  if (pendingWaves.length > 0) {
    const cid = `pending-waves-${p.id}`;
    html += `<div class="wave-row wave-pending-summary" onclick="event.stopPropagation();document.getElementById('${cid}').classList.toggle('expanded')"><div class="wave-label">${statusDot("pending")} ${pendingWaves.length} waves pending</div><div class="wave-expand-icon">&#9662;</div></div>`;
    html += `<div id="${cid}" class="wave-pending-collapse">`;
    pendingWaves.forEach((w) => {
      const wName = w.name ? ` — ${(w.name || "").substring(0, 35)}` : "";
      html += `<div class="wave-row wave-row-dim"><div class="wave-label">${statusDot("pending")} <strong>${esc(w.wave_id)}</strong><span class="wave-name">${esc(wName)}</span></div><div class="wave-bar"><div class="wave-fill pending" style="width:0%"></div></div><div class="wave-pct">0%</div></div>`;
    });
    html += "</div>";
  }
  if (waves.some((w) => w.depends_on) && waves.length <= 8) {
    html += '<div class="wave-gantt-container">';
    html += _renderWaveGanttSvg(waves);
    html += "</div>";
  }
  html += "</div>";
  return html;
}

// Public: running/submitted task pipeline for a plan card
function renderTaskFlow(tasks, p) {
  const running_tasks = (tasks || []).filter((t) => t.status === "in_progress");
  const submitted_count = (tasks || []).filter((t) => t.status === "submitted").length;
  if (!running_tasks.length && !submitted_count) return "";
  let html = '<div class="live-flow-section">';
  running_tasks.slice(0, 4).forEach((t) => (html += _renderOneTask(t)));
  if (running_tasks.length > 4)
    html += `<div style="font-size:10px;color:var(--text-dim);padding:2px 0">+ ${running_tasks.length - 4} more running</div>`;
  if (submitted_count)
    html += `<div style="font-size:10px;color:var(--gold);padding:2px 0">${submitted_count} task awaiting Thor validation</div>`;
  html += "</div>";
  return html;
}
