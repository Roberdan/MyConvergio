function _orgTone(role) {
  if (role === "coordinator") return "var(--cyan)";
  if (role === "validator") return "var(--gold)";
  return "var(--green)";
}

function _orgTaskTone(status) {
  if (status === "blocked") return "var(--red)";
  if (status === "submitted") return "var(--gold)";
  if (status === "done") return "var(--green)";
  return "var(--cyan)";
}

function _resolveOrgHost(task, plan, hostToPeer) {
  const raw = task.executor_host || plan.execution_peer || plan.execution_host || "local";
  if (!raw) return "local";
  if (hostToPeer && hostToPeer[raw]) return hostToPeer[raw];
  const norm = raw.toLowerCase();
  for (const [host, peer] of Object.entries(hostToPeer || {})) {
    const lhs = host.toLowerCase();
    if (lhs.includes(norm) || norm.includes(lhs)) return peer;
  }
  return raw;
}

function _collectOrgUnits() {
  const st = window.DashboardState || {};
  const hostToPeer = st.hostToPeer || {};
  const mesh = Array.isArray(st.lastMeshData) ? st.lastMeshData : [];
  const meshByPeer = new Map(mesh.map((peer) => [peer.peer_name, peer]));
  const units = new Map();

  const ensureUnit = (peerName) => {
    if (!units.has(peerName)) {
      const peer = meshByPeer.get(peerName) || {};
      units.set(peerName, {
        peer_name: peerName,
        role: peer.role || "worker",
        is_online: peer.is_online !== false,
        cpu: peer.cpu || 0,
        mem_used_gb: peer.mem_used_gb || 0,
        mem_total_gb: peer.mem_total_gb || 0,
        plans: new Set(),
        agents: new Map(),
        tasks: [],
      });
    }
    return units.get(peerName);
  };

  (st.allMissionPlans || []).forEach((mission) => {
    const plan = mission.plan || {};
    (mission.tasks || []).forEach((task) => {
      if (!["in_progress", "submitted", "blocked"].includes(task.status)) return;
      const peerName = _resolveOrgHost(task, plan, hostToPeer);
      const unit = ensureUnit(peerName);
      const agentKey = `${task.executor_agent || "unassigned"}|${task.model || ""}`;
      unit.plans.add(plan.id);
      unit.tasks.push({
        planId: plan.id,
        taskId: task.task_id || "—",
        title: task.title || "",
        status: task.status,
        agent: task.executor_agent || "unassigned",
        model: task.model || "",
      });
      if (!unit.agents.has(agentKey)) {
        unit.agents.set(agentKey, {
          agent: task.executor_agent || "unassigned",
          model: task.model || "",
          count: 0,
        });
      }
      unit.agents.get(agentKey).count += 1;
    });
  });

  mesh.forEach((peer) => {
    if ((peer.plans || []).length) {
      const unit = ensureUnit(peer.peer_name);
      (peer.plans || []).forEach((plan) => unit.plans.add(plan.id));
    }
  });

  return Array.from(units.values()).sort((a, b) => {
    if (a.role === "coordinator" && b.role !== "coordinator") return -1;
    if (b.role === "coordinator" && a.role !== "coordinator") return 1;
    return b.tasks.length - a.tasks.length;
  });
}

function _snapshotFromClientState() {
  const units = _collectOrgUnits();
  return {
    summary: {
      nodes_total: units.length,
      nodes_online: units.filter((unit) => unit.is_online).length,
      plans_active: new Set(
        units.flatMap((unit) => Array.from(unit.plans || [])),
      ).size,
      agent_pods: units.reduce((sum, unit) => sum + unit.agents.size, 0),
      live_tasks: units.reduce((sum, unit) => sum + unit.tasks.length, 0),
    },
    units: units.map((unit) => ({
      peer_name: unit.peer_name,
      node_role: unit.role,
      is_online: unit.is_online,
      cpu: unit.cpu,
      mem_used_gb: unit.mem_used_gb,
      mem_total_gb: unit.mem_total_gb,
      plan_ids: Array.from(unit.plans || []),
      agent_pods: Array.from(unit.agents.values()).map((agent) => ({
        agent: agent.agent,
        model: agent.model,
        role: "executor",
        task_count: agent.count,
      })),
      active_tasks: unit.tasks.map((task) => ({
        plan_id: task.planId,
        task_id: task.taskId,
        title: task.title,
        status: task.status,
        agent: task.agent,
        model: task.model,
        role: "executor",
      })),
    })),
  };
}

