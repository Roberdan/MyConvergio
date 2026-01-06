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

  DropdownManager.closeAll('waveMenuList');
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
          <button class="wave-menu-gantt-btn" onclick="event.stopPropagation(); showView('waves'); setTimeout(() => showGanttLevel('tasks', '${wave.wave_id}'), 100);" title="View Gantt chart">📊</button>
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
        <button class="wave-menu-view-btn" onclick="event.stopPropagation(); drillIntoTaskFromMenu('${waveId}', '${task.task_id}'); closeWaveMenu();" title="View task details">🔍</button>
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

// Navigate to waves view
function navigateToWavesView() {
  showView('waves');
}

// Drill into task detail from wave menu
// Note: This uses functions from drilldown.js (drillIntoWave, drillIntoTask)
async function drillIntoTaskFromMenu(waveId, taskId) {
  // Ensure we're on dashboard view for drilldown panel
  showView('dashboard');

  // If data doesn't have the wave/task, fetch it first
  const waveExists = data?.waves?.find(w => w.id === waveId || w.wave_id === waveId);
  if (!waveExists) {
    try {
      const res = await fetch(`${API_BASE}/project/${currentProjectId}/dashboard`);
      const projectData = await res.json();
      if (projectData.waves) {
        data.waves = projectData.waves.map(w => ({
          id: w.wave_id,
          wave_id: w.wave_id,
          name: w.name,
          status: w.status,
          done: w.tasks_done || 0,
          total: w.tasks_total || 0,
          tasks: (w.tasks || []).map(t => ({
            id: t.task_id,
            task_id: t.task_id,
            title: t.title,
            status: t.status,
            assignee: t.assignee,
            priority: t.priority,
            type: t.type,
            tokens: t.tokens,
            notes: t.notes,
            started_at: t.started_at,
            completed_at: t.completed_at,
            duration_minutes: t.duration_minutes,
            validated_by: t.validated_by,
            validated_at: t.validated_at,
            files: t.files ? t.files.split(',') : []
          }))
        }));
      }
    } catch (e) {
      console.error('Failed to load project data for task drilldown:', e);
      if (typeof showToast === 'function') {
        showToast('Failed to load task details', 'error');
      }
      return;
    }
  }

  // Drill into task using drilldown.js functions
  // drillIntoTask expects wave.id format (e.g., "W1" not "1-W1")
  if (typeof drillIntoTask === 'function') {
    // First drill into the wave to set up the context
    if (typeof drillIntoWave === 'function') {
      drillIntoWave(waveId);
    }
    // Then drill into the specific task after a short delay
    setTimeout(() => {
      drillIntoTask(waveId, taskId);
    }, 50);
  }
}
