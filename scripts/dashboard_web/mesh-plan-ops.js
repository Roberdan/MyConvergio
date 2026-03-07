/**
 * Mesh plan operations — start, full sync, cancel, reset.
 * Depends on: mesh-actions.js (ansiToHtml, showOutputModal loaded first)
 */

function quickPreflight(planId, el, btn, target) {
  if (!el) return;
  if (target === 'local') {
    el.innerHTML = '✓ Sync OK';
    el.style.color = 'var(--green)';
    btn.disabled = false;
    return;
  }
  el.innerHTML = '⟳ Checking sync…';
  el.style.color = 'var(--text-dim)';
  btn.disabled = true;
  const es = new EventSource(
    `/api/plan/preflight?plan_id=${planId}&target=${encodeURIComponent(target)}`,
  );
  const t = setTimeout(() => {
    es.close();
    el.innerHTML = '⚠ Could not verify — start anyway?';
    el.style.color = 'var(--gold)';
    btn.disabled = false;
  }, 10000);
  es.addEventListener('result', (e) => {
    clearTimeout(t);
    es.close();
    const d = JSON.parse(e.data);
    el.innerHTML = d.ok ? '✓ Sync OK' : `✗ Sync issues: ${esc(d.detail || '')}`;
    el.style.color = d.ok ? 'var(--green)' : 'var(--red)';
    btn.disabled = false;
  });
  es.onerror = () => {
    clearTimeout(t);
    es.close();
    el.innerHTML = '⚠ Could not verify — start anyway?';
    el.style.color = 'var(--gold)';
    btn.disabled = false;
  };
}

window.showStartPlanDialog = function (planId, planName) {
  const MODELS = [
    'gpt-5.3-codex',
    'claude-opus-4.6',
    'claude-sonnet-4.6',
    'gpt-5-mini',
    'claude-haiku-4.5',
  ];
  const modelOpts = MODELS.map(
    (m, i) => `<option value="${m}"${i === 0 ? ' selected' : ''}>${m}</option>`,
  ).join('');
  const overlay = document.createElement('div');
  overlay.className = 'modal-overlay';
  overlay.innerHTML = `<div class="modal-box" style="max-width:460px">
    <div class="modal-title">Start #${planId} ${esc((planName || '').substring(0, 25))}<span class="modal-close" onclick="this.closest('.modal-overlay').remove()">✕</span></div>
    <div style="padding:14px;display:flex;flex-direction:column;gap:12px">
      <div>
        <div style="font-size:11px;color:var(--text-dim);text-transform:uppercase;letter-spacing:1px;margin-bottom:6px">Target Node</div>
        <div id="spd-nodes" style="display:flex;flex-direction:column;gap:4px">
          <div class="spd-node" data-sel="1" data-target="local" style="display:flex;align-items:center;gap:10px;padding:10px 12px;background:rgba(0,229,255,0.08);border:1px solid rgba(0,229,255,0.4);border-radius:6px;cursor:pointer"><span class="spd-dot" style="color:var(--cyan);font-size:14px;width:14px">●</span><span style="flex:1;font-size:13px;color:var(--text)">Local (this machine)</span></div>
          <div id="spd-loading" style="font-size:11px;color:var(--text-dim);padding:4px 2px">Loading peers…</div>
        </div>
      </div>
      <div>
        <div style="font-size:11px;color:var(--text-dim);text-transform:uppercase;letter-spacing:1px;margin-bottom:6px">Model</div>
        <select id="spd-model" style="width:100%;padding:8px 10px;background:var(--bg-card);border:1px solid var(--border);border-radius:6px;color:var(--text);font-size:13px">${modelOpts}</select>
      </div>
      <div style="font-size:11px;color:var(--green)" id="spd-preflight">✓ Sync OK</div>
      <div style="display:flex;gap:8px;justify-content:flex-end;padding-top:4px">
        <button class="preflight-action-btn" style="border-color:var(--text-dim);color:var(--text-dim)" onclick="this.closest('.modal-overlay').remove()">Cancel</button>
        <button id="spd-start" class="preflight-action-btn" style="border-color:var(--cyan);color:var(--cyan)">▶ Start Plan</button>
      </div>
    </div>
  </div>`;
  document.body.appendChild(overlay);
  fetch('/api/mesh')
    .then((r) => r.json())
    .then((data) => {
      const peers = Array.isArray(data.peers) ? data.peers : Array.isArray(data) ? data : [];
      const wrap = overlay.querySelector('#spd-nodes');
      overlay.querySelector('#spd-loading').remove();
      peers.forEach((p) => {
        const online = p.status === 'online' || p.online !== false,
          cpu = p.cpu != null ? `CPU: ${p.cpu}%` : '---';
        const card = document.createElement('div');
        card.className = 'spd-node';
        card.dataset.target = p.name || p.host || p.id;
        card.style.cssText = `display:flex;align-items:center;gap:10px;padding:10px 12px;background:rgba(140,140,140,0.04);border:1px solid rgba(140,140,140,0.2);border-radius:6px;${online ? 'cursor:pointer' : 'opacity:0.45;pointer-events:none'}`;
        card.innerHTML = `<span class="spd-dot" style="color:var(--text-dim);font-size:14px;width:14px">○</span><span style="flex:1;font-size:13px;color:var(--text)">${esc(p.name || p.host || p.id)}</span><span style="font-size:11px;color:var(--text-dim)">${esc(cpu)}</span>`;
        wrap.appendChild(card);
      });
    })
    .catch(() => {
      const l = overlay.querySelector('#spd-loading');
      if (l) l.textContent = 'No peers found';
    });
  overlay.querySelector('#spd-nodes').addEventListener('click', (e) => {
    const card = e.target.closest('.spd-node');
    if (!card) return;
    overlay.querySelectorAll('.spd-node').forEach((c) => {
      delete c.dataset.sel;
      c.style.background = 'rgba(140,140,140,0.04)';
      c.style.borderColor = 'rgba(140,140,140,0.2)';
      c.querySelector('.spd-dot').style.color = 'var(--text-dim)';
      c.querySelector('.spd-dot').textContent = '○';
    });
    card.dataset.sel = '1';
    card.style.background = 'rgba(0,229,255,0.08)';
    card.style.borderColor = 'rgba(0,229,255,0.4)';
    card.querySelector('.spd-dot').style.color = 'var(--cyan)';
    card.querySelector('.spd-dot').textContent = '●';
    quickPreflight(
      planId,
      overlay.querySelector('#spd-preflight'),
      overlay.querySelector('#spd-start'),
      card.dataset.target,
    );
  });
  overlay.querySelector('#spd-start').addEventListener('click', () => {
    const sel = overlay.querySelector('.spd-node[data-sel="1"]'),
      model = overlay.querySelector('#spd-model').value;
    overlay.remove();
    startPlanExecution(planId, planName, 'copilot', sel ? sel.dataset.target : 'local', model);
  });
  overlay.addEventListener('click', (e) => {
    if (e.target === overlay) overlay.remove();
  });
};