function renderAgentOrganization(data) {
  const root = document.getElementById("agent-organization-content");
  if (!root) return;

  const snapshot =
    data || (window.DashboardState && window.DashboardState.lastOrganizationData) || _snapshotFromClientState();
  const units = Array.isArray(snapshot.units) ? snapshot.units : [];
  const summary = snapshot.summary || {};
  if (!units.length) {
    root.innerHTML =
      '<span style="color:var(--text-dim)">No active squads. Start a plan to see live agent teams.</span>';
    return;
  }

  root.innerHTML = `
    <div style="display:flex;gap:8px;flex-wrap:wrap;margin-bottom:12px">
      <div style="padding:6px 10px;border:1px solid rgba(0,229,255,0.25);border-radius:999px;color:var(--cyan);font-size:11px">${summary.nodes_online || 0}/${summary.nodes_total || units.length} nodes online</div>
      <div style="padding:6px 10px;border:1px solid rgba(0,255,136,0.25);border-radius:999px;color:var(--green);font-size:11px">${summary.agent_pods || 0} active agent pods</div>
      <div style="padding:6px 10px;border:1px solid rgba(255,183,0,0.25);border-radius:999px;color:var(--gold);font-size:11px">${summary.live_tasks || 0} live tasks</div>
    </div>
    <div style="display:grid;grid-template-columns:repeat(auto-fit,minmax(230px,1fr));gap:12px">
      ${units
        .map((unit) => {
          const tone = _orgTone(unit.node_role);
          const memory = unit.mem_total_gb
            ? `${Math.round(unit.mem_used_gb)}/${Math.round(unit.mem_total_gb)}GB`
            : "n/a";
          return `
            <div style="border:1px solid rgba(255,255,255,0.08);border-radius:12px;background:linear-gradient(180deg,rgba(255,255,255,0.04),rgba(255,255,255,0.02));padding:12px">
              <div style="display:flex;justify-content:space-between;align-items:center;gap:8px;margin-bottom:10px">
                <div>
                  <div style="font-weight:700;color:${tone};letter-spacing:0.02em">${esc(unit.peer_name)}</div>
                  <div style="font-size:11px;color:var(--text-dim)">${esc(unit.node_role)} squad · ${(unit.plan_ids || []).length} plans</div>
                </div>
                <div style="text-align:right">
                  <div style="font-size:11px;color:${unit.is_online ? "var(--green)" : "var(--red)"}">${unit.is_online ? "online" : "offline"}</div>
                  <div style="font-size:10px;color:var(--text-dim)">CPU ${Math.round(unit.cpu || 0)}% · MEM ${memory}</div>
                </div>
              </div>
              <div style="display:flex;flex-wrap:wrap;gap:6px;margin-bottom:10px">
                ${(unit.agent_pods || [])
                  .slice(0, 4)
                  .map(
                    (agent) => `
                      <span style="font-size:10px;padding:4px 8px;border-radius:999px;background:rgba(0,0,0,0.18);border:1px solid rgba(255,255,255,0.08);color:var(--text)">
                        ${esc(agent.role || "executor")} · ${esc(agent.agent.substring(0, 16))}${agent.model ? ` · ${esc(_shortModel(agent.model))}` : ""} · ${agent.task_count}
                      </span>`,
                  )
                  .join("")}
                ${(unit.agent_pods || []).length > 4 ? `<span style="font-size:10px;color:var(--text-dim)">+${(unit.agent_pods || []).length - 4} more</span>` : ""}
              </div>
              <div style="display:flex;flex-direction:column;gap:6px">
                ${(unit.active_tasks || [])
                  .slice(0, 5)
                  .map(
                    (task) => `
                      <div style="display:flex;justify-content:space-between;gap:8px;padding:7px 8px;border-radius:8px;background:rgba(0,0,0,0.16)">
                        <div style="min-width:0">
                          <div style="font-size:11px;color:var(--cyan);font-weight:600">#${task.plan_id} · ${esc(task.task_id)}</div>
                          <div style="font-size:11px;color:var(--text);white-space:nowrap;overflow:hidden;text-overflow:ellipsis">${esc(task.title)}</div>
                        </div>
                        <div style="text-align:right;flex-shrink:0">
                          <div style="font-size:10px;color:${_orgTaskTone(task.status)}">${esc(task.status)}</div>
                          <div style="font-size:10px;color:var(--text-dim)">${esc(task.role || "executor")} · ${esc(_shortModel(task.model || task.agent || ""))}</div>
                        </div>
                      </div>`,
                  )
                  .join("")}
                ${(unit.active_tasks || []).length > 5 ? `<div style="font-size:10px;color:var(--text-dim)">+${(unit.active_tasks || []).length - 5} more live tasks</div>` : ""}
              </div>
            </div>`;
        })
        .join("")}
    </div>`;
}

window.renderAgentOrganization = renderAgentOrganization;
