function _liveTone(status) {
  return (
    {
      running: "var(--green)",
      validating: "var(--gold)",
      handoff: "var(--magenta)",
      waiting: "var(--cyan)",
      blocked: "var(--red)",
      queued: "var(--text-dim)",
    }[status] || "var(--cyan)"
  );
}

function _eventTone(type) {
  if (/fail|block|error/i.test(type)) return "var(--red)";
  if (/handoff|delegate/i.test(type)) return "var(--magenta)";
  if (/thor|valid/i.test(type)) return "var(--gold)";
  return "var(--cyan)";
}

function renderLiveSystem(snapshot) {
  const root = document.getElementById("live-system-content");
  if (!root) return;
  if (!snapshot || !Array.isArray(snapshot.peer_nodes) || !snapshot.peer_nodes.length) {
    root.innerHTML =
      '<span style="color:var(--text-dim)">No live system data yet.</span>';
    return;
  }

  const summary = snapshot.summary || {};
  root.innerHTML = `
    <div class="live-system-summary">
      <span>${summary.online_peers || 0}/${summary.peer_nodes || 0} peers online</span>
      <span>${summary.active_runs || 0} active runs</span>
      <span>${summary.open_handoffs || 0} open handoffs</span>
      <span>${summary.recent_events || 0} recent events</span>
    </div>
    <div class="live-system-brain">
      <div class="live-system-peers">
        ${snapshot.peer_nodes
          .map(
            (peer) => `
              <div class="live-peer ${peer.is_online ? "online" : "offline"}">
                <div class="live-peer-name">${esc(peer.peer_name)}</div>
                <div class="live-peer-meta">${esc(peer.role)} · ${peer.active_runs || 0} runs · CPU ${Math.round(peer.cpu || 0)}%</div>
              </div>`,
          )
          .join("")}
      </div>
      <div class="live-system-runs">
        ${snapshot.run_nodes
          .slice(0, 18)
          .map(
            (run) => `
              <div class="live-run" style="--run-tone:${_liveTone(run.status)}">
                <div class="live-run-dot"></div>
                <div class="live-run-main">
                  <div class="live-run-label">${esc(run.label)}</div>
                  <div class="live-run-meta">${esc(run.peer_name)} · ${esc(run.role)}${run.model ? ` · ${esc(run.model)}` : ""}</div>
                </div>
                <div class="live-run-status">${esc(run.status)}</div>
              </div>`,
          )
          .join("")}
      </div>
    </div>
    <div class="live-system-synapses">
      ${snapshot.synapses
        .slice(0, 14)
        .map(
          (edge) => `
            <div class="live-synapse">
              <span class="live-synapse-kind">${esc(edge.kind)}</span>
              <span>${esc(String(edge.source).replace(/^peer:|^run:/, ""))}</span>
              <span class="live-synapse-arrow">→</span>
              <span>${esc(String(edge.target).replace(/^peer:|^run:/, ""))}</span>
            </div>`,
        )
        .join("")}
    </div>
    <div class="live-system-events">
      ${(snapshot.recent_events || [])
        .slice(0, 8)
        .map(
          (event) => `
            <div class="live-event">
              <span class="live-event-type" style="color:${_eventTone(event.event_type)}">${esc(event.event_type)}</span>
              <span class="live-event-msg">${esc(event.message || `${event.source_agent || "system"} → ${event.target_agent || event.peer_name || "peer"}`)}</span>
            </div>`,
        )
        .join("")}
    </div>`;
}

window.renderLiveSystem = renderLiveSystem;