/**
 * Execute plan start via SSE — shows live progress.
 */
window.startPlanExecution = function (planId, planName, cli, target, model) {
  const overlay = document.createElement('div');
  overlay.className = 'modal-overlay';
  overlay.innerHTML = `<div class="modal-box" style="max-width:650px">
    <div class="modal-title">Starting #${planId} ${esc((planName || '').substring(0, 25))}<span class="modal-close" onclick="this.closest('.modal-overlay').remove()">✕</span></div>
    <pre class="modal-output" id="start-plan-output" style="max-height:450px;overflow:auto;font-size:12px;min-height:200px"></pre>
  </div>`;
  document.body.appendChild(overlay);
  overlay.addEventListener('click', (e) => {
    if (e.target === overlay) overlay.remove();
  });

  const output = document.getElementById('start-plan-output');
  const url = `/api/plan/start?plan_id=${planId}&cli=${encodeURIComponent(cli)}&target=${encodeURIComponent(target)}${model ? `&model=${encodeURIComponent(model)}` : ''}`;
  const es = new EventSource(url);

  es.addEventListener('log', (e) => {
    const line = e.data || '';
    const hasAnsi = /\x1b\[/.test(line);
    let html;
    if (hasAnsi) {
      html = ansiToHtml(line);
    } else if (line.startsWith('▶')) {
      html = `<span style="color:var(--cyan)">${esc(line)}</span>`;
    } else if (/^(OK|✓|PASS|done)/i.test(line)) {
      html = `<span style="color:var(--green)">${esc(line)}</span>`;
    } else if (/^(ERROR|FAIL|✗)/i.test(line)) {
      html = `<span style="color:var(--red)">${esc(line)}</span>`;
    } else {
      html = esc(line);
    }
    output.innerHTML += html + '\n';
    output.scrollTop = output.scrollHeight;
  });

  es.addEventListener('done', (e) => {
    es.close();
    const data = JSON.parse(e.data);
    if (data.ok) {
      output.innerHTML += `\n<span style="color:var(--green);font-weight:600">${Icons.checkCircle(14)} Plan started successfully</span>\n`;
    } else {
      const msg = data.message || `Exit code ${data.exit_code || '?'}`;
      output.innerHTML += `\n<span style="color:var(--red);font-weight:600">${Icons.xCircle(14)} ${esc(msg)}</span>\n`;
    }
    output.scrollTop = output.scrollHeight;
    if (typeof refreshAll === 'function') refreshAll();
  });

  es.onerror = () => {
    es.close();
    output.innerHTML += `\n<span style="color:var(--red)">${Icons.x(14)} Connection lost</span>\n`;
  };
};

/**
 * Full Sync action — bidirectional mesh sync via SSE.
 */
window.runFullSync = function (peer) {
  const target = peer || 'all nodes';
  const overlay = document.createElement('div');
  overlay.className = 'modal-overlay';
  overlay.innerHTML = `<div class="modal-box" style="max-width:650px">
    <div class="modal-title">Full Sync — ${esc(target)}<span class="modal-close" onclick="this.closest('.modal-overlay').remove()">✕</span></div>
    <pre class="modal-output" id="fullsync-output" style="min-height:200px;max-height:500px;overflow:auto"></pre>
  </div>`;
  document.body.appendChild(overlay);
  overlay.addEventListener('click', (e) => {
    if (e.target === overlay) overlay.remove();
  });

  const output = document.getElementById('fullsync-output');
  let url = `/api/mesh/fullsync?`;
  if (peer) url += `peer=${encodeURIComponent(peer)}&`;
  const es = new EventSource(url);

  es.addEventListener('log', (e) => {
    const line = e.data || '';
    const hasAnsi = /\x1b\[/.test(line);
    let html;
    if (hasAnsi) {
      html = ansiToHtml(line);
    } else if (line.startsWith('▶') || line.startsWith('===')) {
      html = `<span style="color:var(--cyan);font-weight:600">${esc(line)}</span>`;
    } else if (/^(OK|✓|SYNC_OK|→.*OK|local is newest)/i.test(line.trim())) {
      html = `<span style="color:var(--green)">${esc(line)}</span>`;
    } else if (/PULL from|⟵/.test(line)) {
      html = `<span style="color:var(--gold);font-weight:600">${esc(line)}</span>`;
    } else if (/^(ERROR|FAIL|✗)/i.test(line.trim())) {
      html = `<span style="color:var(--red)">${esc(line)}</span>`;
    } else {
      html = esc(line);
    }
    output.innerHTML += html + '\n';
    output.scrollTop = output.scrollHeight;
  });

  es.addEventListener('done', (e) => {
    es.close();
    const data = JSON.parse(e.data);
    if (data.ok) {
      output.innerHTML += `\n<span style="color:var(--green);font-weight:600">${Icons.checkCircle(14)} Full sync completed</span>\n`;
    } else {
      output.innerHTML += `\n<span style="color:var(--red);font-weight:600">${Icons.xCircle(14)} Sync failed</span>\n`;
    }
    output.scrollTop = output.scrollHeight;
    if (typeof refreshAll === 'function') refreshAll();
  });

  es.onerror = () => {
    es.close();
    output.innerHTML += `\n<span style="color:var(--red)">${Icons.x(14)} Connection lost</span>\n`;
  };
};

/**
 * Stop a plan — sets plan back to "todo", halts execution.
 */
window.stopPlan = async function (planId) {
  const overlay = document.createElement('div');
  overlay.className = 'modal-overlay';
  overlay.innerHTML = `<div class="modal-box" style="max-width:400px">
    <div class="modal-title">Stop Plan #${planId}<span class="modal-close" onclick="this.closest('.modal-overlay').remove()">&#x2715;</span></div>
    <div style="padding:14px">
      <p style="color:var(--text);margin-bottom:12px">Stop execution of plan #${planId}? The plan will return to "todo" status. In-progress tasks will be preserved as-is.</p>
      <div style="display:flex;gap:8px;justify-content:flex-end">
        <button class="preflight-action-btn" style="border-color:var(--text-dim);color:var(--text-dim)" onclick="this.closest('.modal-overlay').remove()">Abort</button>
        <button id="confirm-stop-btn" class="preflight-action-btn" style="border-color:var(--gold);color:var(--gold)">Confirm Stop</button>
      </div>
    </div>
  </div>`;
  document.body.appendChild(overlay);
  overlay.addEventListener('click', (e) => {
    if (e.target === overlay) overlay.remove();
  });
  document.getElementById('confirm-stop-btn').addEventListener('click', async () => {
    try {
      const res = await fetch('/api/plan-status', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ plan_id: planId, status: 'todo' }),
      });
      const data = await res.json();
      overlay.remove();
      if (data.ok) {
        if (typeof closeSidebar === 'function') closeSidebar();
        refreshAll();
      } else {
        if (typeof showOutputModal === 'function')
          showOutputModal('Stop Error', data.error || 'Failed');
      }
    } catch (err) {
      overlay.remove();
      if (typeof showOutputModal === 'function') showOutputModal('Stop Error', err.message);
    }
  });
};

