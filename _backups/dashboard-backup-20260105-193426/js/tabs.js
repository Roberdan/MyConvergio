// Tab Switching, History, and Debt

function showTab(tabName) {
  ['issues', 'tokens', 'history'].forEach(t => {
    const tabId = 'tab' + t.charAt(0).toUpperCase() + t.slice(1);
    const tab = document.getElementById(tabId);
    const btn = document.querySelector(`.about-tab[onclick="showTab('${t}')"]`);
    if (tab) tab.style.display = t === tabName ? 'block' : 'none';
    if (btn) btn.classList.toggle('active', t === tabName);
  });

  if (tabName === 'issues') {
    renderIssuesPanel();
  }
  if (tabName === 'tokens') {
    renderTokensTab();
  }
  if (tabName === 'history') {
    renderHistory();
  }
}

function renderDebt() {
  if (!data.debt) return;

  // All debt elements may not exist in all views
  const debtTotalEl = document.getElementById('debtTotal');
  const debtTodoEl = document.getElementById('debtTodo');
  const debtFixmeEl = document.getElementById('debtFixme');
  const debtHackEl = document.getElementById('debtHack');
  const debtUpdatedEl = document.getElementById('debtUpdated');

  if (debtTotalEl) debtTotalEl.textContent = data.debt.total || 0;
  if (debtTodoEl) debtTodoEl.textContent = data.debt.byType?.todo?.length || 0;
  if (debtFixmeEl) debtFixmeEl.textContent = data.debt.byType?.fixme?.length || 0;
  if (debtHackEl) debtHackEl.textContent = data.debt.byType?.hack?.length || 0;

  if (debtUpdatedEl && data.debt.lastScan) {
    debtUpdatedEl.textContent = 'Last scan: ' + new Date(data.debt.lastScan).toLocaleString();
  }
}

function renderHistory() {
  const history = data.history || [];

  const versions = history.length;
  const edits = history.filter(h => h.change_type === 'user_edit').length;
  const blockers = history.filter(h => h.change_type === 'blocker').length;

  const historyVersionsEl = document.getElementById('historyVersions');
  const historyEditsEl = document.getElementById('historyEdits');
  const historyBlockersEl = document.getElementById('historyBlockers');

  if (historyVersionsEl) historyVersionsEl.textContent = versions || 0;
  if (historyEditsEl) historyEditsEl.textContent = edits || 0;
  if (historyBlockersEl) historyBlockersEl.textContent = blockers || 0;

  const timeline = document.getElementById('historyTimeline');
  if (!timeline) return;

  if (history.length === 0) {
    timeline.innerHTML = '<div class="history-empty">No version history yet</div>';
    return;
  }

  timeline.innerHTML = history.map(h => {
    const typeLabel = {
      'created': 'Created',
      'user_edit': 'User Edit',
      'scope_add': 'Scope Added',
      'scope_remove': 'Scope Removed',
      'blocker': 'Blocker',
      'replan': 'Replanned',
      'task_split': 'Task Split',
      'completed': 'Completed'
    }[h.change_type] || h.change_type;

    const time = h.created_at ? new Date(h.created_at).toLocaleString() : '';

    return `
      <div class="history-item">
        <div class="history-item-dot ${h.change_type}"></div>
        <div class="history-item-content">
          <div class="history-item-type">v${h.version} - ${typeLabel}</div>
          ${h.change_reason ? `<div class="history-item-reason">${h.change_reason}</div>` : ''}
          <div class="history-item-time">${time}</div>
        </div>
      </div>
    `;
  }).join('');
}
