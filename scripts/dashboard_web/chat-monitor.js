(function () {
  const byId = (id) => document.getElementById(id);
  const esc = (v) =>
    String(v ?? '').replace(/[&<>"']/g, (m) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[m]);
  const state = { key: '', timer: null, sse: null, sseKey: '' };
  const PLAN_SSE_ENDPOINT = '/api/plan/start';

  async function jsonFetch(url) {
    const res = await fetch(url);
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    return res.json();
  }

  function activeState() {
    return window.chatTabs?.getActiveState?.() || null;
  }

  function iconStatus(status) {
    if (typeof window.statusDot === 'function') return window.statusDot(status);
    return esc(status || 'pending');
  }

  function iconThor(validatedAt) {
    if (typeof window.thorIcon === 'function') return window.thorIcon(validatedAt);
    return validatedAt ? '[ok]' : '';
  }

  async function resolveContext() {
    const tab = activeState();
    const sid = String(tab?.session_id || '');
    if (!sid) return null;
    const sessions = await jsonFetch('/api/chat/sessions');
    const session = (sessions.sessions || []).find((row) => row.id === sid);
    const planId = Number(session?.plan_id || 0);
    if (!planId) return { sid, planId: 0, model: tab?.model || 'gpt-5.3-codex' };
    return { sid, planId, model: tab?.model || 'gpt-5.3-codex' };
  }

  function computeStatus(planData) {
    const plan = planData?.plan || {};
    const tasks = Array.isArray(planData?.tasks) ? planData.tasks : [];
    const waves = Array.isArray(planData?.waves) ? planData.waves : [];
    const missionStatus = {
      done: Number(plan.tasks_done || 0),
      total: Number(plan.tasks_total || 0),
      running: tasks.filter((t) => t.status === 'in_progress').length,
      blocked: tasks.filter((t) => t.status === 'blocked').length,
      waitingThor: tasks.filter((t) => !t.validated_at && (t.substatus === 'waiting_thor' || t.status === 'submitted')).length,
    };
    const taskPipeline = tasks
      .slice()
      .sort((a, b) => String(a.wave_id || '').localeCompare(String(b.wave_id || '')) || Number(a.id || 0) - Number(b.id || 0))
      .slice(0, 14);
    const waveCompletion = waves.map((w) => {
      const total = Number(w.tasks_total || 0);
      const done = Number(w.tasks_done || 0);
      return { waveId: String(w.wave_id || 'W?'), name: String(w.name || ''), pct: total > 0 ? Math.round((100 * done) / total) : 0, validatedAt: w.validated_at };
    });
    return { missionStatus, taskPipeline, waveCompletion };
  }

  function renderMonitor(ctx, payload) {
    const root = byId('chat-monitor-root');
    if (!root) return;
    if (!ctx || !ctx.sid) {
      root.innerHTML = '<div class="chat-monitor-empty">Open a chat session to start monitoring.</div>';
      return;
    }
    if (!ctx.planId) {
      root.innerHTML = '<div class="chat-monitor-empty">No plan linked yet. Approve and execute to enter MONITOR phase.</div>';
      return;
    }
    const { missionStatus, taskPipeline, waveCompletion } = computeStatus(payload);
    const total = missionStatus.total || 0;
    const donePct = total > 0 ? Math.round((100 * missionStatus.done) / total) : 0;
    root.innerHTML = `
      <div class="chat-monitor-kpi">
        <span>Plan #${ctx.planId}</span>
        <span>Done ${missionStatus.done}/${missionStatus.total}</span>
        <span>Run ${missionStatus.running}</span>
        <span>Thor ${missionStatus.waitingThor}</span>
        <span>Blocked ${missionStatus.blocked}</span>
      </div>
      <div class="chat-monitor-progress"><div class="chat-monitor-progress-fill" style="width:${donePct}%"></div></div>
      <div class="chat-monitor-waves">
        ${waveCompletion
          .map(
            (w) => `<div class="chat-monitor-wave">
              <span>${esc(w.waveId)}</span>
              <span class="chat-monitor-wave-name">${esc(w.name)}</span>
              <span class="chat-monitor-wave-pct">${w.pct}% ${iconThor(w.validatedAt)}</span>
            </div>`,
          )
          .join('') || '<div class="chat-monitor-empty">No waves available yet.</div>'}
      </div>
      <div class="chat-monitor-table-wrap">
        <table class="chat-monitor-table">
          <thead><tr><th>ID</th><th>Task</th><th>Status</th><th>Wave</th></tr></thead>
          <tbody>
            ${taskPipeline
              .map(
                (t) => `<tr>
                  <td>${esc(t.task_id || 'T?')}</td>
                  <td>${esc(String(t.title || '—').slice(0, 56))}</td>
                  <td>${iconStatus(t.status)} ${iconThor(t.validated_at)}</td>
                  <td>${esc(t.wave_id || 'W?')}</td>
                </tr>`,
              )
              .join('') || '<tr><td colspan="4" class="chat-monitor-empty">No task pipeline data yet.</td></tr>'}
          </tbody>
        </table>
      </div>`;
  }

  function connectSse(ctx) {
    const tab = activeState();
    const enableSse = Boolean(tab?.monitor_sse_enabled);
    const root = byId('chat-monitor-root');
    if (!enableSse || !ctx?.planId) {
      if (state.sse) state.sse.close();
      state.sse = null;
      state.sseKey = '';
      return;
    }
    const url = String(tab?.monitor_sse_url || `${PLAN_SSE_ENDPOINT}?plan_id=${ctx.planId}&cli=copilot&target=local&model=${encodeURIComponent(ctx.model)}`);
    if (state.sseKey === url && state.sse) return;
    if (state.sse) state.sse.close();
    state.sseKey = url;
    const es = new EventSource(url);
    es.addEventListener('log', () => window.chatMonitor?.refresh?.());
    es.addEventListener('done', () => window.chatMonitor?.refresh?.());
    es.onerror = () => {
      es.close();
      state.sse = null;
      if (root) root.dataset.monitorSse = 'error';
    };
    state.sse = es;
    if (root) root.dataset.monitorSse = 'connected';
  }

  async function refreshMonitor() {
    try {
      const ctx = await resolveContext();
      const key = `${ctx?.sid || ''}:${ctx?.planId || 0}`;
      if (!ctx?.planId) {
        state.key = key;
        connectSse(ctx);
        renderMonitor(ctx, null);
        return;
      }
      const data = await jsonFetch(`/api/plan/${ctx.planId}`);
      state.key = key;
      connectSse(ctx);
      renderMonitor(ctx, data);
    } catch (err) {
      const root = byId('chat-monitor-root');
      if (root) root.innerHTML = `<div class="chat-monitor-empty">Monitor unavailable: ${esc(err.message)}</div>`;
    }
  }

  function boot() {
    if (state.timer) clearInterval(state.timer);
    state.timer = setInterval(refreshMonitor, 4000);
    refreshMonitor();
    window.chatMonitor = { refresh: refreshMonitor };
  }

  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', boot);
  else boot();
})();
