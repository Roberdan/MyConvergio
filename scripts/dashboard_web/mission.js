function _progressGradient(pct) {
  // Red→Orange→Gold→Green as completion approaches 100%
  if (pct >= 100) return { color: '#00cc6a', gradient: 'linear-gradient(90deg, #00cc6a, #00ff88)' };
  if (pct >= 75) return { color: '#4dd64d', gradient: 'linear-gradient(90deg, #e6a117, #4dd64d)' };
  if (pct >= 50) return { color: '#e6a117', gradient: 'linear-gradient(90deg, #ff6633, #e6a117)' };
  if (pct >= 25) return { color: '#ff6633', gradient: 'linear-gradient(90deg, #ee3344, #ff6633)' };
  return { color: '#ee3344', gradient: 'linear-gradient(90deg, #cc1133, #ee3344)' };
}
function _substatusBadge(substatus) {
  const badges = {
    waiting_ci: { icon: Icons.clock(11), label: 'CI', color: '#00d4ff' },
    waiting_review: { icon: Icons.eye(11), label: 'Review', color: '#e6a117' },
    waiting_merge: { icon: Icons.gitMerge(11), label: 'Merge', color: '#a855f7' },
    waiting_thor: { icon: Icons.shield(11), label: 'Thor', color: '#ff9500' },
    agent_running: { icon: Icons.cpu(11), label: 'Agent', color: '#0066ff' },
  };
  const badge = badges[substatus];
  return badge
    ? `<span class="substatus-badge" style="color:${badge.color}" title="${esc(substatus)}">${badge.icon} ${badge.label}</span>`
    : '';
}
function _healthIcon(code) {
  const icons = {
    blocked:
      '<svg width="14" height="14" viewBox="0 0 24 24" fill="#ee3344" style="vertical-align:-2px"><path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm-2 15l-5-5 1.41-1.41L10 14.17l7.59-7.59L19 8l-9 9z"/></svg>',
    stale:
      '<svg width="14" height="14" viewBox="0 0 24 24" fill="#ee3344" style="vertical-align:-2px"><path d="M11.99 2C6.47 2 2 6.48 2 12s4.47 10 9.99 10C17.52 22 22 17.52 22 12S17.52 2 11.99 2zM12 20c-4.42 0-8-3.58-8-8s3.58-8 8-8 8 3.58 8 8-3.58 8-8 8zm.5-13H11v6l5.25 3.15.75-1.23-4.5-2.67z"/></svg>',
    stuck_deploy:
      '<svg width="14" height="14" viewBox="0 0 24 24" fill="#ffb700" style="vertical-align:-2px"><path d="M1 21h22L12 2 1 21zm12-3h-2v-2h2v2zm0-4h-2v-4h2v4z"/></svg>',
    manual_required:
      '<svg width="14" height="14" viewBox="0 0 24 24" fill="#ffb700" style="vertical-align:-2px"><path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm1 15h-2v-2h2v2zm0-4h-2V7h2v6z"/></svg>',
    thor_stuck:
      '<svg width="14" height="14" viewBox="0 0 24 24" fill="#ffb700" style="vertical-align:-2px"><path d="M12 1L8 5v3H5l-2 4h4l-3 11h2l7-9H9l3-5h5l3-4h-4l1-4h-5z"/></svg>',
    near_complete_stuck:
      '<svg width="14" height="14" viewBox="0 0 24 24" fill="#ffb700" style="vertical-align:-2px"><path d="M18 8h-1V6c0-2.76-2.24-5-5-5S7 3.24 7 6v2H6c-1.1 0-2 .9-2 2v10c0 1.1.9 2 2 2h12c1.1 0 2-.9 2-2V10c0-1.1-.9-2-2-2zM12 17c-1.1 0-2-.9-2-2s.9-2 2-2 2 .9 2 2-.9 2-2 2zm3.1-9H8.9V6c0-1.71 1.39-3.1 3.1-3.1 1.71 0 3.1 1.39 3.1 3.1v2z"/></svg>',
    preflight_missing:
      '<svg width="14" height="14" viewBox="0 0 24 24" fill="#ffb700" style="vertical-align:-2px"><path d="M19 3H5c-1.1 0-2 .9-2 2v14l4-4h12c1.1 0 2-.9 2-2V5c0-1.1-.9-2-2-2zm-6 9h-2V6h2v6zm0 4h-2v-2h2v2z"/></svg>',
    preflight_stale:
      '<svg width="14" height="14" viewBox="0 0 24 24" fill="#ffb700" style="vertical-align:-2px"><path d="M13 3a9 9 0 1 0 8.95 10h-2.02A7 7 0 1 1 13 5v4l5-5-5-5v4z"/></svg>',
    preflight_context:
      '<svg width="14" height="14" viewBox="0 0 24 24" fill="#ffb700" style="vertical-align:-2px"><path d="M12 3L1 9l11 6 9-4.91V17h2V9L12 3zm0 13L3.74 11.5 12 7l8.26 4.5L12 16z"/></svg>',
    preflight_blocked:
      '<svg width="14" height="14" viewBox="0 0 24 24" fill="#ee3344" style="vertical-align:-2px"><path d="M12 2a10 10 0 1 0 10 10A10 10 0 0 0 12 2zm5 11H7v-2h10z"/></svg>',
  };
  return icons[code] || icons.blocked;
}
function _renderHealthAlerts(health, planId, peer) {
  if (!health || !health.length) return '';
  const hasCritical = health.some((h) => h.severity === 'critical');
  let html = `<div class="plan-health-bar ${hasCritical ? 'health-critical' : 'health-warning'}" onclick="event.stopPropagation()">`;
  html += `<div class="plan-health-alerts">`;
  health.forEach((h) => {
    html += `<div class="plan-health-item plan-health-${h.severity}">${_healthIcon(h.code)} <span>${esc(h.message)}</span></div>`;
  });
  const actionable = health.some(
    (h) => h.severity === 'critical' || h.code === 'thor_stuck' || h.code === 'preflight_blocked',
  );
  if (!actionable) {
    html += `</div></div>`;
    return html;
  }
  html += `</div><div class="plan-health-actions">`;
  const hasThor = health.some((h) => h.code === 'thor_stuck');
  if (hasThor) {
    html += `<button class="plan-health-btn plan-health-btn-thor" onclick="event.stopPropagation();runThorValidation(${planId})" title="Run Thor validation on submitted tasks"><svg width="16" height="16" viewBox="0 0 24 24" fill="var(--gold)"><path d="M12 1L8 5v3H5l-2 4h4l-3 11h2l7-9H9l3-5h5l3-4h-4l1-4h-5z"/></svg> Run Thor</button>`;
  }
  html += `<button class="plan-health-btn plan-health-btn-resume" onclick="event.stopPropagation();resumePlanExecution(${planId},'${esc(peer || 'local')}')" title="Resume/fix plan execution"><svg width="16" height="16" viewBox="0 0 24 24" fill="currentColor"><polygon points="5,3 19,12 5,21"/></svg> Resume</button>`;
  html += `<button class="plan-health-btn plan-health-btn-term" onclick="event.stopPropagation();openPlanTerminal(${planId},'${esc(peer || 'local')}')" title="Open terminal on plan"><svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="4 17 10 11 4 5"></polyline><line x1="12" y1="19" x2="20" y2="19"></line></svg> Debug</button>`;
  html += `</div></div>`;
  return html;
}
window.openPlanTerminal = function (planId, peer) {
  if (typeof termMgr !== 'undefined') {
    const session = 'plan-' + planId;
    termMgr.open(
      peer === 'local' ||
        peer === ((window.DashboardState && window.DashboardState.localPeerName) || 'local')
        ? 'local'
        : peer,
      'Plan #' + planId,
      session,
    );
  }
};
window.resumePlanExecution = function (planId, peer) {
  const planData =
    window.DashboardState &&
    window.DashboardState.lastMeshData &&
    window.DashboardState.lastMeshData
      .flatMap((n) => (n.plans || []).map((p) => ({ ...p, node: n.peer_name })))
      .find((p) => p.id === planId);
  const assignedHost = planData ? planData.node : peer || 'local';
  const target =
    assignedHost === 'local' ||
    assignedHost === ((window.DashboardState && window.DashboardState.localPeerName) || 'local')
      ? 'local'
      : assignedHost;

  if (typeof termMgr === 'undefined') return;

  const session = 'plan-' + planId;
  const tabId = termMgr.open(target, 'Resume #' + planId, session);

  const tab = termMgr.tabs.find((t) => t.id === tabId);
  if (!tab) return;

  const sendResume = () => {
    if (tab.ws && tab.ws.readyState === WebSocket.OPEN) {
      const cmd = 'cd ~/.claude && claude --model sonnet -p "/execute ' + planId + '"\n';
      tab.ws.send(new TextEncoder().encode(cmd));
    }
  };

  let attempts = 0;
  const waitForOpen = setInterval(() => {
    attempts++;
    if (tab.ws && tab.ws.readyState === WebSocket.OPEN) {
      clearInterval(waitForOpen);
      setTimeout(sendResume, 800);
    } else if (attempts > 50) {
      clearInterval(waitForOpen);
    }
  }, 100);
};
function _renderOnePlan(m) {
  const p = m.plan,
    health = m.health || [],
    rawPct = p.tasks_total > 0 ? Math.round((100 * p.tasks_done) / p.tasks_total) : 0,
    allValidated =
      m.waves && m.waves.length && m.waves.every((w) => w.validated_at || w.status === 'pending'),
    pct = rawPct >= 100 && !allValidated ? 95 : rawPct,
    pg = _progressGradient(pct),
    ringColor = pg.color,
    hostName = p.execution_peer || _resolveHost(p.execution_host),
    isRemote =
      hostName &&
      hostName !== 'local' &&
      hostName !== ((window.DashboardState && window.DashboardState.localPeerName) || 'local'),
    blocked = (m.tasks || []).filter((t) => t.status === 'blocked').length,
    running = (m.tasks || []).filter((t) => t.status === 'in_progress').length,
    waitingCi = (m.tasks || []).filter((t) => t.substatus === 'waiting_ci').length,
    waitingReview = (m.tasks || []).filter((t) => t.substatus === 'waiting_review').length,
    waitingMerge = (m.tasks || []).filter((t) => t.substatus === 'waiting_merge').length,
    waitingThor = (m.tasks || []).filter((t) => t.substatus === 'waiting_thor').length,
    agentRunning = (m.tasks || []).filter((t) => t.substatus === 'agent_running').length,
    hasCritical = health.some((h) => h.severity === 'critical'),
    nodeLabel = isRemote
      ? `<span class="host-badge-prominent">${esc(hostName)}</span>`
      : hostName && hostName !== 'local'
        ? `<span class="host-badge-local">${esc(hostName)}</span>`
        : '';
  const stopBtn =
    p.status === 'doing'
      ? `<button class="mission-stop-btn" onclick="event.stopPropagation();stopPlan(${p.id})" title="Stop execution"><svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor"><rect x="4" y="4" width="16" height="16" rx="2"/></svg></button>`
      : '';
  const resetBtn =
    p.status !== 'done'
      ? `<button class="mission-reset-btn" onclick="event.stopPropagation();resetPlan(${p.id})" title="Reset to todo"><svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><path d="M1 4v6h6"/><path d="M3.51 15a9 9 0 105.64-11.36L3 10"/></svg></button>`
      : '';
  const cancelBtn =
    p.status !== 'done'
      ? `<button class="mission-cancel-btn" onclick="event.stopPropagation();cancelPlan(${p.id})" title="Cancel plan"><svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M3 6h18M19 6v14a2 2 0 01-2 2H7a2 2 0 01-2-2V6m3 0V4a2 2 0 012-2h4a2 2 0 012 2v2"/></svg></button>`
      : '';
  let html = `<div class="mission-plan${hasCritical ? ' mission-plan-critical' : health.length ? ' mission-plan-warning' : ''}" onclick="filterTasks(${p.id})"><div style="margin-bottom:6px"><span class="mission-id">#${p.id}</span><span class="mission-name">&nbsp;${esc(p.name)}</span>${statusDot(p.status === 'doing' ? 'in_progress' : p.status)}${health.length ? `<span class="health-badge health-badge-${hasCritical ? 'critical' : 'warning'}" title="${health.map((h) => h.message).join('; ')}">${hasCritical ? 'ALERT' : 'WARN'}</span>` : ''}${nodeLabel}${p.project_name ? `<span class="badge badge-project">${esc(p.project_name)}</span>` : ''}<button class="mission-delegate-btn" onclick="event.stopPropagation();showDelegatePlanDialog(${p.id},'${esc(p.name)}')" title="Delegate to mesh node"><svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M22 2L11 13"/><path d="M22 2L15 22L11 13L2 9L22 2Z"/></svg></button>${p.status === 'todo' ? `<button class="mission-start-btn" onclick="event.stopPropagation();showStartPlanDialog(${p.id},'${esc(p.name)}')" title="Start plan execution"><svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor"><polygon points="5,3 19,12 5,21"/></svg></button>` : ''}${stopBtn}${resetBtn}${cancelBtn}</div>${_renderHealthAlerts(health, p.id, hostName)}${p.human_summary ? `<div class="mission-summary">${esc(p.human_summary)}</div>` : ''}<div class="mission-progress">${_progressRing(pct, 56, ringColor)}<div class="mission-progress-bars"><div class="mission-progress-label"><span>Done ${p.tasks_done || 0}/${p.tasks_total || 0}</span><span style="color:var(--cyan)">${pct}%</span></div><div class="mission-progress-track"><div class="mission-progress-fill" style="width:${pct}%;background:${pg.gradient}"></div></div><div style="display:flex;gap:6px;font-size:9px;color:var(--text-dim);margin-top:4px;flex-wrap:wrap"><span>${running > 0 ? `<span style="color:var(--gold)">${running} running</span>` : ''}</span><span>${blocked > 0 ? `<span style="color:var(--red)">${blocked} blocked</span>` : ''}</span>${waitingCi > 0 ? _substatusBadge('waiting_ci') : ''}${waitingReview > 0 ? _substatusBadge('waiting_review') : ''}${waitingMerge > 0 ? _substatusBadge('waiting_merge') : ''}${waitingThor > 0 ? _substatusBadge('waiting_thor') : ''}${agentRunning > 0 ? _substatusBadge('agent_running') : ''}</div></div></div>`;
  html += typeof renderWaveGantt === 'function' ? renderWaveGantt(m.waves, p) : '';
  html += typeof renderTaskFlow === 'function' ? renderTaskFlow(m.tasks, p) : '';
  return html + '</div>';
}
function renderMission(data) {
  const st = window.DashboardState;
  st.lastMissionData = data;
  st.allMissionPlans = data && data.plans ? data.plans : data && data.plan ? [data] : [];
  window._dashboardPlans = st.allMissionPlans;
  if (!st.allMissionPlans.length) {
    $('#mission-content').innerHTML = '<span style="color:#5a6080">No active mission</span>';
    $('#task-table tbody').innerHTML = '';
    return;
  }
  $('#mission-content').innerHTML = st.allMissionPlans.map(_renderOnePlan).join('');
  renderTaskPipeline();
}

window.runThorValidation = async function (planId) {
  try {
    const r = await fetch(`/api/plans/${planId}/validate`, { method: 'POST' });
    const d = await r.json();
    if (d.ok) {
      showToast('Thor', `Validated ${d.validated || 0} tasks`, null, 'info');
    } else {
      showToast('Thor', d.error || 'Validation failed', null, 'error');
    }
    if (typeof refreshAll === 'function') refreshAll();
  } catch (e) {
    showToast('Thor', 'Request failed: ' + e.message, null, 'error');
  }
};

window.renderMission = renderMission;
