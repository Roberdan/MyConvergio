// optimize.js — Session Learning Signals panel
// Shows accumulated signals from session-learning-collector.sh
// Version: 1.0.0

const SIGNAL_ICONS = {
  stale_tasks: '<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="var(--gold)" stroke-width="2"><circle cx="12" cy="12" r="10"/><path d="M12 6v6l4 2"/></svg>',
  stale_checkpoint: '<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="var(--magenta)" stroke-width="2"><path d="M19 21H5a2 2 0 01-2-2V5a2 2 0 012-2h11l5 5v11a2 2 0 01-2 2z"/><polyline points="17 21 17 13 7 13 7 21"/></svg>',
  repeated_failures: '<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="var(--red)" stroke-width="2"><circle cx="12" cy="12" r="10"/><line x1="15" y1="9" x2="9" y2="15"/><line x1="9" y1="9" x2="15" y2="15"/></svg>',
  version_mismatch: '<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="var(--gold)" stroke-width="2"><path d="M10.29 3.86L1.82 18a2 2 0 001.71 3h16.94a2 2 0 001.71-3L13.71 3.86a2 2 0 00-3.42 0z"/><line x1="12" y1="9" x2="12" y2="13"/><line x1="12" y1="17" x2="12.01" y2="17"/></svg>',
  stale_worktrees: '<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="var(--cyan)" stroke-width="2"><line x1="6" y1="3" x2="6" y2="15"/><circle cx="18" cy="6" r="3"/><circle cx="6" cy="18" r="3"/><path d="M18 9a9 9 0 01-9 9"/></svg>',
};

const SIGNAL_LABELS = {
  stale_tasks: 'Stale Tasks',
  stale_checkpoint: 'Stale Checkpoint',
  repeated_failures: 'Repeated Failures',
  version_mismatch: 'Version Mismatch',
  stale_worktrees: 'Orphan Worktrees',
};

let optimizeData = null;

async function fetchOptimizeSignals() {
  try {
    const res = await fetch('/api/optimize/signals');
    optimizeData = await res.json();
    updateOptimizeBadge();
    return optimizeData;
  } catch {
    optimizeData = { count: 0, signals: [], by_type: [] };
    updateOptimizeBadge();
    return optimizeData;
  }
}

function updateOptimizeBadge() {
  const badge = document.getElementById('optimize-badge');
  if (!badge) return;
  const count = optimizeData?.count || 0;
  if (count > 0) {
    badge.textContent = count;
    badge.style.display = 'flex';
  } else {
    badge.style.display = 'none';
  }
}

function renderSignalCard(sig) {
  const icon = SIGNAL_ICONS[sig.type] || '';
  const label = SIGNAL_LABELS[sig.type] || sig.type;
  const samples = Array.isArray(sig.samples)
    ? sig.samples.map(s => `<code>${JSON.stringify(s, null, 0).slice(0, 120)}</code>`).join('')
    : '';
  return `<div class="opt-signal-card">
    <div class="opt-signal-header">
      ${icon}
      <span class="opt-signal-label">${label}</span>
      <span class="opt-signal-count">${sig.count}</span>
    </div>
    ${samples ? `<div class="opt-signal-samples">${samples}</div>` : ''}
  </div>`;
}

function openOptimizeModal() {
  let overlay = document.getElementById('optimize-overlay');
  if (overlay) { overlay.remove(); }

  overlay = document.createElement('div');
  overlay.id = 'optimize-overlay';
  overlay.className = 'modal-overlay';
  overlay.onclick = e => { if (e.target === overlay) overlay.remove(); };

  const data = optimizeData || { count: 0, signals: [], by_type: [] };
  const isEmpty = data.count === 0;
  const projects = (data.projects || []).join(', ') || 'none';

  const signalCards = isEmpty
    ? '<div class="opt-empty">No signals collected. System is clean.</div>'
    : data.by_type.map(renderSignalCard).join('');

  const timeRange = !isEmpty && data.signals?.length
    ? `${data.signals[0]?.timestamp?.slice(0, 16) || '?'} — ${data.signals[data.signals.length - 1]?.timestamp?.slice(0, 16) || '?'}`
    : '';

  overlay.innerHTML = `
    <div class="modal-box opt-modal">
      <div class="modal-title">
        <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="var(--cyan)" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.65 1.65 0 00.33 1.82l.06.06a2 2 0 010 2.83 2 2 0 01-2.83 0l-.06-.06a1.65 1.65 0 00-1.82-.33 1.65 1.65 0 00-1 1.51V21a2 2 0 01-2 2 2 2 0 01-2-2v-.09A1.65 1.65 0 009 19.4a1.65 1.65 0 00-1.82.33l-.06.06a2 2 0 01-2.83 0 2 2 0 010-2.83l.06-.06A1.65 1.65 0 004.68 15a1.65 1.65 0 00-1.51-1H3a2 2 0 01-2-2 2 2 0 012-2h.09A1.65 1.65 0 004.6 9a1.65 1.65 0 00-.33-1.82l-.06-.06a2 2 0 010-2.83 2 2 0 012.83 0l.06.06A1.65 1.65 0 009 4.68a1.65 1.65 0 001-1.51V3a2 2 0 012-2 2 2 0 012 2v.09a1.65 1.65 0 001 1.51 1.65 1.65 0 001.82-.33l.06-.06a2 2 0 012.83 0 2 2 0 010 2.83l-.06.06a1.65 1.65 0 00-.33 1.82V9a1.65 1.65 0 001.51 1H21a2 2 0 012 2 2 2 0 01-2 2h-.09a1.65 1.65 0 00-1.51 1z"/></svg>
        OPTIMIZE .CLAUDE
        <button class="modal-close" onclick="document.getElementById('optimize-overlay').remove()">&times;</button>
      </div>
      <div class="opt-meta">
        <span>Sessions: <b>${data.count}</b></span>
        <span>Projects: <b>${projects}</b></span>
        ${timeRange ? `<span class="opt-timerange">${timeRange}</span>` : ''}
      </div>
      <div class="opt-signals">${signalCards}</div>
      <div class="opt-actions">
        ${!isEmpty ? `<button class="opt-btn opt-btn-clear" onclick="clearOptimizeSignals()">Archive & Clear</button>` : ''}
        <button class="opt-btn opt-btn-refresh" onclick="refreshOptimize()">Refresh</button>
      </div>
    </div>`;
  document.body.appendChild(overlay);
}

async function clearOptimizeSignals() {
  try {
    await fetch('/api/optimize/clear', { method: 'POST' });
    await fetchOptimizeSignals();
    openOptimizeModal();
  } catch (e) {
    console.error('Clear failed:', e);
  }
}

async function refreshOptimize() {
  await fetchOptimizeSignals();
  openOptimizeModal();
}

// Auto-fetch on load
document.addEventListener('DOMContentLoaded', () => fetchOptimizeSignals());