/**
 * Cancel a plan — sets plan + waves + tasks to cancelled.
 */
window.cancelPlan = async function (planId) {
  const overlay = document.createElement('div');
  overlay.className = 'modal-overlay';
  overlay.innerHTML = `<div class="modal-box" style="max-width:400px">
    <div class="modal-title">Cancel Plan #${planId}<span class="modal-close" onclick="this.closest('.modal-overlay').remove()">&#x2715;</span></div>
    <div style="padding:14px">
      <p style="color:var(--text);margin-bottom:12px">This will cancel all pending/in-progress tasks and waves for plan #${planId}. Already completed tasks will be preserved.</p>
      <div style="display:flex;gap:8px;justify-content:flex-end">
        <button class="preflight-action-btn" style="border-color:var(--text-dim);color:var(--text-dim)" onclick="this.closest('.modal-overlay').remove()">Abort</button>
        <button id="confirm-cancel-btn" class="preflight-action-btn" style="border-color:var(--red);color:var(--red)">Confirm Cancel</button>
      </div>
    </div>
  </div>`;
  document.body.appendChild(overlay);
  overlay.addEventListener('click', (e) => {
    if (e.target === overlay) overlay.remove();
  });
  document.getElementById('confirm-cancel-btn').addEventListener('click', async () => {
    const res = await fetchJson(`/api/plan/cancel?plan_id=${planId}`);
    overlay.remove();
    if (res && res.ok) {
      closeSidebar();
      refreshAll();
    } else {
      showOutputModal('Cancel Error', res ? res.error : 'Failed');
    }
  });
};

