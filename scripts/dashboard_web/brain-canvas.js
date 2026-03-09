/* brain-canvas.js — Agent Activity widget (DOM card grid, replaces canvas bubbles) */
(() => {
  'use strict';
  const S = { container: null, pollT: 0, ws: null, wsRetry: 0, wsT: 0, running: true, sessions: [], agents: [] };
  const esc = (s) => { const d = document.createElement('div'); d.textContent = s; return d.innerHTML; };

  function fmtDuration(startedAt) {
    if (!startedAt) return '';
    const diff = (Date.now() - new Date(startedAt + 'Z').getTime()) / 1000;
    if (diff < 60) return `${Math.round(diff)}s`;
    if (diff < 3600) return `${Math.round(diff / 60)}m`;
    return `${(diff / 3600).toFixed(1)}h`;
  }

  function parseMeta(s) {
    try { return typeof s === 'string' ? JSON.parse(s) : (s || {}); } catch { return {}; }
  }

  function toolType(agentId, type) {
    if (type?.includes('copilot') || agentId?.includes('copilot')) return 'copilot';
    return 'claude';
  }

  function toolIcon(tool) {
    return tool === 'copilot'
      ? '<svg viewBox="0 0 24 24" width="18" height="18" fill="currentColor"><path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm-1 15v-4H7l5-8v4h4l-5 8z"/></svg>'
      : '<svg viewBox="0 0 24 24" width="18" height="18" fill="currentColor"><circle cx="12" cy="12" r="10" fill="none" stroke="currentColor" stroke-width="1.5"/><path d="M8 12l2.5 2.5L16 9" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/></svg>';
  }

  function sessionCardHtml(sess) {
    const meta = parseMeta(sess.metadata);
    const tool = toolType(sess.session_id, sess.type);
    const pid = meta.pid || sess.session_id.split('-').pop();
    const tty = meta.tty || '';
    const cpu = meta.cpu != null ? `${meta.cpu}%` : '';
    const mem = meta.mem != null ? `${meta.mem}%` : '';
    const children = sess.children || [];
    const activeKids = children.filter(c => c.status === 'running');
    const isRunning = sess.status === 'running';
    const cls = ['agent-node', isRunning ? 'online' : 'offline', tool].filter(Boolean).join(' ');

    let childHtml = '';
    if (activeKids.length) {
      childHtml = `<div class="an-children">${activeKids.map(c => {
        const dur = c.duration_s ? `${Math.round(c.duration_s)}s` : '';
        const model = c.model ? `<span class="an-child-model">${esc(c.model)}</span>` : '';
        return `<div class="an-child"><span class="an-child-dot"></span>${esc((c.description || c.type || '').substring(0, 30))} ${model} ${dur}</div>`;
      }).join('')}</div>`;
    }

    const stats = [cpu && `CPU ${cpu}`, mem && `MEM ${mem}`].filter(Boolean).join(' · ');

    return `<div class="${cls}" data-session="${esc(sess.session_id)}">
      <div class="an-top">
        <span class="an-icon ${tool}">${toolIcon(tool)}</span>
        <span class="an-name">${esc(tool === 'copilot' ? 'Copilot' : 'Claude')}</span>
        <span class="an-dot ${isRunning ? 'on' : 'off'}"></span>
      </div>
      <div class="an-meta">${tty ? `TTY ${esc(tty)}` : ''}${tty && pid ? ' · ' : ''}PID ${esc(String(pid))}</div>
      ${stats ? `<div class="an-stats">${stats}</div>` : ''}
      ${children.length ? `<div class="an-agents">${activeKids.length} agent${activeKids.length !== 1 ? 's' : ''} running${children.length > activeKids.length ? ` · ${children.length - activeKids.length} done` : ''}</div>` : '<div class="an-agents idle-text">No sub-agents</div>'}
      ${childHtml}
    </div>`;
  }

  function recentCardHtml(agent) {
    const tool = toolType(agent.agent_id, agent.type);
    const ok = agent.status === 'completed';
    return `<div class="agent-node recent ${ok ? 'done' : 'failed'}">
      <div class="an-top">
        <span class="an-icon ${tool}">${toolIcon(tool)}</span>
        <span class="an-name">${esc(agent.type || 'agent')}</span>
        <span class="an-dot ${ok ? 'done' : 'fail'}"></span>
      </div>
      <div class="an-meta">${agent.model ? esc(agent.model) : ''}${agent.duration_s ? ` · ${Math.round(agent.duration_s)}s` : ''}</div>
      <div class="an-desc">${esc((agent.description || '').substring(0, 50))}</div>
    </div>`;
  }

  function renderCards() {
    if (!S.container) return;
    const grid = S.container.querySelector('.agent-grid') || (() => {
      const g = document.createElement('div'); g.className = 'agent-grid'; S.container.appendChild(g); return g;
    })();
    const sessions = S.sessions.filter(s => s.status === 'running');
    const recent = S.agents.filter(a => a.status !== 'running').slice(0, 6);

    if (!sessions.length && !recent.length) {
      grid.innerHTML = '<div class="an-empty">No active sessions</div>';
    } else {
      grid.innerHTML = sessions.map(sessionCardHtml).join('') +
        (recent.length ? `<div class="an-divider">Recent</div>${recent.map(recentCardHtml).join('')}` : '');
    }
  }

  function updateStats() {
    const el = document.getElementById('brain-stats');
    if (!el) return;
    const running = S.sessions.filter(s => s.status === 'running');
    const totalKids = running.reduce((n, s) => n + (s.children || []).filter(c => c.status === 'running').length, 0);
    const models = new Set();
    running.forEach(s => (s.children || []).forEach(c => { if (c.model) models.add(c.model); }));
    const plans = (window._dashboardPlans || []).filter(p => p.status === 'doing').length;
    el.textContent = `${running.length} session${running.length !== 1 ? 's' : ''} · ${totalKids} agent${totalKids !== 1 ? 's' : ''} · ${plans} plan${plans !== 1 ? 's' : ''} · ${models.size} model${models.size !== 1 ? 's' : ''}`;
  }

  function pollData() {
    Promise.all([
      fetch('/api/sessions').then(r => r.json()).catch(() => []),
      fetch('/api/agents').then(r => r.json()).catch(() => ({ running: [], recent: [] }))
    ]).then(([rawSessions, agentData]) => {
      const running = agentData.running || [];
      const childMap = new Map();
      running.forEach(a => {
        if (a.parent_session) {
          if (!childMap.has(a.parent_session)) childMap.set(a.parent_session, []);
          childMap.get(a.parent_session).push(a);
        }
      });
      S.sessions = (rawSessions || []).map(s => ({
        session_id: s.agent_id, type: s.type || 'claude-cli',
        status: s.status, metadata: s.metadata, started_at: s.started_at,
        children: (childMap.get(s.agent_id) || []).map(c => ({
          agent_id: c.agent_id, type: c.type, model: c.model,
          description: c.description, status: c.status || 'running', duration_s: c.duration_s
        }))
      }));
      S.agents = agentData.recent || [];
      window._dashboardAgentData = { sessions: S.sessions, orphan_agents: [] };
      renderCards();
      updateStats();
    }).catch(() => {});
  }

  const wsUrl = () => `${location.protocol === 'https:' ? 'wss' : 'ws'}://${location.host}/ws/brain`;
  function connectWs() {
    try { S.ws = new WebSocket(wsUrl()); } catch { S.ws = null; }
    if (!S.ws) return;
    S.ws.onopen = () => { S.wsRetry = 0; };
    S.ws.onmessage = () => pollData();
    S.ws.onerror = () => S.ws?.close();
    S.ws.onclose = () => { clearTimeout(S.wsT); S.wsT = setTimeout(connectWs, Math.min(30000, 1000 * Math.pow(2, S.wsRetry++))); };
  }

  window.initBrainCanvas = function(id) {
    window.destroyBrainCanvas();
    S.container = document.getElementById(id || 'brain-canvas-container');
    if (!S.container) return;
    S.container.style.height = 'auto';
    S.container.style.minHeight = '120px';
    S.container.innerHTML = '';
    pollData();
    S.pollT = setInterval(pollData, 10000);
    connectWs();
  };
  window.destroyBrainCanvas = function() {
    if (S.ws) S.ws.close(); S.ws = null; clearTimeout(S.wsT); S.wsT = 0;
    if (S.pollT) clearInterval(S.pollT); S.pollT = 0;
    if (S.container) S.container.innerHTML = '';
    S.container = null; S.sessions = []; S.agents = [];
  };
  window.updateBrainData = function() { pollData(); };
  window.toggleBrainFreeze = function() {
    S.running = !S.running;
    const btn = document.getElementById('brain-pause-btn');
    if (btn) btn.textContent = S.running ? '❚❚' : '▶';
    if (S.running) pollData();
  };
  window.rewindBrain = function() { pollData(); };

  const _boot = () => window.initBrainCanvas('brain-canvas-container');
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', _boot);
  else setTimeout(_boot, 100);
})();