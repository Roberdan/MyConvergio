// Views - Execution Tree
// Renders a visual execution tree for a plan showing status, cancel/skip reasons

async function loadExecutionTree(planId) {
  try {
    const res = await fetch(`${API_BASE}/plan/${planId}/execution-tree`);
    const tree = await res.json();
    if (tree.error) {
      console.error('Execution tree error:', tree.error);
      return null;
    }
    return tree;
  } catch (e) {
    console.error('Failed to load execution tree:', e);
    return null;
  }
}

function statusIcon(status) {
  const icons = {
    done: '✓', cancelled: '✗', skipped: '⊘', in_progress: '▶',
    blocked: '⊘', pending: '○', merging: '⇄', doing: '▶', todo: '○'
  };
  return icons[status] || '?';
}

function statusClass(status) {
  const classes = {
    done: 'status-done', cancelled: 'status-cancelled', skipped: 'status-skipped',
    in_progress: 'status-progress', blocked: 'status-blocked', pending: 'status-pending',
    merging: 'status-merging', doing: 'status-progress', todo: 'status-pending'
  };
  return classes[status] || '';
}

function renderExecutionTreeHTML(tree) {
  if (!tree || !tree.plan) return '<div class="exec-tree-empty">No execution tree data</div>';

  const { plan, waves } = tree;
  let html = `<div class="exec-tree">`;
  html += `<div class="exec-tree-plan ${statusClass(plan.status)}">`;
  html += `<span class="exec-tree-icon">${statusIcon(plan.status)}</span>`;
  html += `<strong>Plan #${plan.id}</strong>: ${escapeHtml(plan.name)} <span class="exec-tree-status">[${plan.status}]</span>`;
  if (plan.status === 'cancelled' && plan.cancelled_reason) {
    html += `<div class="exec-tree-reason">${escapeHtml(plan.cancelled_reason)}</div>`;
  }
  html += `</div>`;

  (waves || []).forEach((wave, wi) => {
    html += `<div class="exec-tree-wave ${statusClass(wave.status)}">`;
    html += `<span class="exec-tree-connector">├─</span>`;
    html += `<span class="exec-tree-icon">${statusIcon(wave.status)}</span>`;
    html += `<strong>${escapeHtml(wave.wave_id)}</strong>: ${escapeHtml(wave.name)}`;
    html += ` <span class="exec-tree-status">[${wave.status}]</span>`;
    html += ` <span class="exec-tree-progress">(${wave.tasks_done}/${wave.tasks_total})</span>`;
    if (wave.status === 'cancelled' && wave.cancelled_reason) {
      html += `<div class="exec-tree-reason">${escapeHtml(wave.cancelled_reason)}</div>`;
    }

    const tasks = wave.tasks || [];
    tasks.forEach((task, ti) => {
      const isLast = ti === tasks.length - 1;
      const connector = isLast ? '└─' : '├─';
      html += `<div class="exec-tree-task ${statusClass(task.status)}">`;
      html += `<span class="exec-tree-connector">│ ${connector}</span>`;
      html += `<span class="exec-tree-icon">${statusIcon(task.status)}</span>`;
      html += `${escapeHtml(task.task_id)}: ${escapeHtml(task.title)}`;
      html += ` <span class="exec-tree-status">[${task.status}]</span>`;
      if (task.status === 'cancelled' && task.cancelled_reason) {
        html += `<div class="exec-tree-reason">${escapeHtml(task.cancelled_reason)}</div>`;
      } else if (task.status === 'skipped' && task.notes) {
        html += `<div class="exec-tree-reason skip">${escapeHtml(task.notes)}</div>`;
      }
      html += `</div>`;
    });

    html += `</div>`;
  });

  html += `</div>`;
  return html;
}

function escapeHtml(str) {
  if (!str) return '';
  return str.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
}
