// Wave Tree Navigation Menu

let waveMenuExpanded = new Set();
let waveTaskMenuExpanded = new Set();

async function showWaveMenu() {
  if (!currentProjectId) return;

  const waveList = document.getElementById('waveMenuList');
  if (!waveList) return;

  if (waveList.style.display === 'block') {
    waveList.style.display = 'none';
    return;
  }

  waveList.innerHTML = '<div class="wave-loading">Loading waves...</div>';
  waveList.style.display = 'block';

  try {
    const res = await fetch(`${API_BASE}/project/${currentProjectId}/dashboard`);
    const result = await res.json();

    if (!result.waves || result.waves.length === 0) {
      waveList.innerHTML = '<div class="wave-empty">No waves in this project</div>';
      return;
    }

    waveList.innerHTML = `
      <div class="wave-menu-header">
        Waves (${result.waves.length})
        <div class="wave-menu-actions">
          <button class="wave-menu-action-btn" onclick="event.stopPropagation(); expandAllWavesMenu()" title="Expand all">⊕</button>
          <button class="wave-menu-action-btn" onclick="event.stopPropagation(); collapseAllWavesMenu()" title="Collapse all">⊖</button>
        </div>
      </div>
      <div class="wave-menu-tree">
        ${result.waves.map(wave => renderWaveMenuItem(wave)).join('')}
      </div>
    `;
  } catch (e) {
    waveList.innerHTML = `<div class="wave-empty">Error: ${e.message}</div>`;
  }
}

function renderWaveMenuItem(wave) {
  const isExpanded = waveMenuExpanded.has(wave.wave_id);
  const progress = wave.tasks_total > 0 ? Math.round((wave.tasks_done / wave.tasks_total) * 100) : 0;
  const hasActiveTasks = wave.tasks?.some(t => t.status === 'in_progress');

  let html = `
    <div class="wave-menu-item ${isExpanded ? 'expanded' : ''}" data-wave-id="${wave.wave_id}">
      <div class="wave-menu-header-row" onclick="event.stopPropagation(); toggleWaveMenuNode('${wave.wave_id}')">
        <span class="wave-menu-expand">${isExpanded ? '▼' : '▶'}</span>
        <span class="wave-menu-status ${wave.status}" title="${wave.status}">
          ${wave.status === 'in_progress' ? '●' : wave.status === 'done' ? '✓' : '○'}
        </span>
        <span class="wave-menu-name">
          <strong>${wave.wave_id}</strong>
          <span class="wave-menu-title">${wave.name}</span>
        </span>
        ${hasActiveTasks ? '<span class="wave-menu-live" title="Tasks running">●</span>' : ''}
        <span class="wave-menu-progress">${wave.tasks_done}/${wave.tasks_total}</span>
        <button class="wave-menu-view-btn" onclick="event.stopPropagation(); showWaveMarkdown('${wave.wave_id}'); closeWaveMenu();" title="View documentation">📄</button>
        <button class="wave-menu-gantt-btn" onclick="event.stopPropagation(); drillIntoWave('${wave.wave_id}'); closeWaveMenu();" title="View Gantt chart">📊</button>
      </div>

      ${isExpanded && wave.tasks?.length > 0 ? `
        <div class="wave-menu-tasks">
          ${wave.tasks.map(task => renderWaveTaskMenuItem(wave.wave_id, task)).join('')}
        </div>
      ` : ''}
    </div>
  `;

  return html;
}

function renderWaveTaskMenuItem(waveId, task) {
  const isExpanded = waveTaskMenuExpanded.has(task.task_id);
  const isLive = task.executor_status === 'running';

  return `
    <div class="wave-menu-task ${isExpanded ? 'expanded' : ''}" data-task-id="${task.task_id}">
      <div class="wave-menu-task-header" onclick="event.stopPropagation(); toggleWaveTaskMenuNode('${task.task_id}')">
        <span class="wave-menu-expand">${isExpanded ? '▼' : '▶'}</span>
        <span class="wave-menu-status ${task.status}" title="${task.status}">
          ${task.status === 'in_progress' ? '●' : task.status === 'done' ? '✓' : task.status === 'blocked' ? '✖' : '○'}
        </span>
        <span class="wave-menu-task-name">
          <strong>${task.task_id}</strong>
          <span class="wave-menu-task-title">${task.title}</span>
        </span>
        ${isLive ? '<span class="wave-menu-live pulsing" title="Executing">●</span>' : ''}
        ${task.priority ? `<span class="wave-menu-priority ${task.priority}">${task.priority}</span>` : ''}
      </div>

      ${isExpanded && (task.description || task.assignee || task.tokens) ? `
        <div class="wave-menu-task-details">
          ${task.description ? `<div class="task-detail"><span class="detail-label">Task:</span> ${escapeHtml(task.description)}</div>` : ''}
          ${task.assignee ? `<div class="task-detail"><span class="detail-label">Assigned to:</span> ${task.assignee}</div>` : ''}
          ${task.tokens ? `<div class="task-detail"><span class="detail-label">Tokens:</span> ${task.tokens.toLocaleString()}</div>` : ''}
        </div>
      ` : ''}
    </div>
  `;
}

function toggleWaveMenuNode(waveId) {
  if (waveMenuExpanded.has(waveId)) {
    waveMenuExpanded.delete(waveId);
  } else {
    waveMenuExpanded.add(waveId);
  }
  showWaveMenu();
}

function toggleWaveTaskMenuNode(taskId) {
  if (waveTaskMenuExpanded.has(taskId)) {
    waveTaskMenuExpanded.delete(taskId);
  } else {
    waveTaskMenuExpanded.add(taskId);
  }
  showWaveMenu();
}

function expandAllWavesMenu() {
  const res = fetch(`${API_BASE}/project/${currentProjectId}/dashboard`)
    .then(r => r.json())
    .then(result => {
      if (result.waves) {
        result.waves.forEach(w => waveMenuExpanded.add(w.wave_id));
        showWaveMenu();
      }
    });
}

function collapseAllWavesMenu() {
  waveMenuExpanded.clear();
  waveTaskMenuExpanded.clear();
  showWaveMenu();
}

function closeWaveMenu() {
  const waveList = document.getElementById('waveMenuList');
  if (waveList) waveList.style.display = 'none';
}

function drillIntoWave(waveId) {
  showView('waves');
  // Optional: Could scroll to specific wave in Gantt view
}