/**
 * Reset a plan — resets to todo, all non-done tasks back to pending.
 */
window.resetPlan = async function (planId) {
  const overlay = document.createElement('div');
  overlay.className = 'modal-overlay';
  overlay.innerHTML = `<div class="modal-box" style="max-width:400px">
    <div class="modal-title">Reset Plan #${planId}<span class="modal-close" onclick="this.closest('.modal-overlay').remove()">&#x2715;</span></div>
    <div style="padding:14px">
      <p style="color:var(--text);margin-bottom:12px">This will reset plan #${planId} back to "todo". All non-completed tasks will be set to pending. Agent assignments and token counts will be cleared.</p>
      <div style="display:flex;gap:8px;justify-content:flex-end">
        <button class="preflight-action-btn" style="border-color:var(--text-dim);color:var(--text-dim)" onclick="this.closest('.modal-overlay').remove()">Abort</button>
        <button id="confirm-reset-btn" class="preflight-action-btn" style="border-color:var(--gold);color:var(--gold)">Confirm Reset</button>
      </div>
    </div>
  </div>`;
  document.body.appendChild(overlay);
  overlay.addEventListener('click', (e) => {
    if (e.target === overlay) overlay.remove();
  });
  document.getElementById('confirm-reset-btn').addEventListener('click', async () => {
    const res = await fetchJson(`/api/plan/reset?plan_id=${planId}`);
    overlay.remove();
    if (res && res.ok) {
      closeSidebar();
      refreshAll();
    } else {
      showOutputModal('Reset Error', res ? res.error : 'Failed');
    }
  });
};
