// Enhanced Gantt Navigation System
// Provides hierarchical navigation: Waves -> Tasks -> Details -> Files

let ganttViewMode = 'timeline';
let ganttNavigationState = {
  level: 'waves',  // 'waves', 'tasks', 'details', 'files'
  waveId: null,
  taskId: null,
  data: null
};

// Load complete project data for Gantt navigation
async function loadGanttData() {
  if (!currentProjectId) {
    showGanttError('No project selected');
    return;
  }

  const content = document.getElementById('ganttContent');
  if (!content) return;

  content.innerHTML = '<div class="gantt-loading">Loading project data...</div>';

  try {
    // Load project dashboard data
    const dashboardRes = await fetch(`${API_BASE}/project/${currentProjectId}/dashboard`);
    const dashboardData = await dashboardRes.json();

    // Load detailed plan data for each plan
    const plansPromises = dashboardData.plans.map(async (plan) => {
      try {
        const planRes = await fetch(`${API_BASE}/plan/${plan.id}`);
        return await planRes.json();
      } catch (e) {
        console.warn(`Failed to load plan ${plan.id}:`, e);
        return null;
      }
    });

    const plansData = await Promise.all(plansPromises);
    const validPlans = plansData.filter(p => p);

    ganttNavigationState.data = {
      project: dashboardData,
      plans: validPlans
    };

    showGanttLevel('waves');
  } catch (e) {
    showGanttError(`Failed to load project data: ${e.message}`);
  }
}

// Show different levels of the Gantt hierarchy
function showGanttLevel(level, waveId = null, taskId = null) {
  ganttNavigationState.level = level;
  ganttNavigationState.waveId = waveId;
  ganttNavigationState.taskId = taskId;

  updateGanttNavigation();

  switch (level) {
    case 'waves':
      renderWavesLevel();
      break;
    case 'tasks':
      renderTasksLevel(waveId);
      break;
    case 'details':
      renderTaskDetailsLevel(waveId, taskId);
      break;
    case 'files':
      renderFilesLevel(waveId, taskId);
      break;
  }
}

// Update navigation breadcrumb
function updateGanttNavigation() {
  const navWave = document.getElementById('ganttNavWave');
  const navTask = document.getElementById('ganttNavTask');
  const separator1 = document.getElementById('ganttNavSeparator');
  const separator2 = document.getElementById('ganttNavTaskSeparator');

  // Reset all nav items
  document.querySelectorAll('.gantt-nav-item').forEach(item => {
    item.classList.remove('active');
  });

  // Show/hide based on level
  switch (ganttNavigationState.level) {
    case 'waves':
      document.querySelector('[onclick*="showGanttLevel(\'waves\'"]').classList.add('active');
      navWave.style.display = 'none';
      navTask.style.display = 'none';
      separator1.style.display = 'none';
      separator2.style.display = 'none';
      break;

    case 'tasks':
      document.querySelector('[onclick*="showGanttLevel(\'waves\'"]').classList.add('active');
      navWave.style.display = 'inline-flex';
      navTask.style.display = 'none';
      separator1.style.display = 'inline';
      separator2.style.display = 'none';

      if (ganttNavigationState.waveId) {
        const wave = findWaveById(ganttNavigationState.waveId);
        if (wave) {
          document.getElementById('ganttNavWaveName').textContent = wave.wave_id;
        }
      }
      break;

    case 'details':
    case 'files':
      document.querySelector('[onclick*="showGanttLevel(\'waves\'"]').classList.add('active');
      navWave.style.display = 'inline-flex';
      navTask.style.display = 'inline-flex';
      separator1.style.display = 'inline';
      separator2.style.display = 'inline';

      if (ganttNavigationState.taskId) {
        document.getElementById('ganttNavTaskName').textContent = ganttNavigationState.taskId;
      }
      break;
  }
}

// Render waves level (top level of hierarchy)
function renderWavesLevel() {
  const content = document.getElementById('ganttContent');
  if (!content || !ganttNavigationState.data) return;

  const { project, plans } = ganttNavigationState.data;

  if (!plans || plans.length === 0) {
    content.innerHTML = '<div class="gantt-empty">No plans found in this project</div>';
    return;
  }

  // Render Gantt chart for all waves across all plans
  const allWaves = [];
  plans.forEach(plan => {
    if (plan.waves) {
      plan.waves.forEach(wave => {
        allWaves.push({
          ...wave,
          planName: plan.name,
          planId: plan.id
        });
      });
    }
  });

  renderWavesGanttInContainer(allWaves, content);
}

// Render tasks level for a specific wave
function renderTasksLevel(waveId) {
  const content = document.getElementById('ganttContent');
  if (!content || !ganttNavigationState.data) return;

  const wave = findWaveById(waveId);
  if (!wave) {
    content.innerHTML = '<div class="gantt-empty">Wave not found</div>';
    return;
  }

  const tasks = wave.tasks || [];

  if (tasks.length === 0) {
    content.innerHTML = '<div class="gantt-empty">No tasks in this wave</div>';
    return;
  }

  // Render tasks in a list or kanban view
  const html = `
    <div class="tasks-view">
      <div class="tasks-header">
        <h3>Tasks in ${wave.wave_id} - ${wave.name}</h3>
        <div class="tasks-stats">
          <span class="task-stat">Total: ${tasks.length}</span>
          <span class="task-stat">Done: ${tasks.filter(t => t.status === 'done').length}</span>
          <span class="task-stat">In Progress: ${tasks.filter(t => t.status === 'in_progress').length}</span>
        </div>
      </div>
      <div class="tasks-grid">
        ${tasks.map(task => renderTaskCard(task, waveId)).join('')}
      </div>
    </div>
  `;

  content.innerHTML = html;
}

// Render task card
function renderTaskCard(task, waveId) {
  const statusIcon = getTaskStatusIcon(task.status);
  const priorityClass = getTaskPriorityClass(task.priority);

  return `
    <div class="task-card ${task.status}" onclick="showGanttLevel('details', '${waveId}', '${task.task_id}')">
      <div class="task-header">
        <span class="task-id">${task.task_id}</span>
        <span class="task-status-icon">${statusIcon}</span>
      </div>
      <div class="task-title">${task.title}</div>
      <div class="task-meta">
        <span class="task-priority ${priorityClass}">${task.priority || 'P3'}</span>
        <span class="task-assignee">${task.assignee || 'Unassigned'}</span>
      </div>
    </div>
  `;
}

// Render task details level
function renderTaskDetailsLevel(waveId, taskId) {
  const content = document.getElementById('ganttContent');
  if (!content || !ganttNavigationState.data) return;

  const task = findTaskById(waveId, taskId);
  if (!task) {
    content.innerHTML = '<div class="gantt-empty">Task not found</div>';
    return;
  }

  const html = `
    <div class="task-details-view">
      <div class="task-details-header">
        <h3>${task.task_id} - ${task.title}</h3>
        <div class="task-details-meta">
          <span class="task-detail-item">Status: ${task.status}</span>
          <span class="task-detail-item">Priority: ${task.priority || 'P3'}</span>
          <span class="task-detail-item">Assignee: ${task.assignee || 'Unassigned'}</span>
          <span class="task-detail-item">Tokens: ${task.tokens || 0}</span>
        </div>
      </div>

      <div class="task-details-content">
        <div class="task-details-section">
          <h4>Timing</h4>
          <div class="task-timing">
            <div class="timing-item">
              <span class="timing-label">Started:</span>
              <span class="timing-value">${task.started_at ? new Date(task.started_at).toLocaleString() : 'Not started'}</span>
            </div>
            <div class="timing-item">
              <span class="timing-label">Completed:</span>
              <span class="timing-value">${task.completed_at ? new Date(task.completed_at).toLocaleString() : 'Not completed'}</span>
            </div>
            <div class="timing-item">
              <span class="timing-label">Duration:</span>
              <span class="timing-value">${task.duration_minutes ? `${task.duration_minutes} min` : 'N/A'}</span>
            </div>
          </div>
        </div>

        <div class="task-details-section">
          <h4>Files Modified</h4>
          <div class="task-files">
            <button class="gantt-action-btn" onclick="showGanttLevel('files', '${waveId}', '${taskId}')">
              View Modified Files (${task.files ? task.files.length : 0})
            </button>
          </div>
        </div>
      </div>
    </div>
  `;

  content.innerHTML = html;
}

// Render files level for a task
function renderFilesLevel(waveId, taskId) {
  const content = document.getElementById('ganttContent');
  if (!content || !ganttNavigationState.data) return;

  const task = findTaskById(waveId, taskId);
  if (!task) {
    content.innerHTML = '<div class="gantt-empty">Task not found</div>';
    return;
  }

  const files = task.files || [];

  const html = `
    <div class="files-view">
      <div class="files-header">
        <h3>Files Modified in ${taskId}</h3>
        <span class="files-count">${files.length} files</span>
      </div>

      ${files.length === 0 ?
        '<div class="files-empty">No files recorded for this task</div>' :
        `<div class="files-list">
          ${files.map(file => `
            <div class="file-item" onclick="openFile('${file}')">
              <span class="file-icon">${getFileIcon(file)}</span>
              <span class="file-path">${file}</span>
              <button class="file-action-btn" onclick="event.stopPropagation(); viewFileDiff('${file}')">View Changes</button>
            </div>
          `).join('')}
        </div>`
      }
    </div>
  `;

  content.innerHTML = html;
}

// Utility functions
function findWaveById(waveId) {
  if (!ganttNavigationState.data) return null;
  const { plans } = ganttNavigationState.data;

  for (const plan of plans) {
    if (plan.waves) {
      const wave = plan.waves.find(w => w.wave_id === waveId);
      if (wave) return wave;
    }
  }
  return null;
}

function findTaskById(waveId, taskId) {
  const wave = findWaveById(waveId);
  if (!wave || !wave.tasks) return null;

  return wave.tasks.find(t => t.task_id === taskId);
}

function getTaskStatusIcon(status) {
  switch (status) {
    case 'done': return '✓';
    case 'in_progress': return '●';
    case 'blocked': return '✖';
    default: return '○';
  }
}

function getTaskPriorityClass(priority) {
  switch (priority) {
    case 'P0': return 'critical';
    case 'P1': return 'high';
    case 'P2': return 'medium';
    default: return 'low';
  }
}

function getFileIcon(filename) {
  if (filename.endsWith('.js') || filename.endsWith('.ts')) return '🟨';
  if (filename.endsWith('.css') || filename.endsWith('.scss')) return '🟦';
  if (filename.endsWith('.html')) return '🟠';
  if (filename.endsWith('.json')) return '🟣';
  if (filename.endsWith('.md')) return '📝';
  return '📄';
}

function showGanttError(message) {
  const content = document.getElementById('ganttContent');
  if (content) {
    content.innerHTML = `<div class="gantt-error">${message}</div>`;
  }
}

// Set Gantt view mode (timeline, kanban, list)
function setGanttViewMode(mode) {
  ganttViewMode = mode;

  // Update UI
  document.querySelectorAll('.gantt-mode-btn').forEach(btn => {
    btn.classList.remove('active');
  });
  document.querySelector(`[onclick*="setGanttViewMode('${mode}'"]`).classList.add('active');

  // Re-render current level
  showGanttLevel(ganttNavigationState.level, ganttNavigationState.waveId, ganttNavigationState.taskId);
}

// Expand/collapse functions
function expandAllGantt() {
  // Implementation for expanding all items
  console.log('Expand all Gantt items');
}

function collapseAllGantt() {
  // Implementation for collapsing all items
  console.log('Collapse all Gantt items');
}

function exportGantt() {
  // Implementation for exporting Gantt data
  console.log('Export Gantt data');
}

// File operations
function openFile(filePath) {
  // Implementation for opening file
  console.log('Open file:', filePath);
  // TODO: Implement file opening in editor
}

function viewFileDiff(filePath) {
  // Implementation for viewing file diff
  console.log('View diff for:', filePath);
  // TODO: Implement diff viewer
}

// Export functions to global scope
window.loadGanttData = loadGanttData;
window.showGanttLevel = showGanttLevel;
window.setGanttViewMode = setGanttViewMode;
window.expandAllGantt = expandAllGantt;
window.collapseAllGantt = collapseAllGantt;
window.exportGantt = exportGantt;
window.openFile = openFile;
window.viewFileDiff = viewFileDiff;

// Simple Gantt view that works immediately
async function loadWavesView() {
  console.log('Loading simple Gantt view...');

  const content = document.getElementById('ganttContent');
  if (!content) return;

  content.innerHTML = '<div class="gantt-loading">Loading Gantt chart...</div>';

  try {
    // Load project data
    const response = await fetch('/api/project/convergioedu/dashboard');
    const data = await response.json();

    console.log('Gantt data:', data);

    // Create simple Gantt HTML
    const html = `
      <div class="simple-gantt">
        <div class="gantt-header">
          <h3>Project Waves - ${data.meta.project}</h3>
          <div class="gantt-stats">
            <span>Total Tasks: ${data.metrics.throughput.total}</span>
            <span>Completed: ${data.metrics.throughput.done}</span>
            <span>Progress: ${data.metrics.throughput.percent}%</span>
          </div>
        </div>

        <div class="waves-list">
          ${data.waves.map(wave => `
            <div class="wave-item" onclick="alert('Wave: ${wave.name}\\nStatus: ${wave.status}\\nTasks: ${wave.done}/${wave.total}')">
              <div class="wave-info">
                <div class="wave-name">${wave.id} - ${wave.name}</div>
                <div class="wave-status ${wave.status}">${wave.status}</div>
              </div>
              <div class="wave-progress">
                <div class="progress-bar">
                  <div class="progress-fill" style="width: ${wave.total > 0 ? (wave.done / wave.total * 100) : 0}%"></div>
                </div>
                <span class="progress-text">${wave.done}/${wave.total}</span>
              </div>
            </div>
          `).join('')}
        </div>

        <div class="gantt-actions">
          <button onclick="alert('Gantt navigation not fully implemented yet.\\nClick on waves above to see details.')" class="gantt-btn">🔍 Drill Down</button>
          <button onclick="alert('Export functionality coming soon!')" class="gantt-btn">💾 Export</button>
        </div>
      </div>
    `;

    content.innerHTML = html;
    console.log('Simple Gantt rendered successfully');

  } catch (error) {
    console.error('Gantt error:', error);
    content.innerHTML = `<div class="gantt-error">Error: ${error.message}</div>`;
  }
}

function renderWavesGanttInContainer(waves, container) {
  if (!waves || waves.length === 0) {
    container.innerHTML = '<div class="waves-empty">No waves available</div>';
    return;
  }

  const now = new Date();
  let minDate = null;
  let maxDate = null;

  waves.forEach(wave => {
    const start = wave.planned_start ? new Date(wave.planned_start) : null;
    const end = wave.planned_end ? new Date(wave.planned_end) : null;
    if (start && (!minDate || start < minDate)) minDate = start;
    if (end && (!maxDate || end > maxDate)) maxDate = end;
  });

  if (!minDate) minDate = new Date(now.getTime() - 86400000);
  if (!maxDate) maxDate = new Date(now.getTime() + 7 * 86400000);

  const dataRange = maxDate - minDate;
  const dynamicPadding = Math.max(30 * 60000, Math.min(6 * 3600000, dataRange * 0.15));
  minDate = new Date(minDate.getTime() - dynamicPadding);
  maxDate = new Date(maxDate.getTime() + dynamicPadding);

  const totalMs = maxDate - minDate;
  const totalDays = Math.ceil(totalMs / 86400000);
  const totalHours = totalMs / 3600000;

  const headers = buildGanttHeaders(minDate, maxDate, totalHours, totalDays);
  const todayPos = ((now - minDate) / totalMs) * 100;
  const showToday = todayPos >= 0 && todayPos <= 100;

  container.innerHTML = `
    <div class="gantt-container">
      <div class="gantt-header">
        <div class="gantt-header-label">WAVE</div>
        <div class="gantt-header-timeline">
          ${headers.map(h => `<div class="gantt-header-day">${h.label}</div>`).join('')}
        </div>
      </div>
      <div class="gantt-body">
        ${showToday ? `<div class="gantt-today-marker" style="left:calc(200px + ${todayPos}% * (100% - 200px - 180px) / 100);" title="Today"></div>` : ''}
        ${waves.map(wave => renderWaveGanttRow(wave, minDate, totalMs, now)).join('')}
      </div>
    </div>
  `;
}

function buildGanttHeaders(minDate, maxDate, totalHours, totalDays) {
  const headers = [];
  let interval, formatOpts;

  if (totalHours <= 3) {
    interval = 30 * 60000;
    formatOpts = { hour: '2-digit', minute: '2-digit' };
  } else if (totalHours <= 8) {
    interval = 3600000;
    formatOpts = { hour: '2-digit', minute: '2-digit' };
  } else if (totalDays <= 2) {
    interval = 3 * 3600000;
    formatOpts = { month: 'short', day: 'numeric', hour: '2-digit' };
  } else if (totalDays <= 7) {
    interval = 6 * 3600000;
    formatOpts = { month: 'short', day: 'numeric', hour: '2-digit' };
  } else {
    interval = 86400000;
    formatOpts = { month: 'short', day: 'numeric' };
  }

  for (let t = minDate.getTime(); t <= maxDate.getTime(); t += interval) {
    const d = new Date(t);
    headers.push({ label: d.toLocaleString('en-US', formatOpts), time: t });
  }

  return headers;
}

function renderWaveGanttRow(wave, minDate, totalMs, now) {
  const start = wave.planned_start ? new Date(wave.planned_start) : null;
  const end = wave.planned_end ? new Date(wave.planned_end) : null;
  const actual_start = wave.started_at ? new Date(wave.started_at) : null;
  const actual_end = wave.completed_at ? new Date(wave.completed_at) : null;

  let plannedLeft = 0, plannedWidth = 5;
  if (start && end) {
    plannedLeft = ((start - minDate) / totalMs) * 100;
    plannedWidth = Math.max(2, ((end - start) / totalMs) * 100);
  }

  let actualLeft = plannedLeft, actualWidth = 0;
  if (actual_start) {
    actualLeft = ((actual_start - minDate) / totalMs) * 100;
    const actualEndTime = actual_end || now;
    actualWidth = Math.max(1, ((actualEndTime - actual_start) / totalMs) * 100);
  }

  const progress = wave.tasks_total > 0 ? Math.round((wave.tasks_done / wave.tasks_total) * 100) : 0;
  const startStr = start ? start.toLocaleString('en-US', { month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' }) : 'Not planned';
  const endStr = end ? end.toLocaleString('en-US', { month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' }) : 'Not planned';
  const hasDeps = wave.depends_on && wave.depends_on.length > 0;

   return `
    <div class="gantt-row" onclick="console.log('Drilling into wave:', '${wave.wave_id}'); showGanttLevel('tasks', '${wave.wave_id}')" title="${wave.name}&#10;Start: ${startStr}&#10;End: ${endStr}&#10;Progress: ${progress}%">
      <div class="gantt-label">
        <div class="gantt-label-status ${wave.status}"></div>
        <div class="gantt-label-info">
          <div class="gantt-label-header">
            <span class="gantt-label-text">${wave.wave_id}</span>
            ${hasDeps ? `<span class="gantt-dep-badge" title="Depends on: ${wave.depends_on}">&#x2192; ${wave.depends_on}</span>` : ''}
            <button class="gantt-markdown-btn" onclick="event.stopPropagation(); showWaveMarkdown('${wave.wave_id}')" title="View wave documentation">
              <svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor">
                <path d="M22.27 19.385H1.73A1.73 1.73 0 0 1 0 17.655V6.345a1.73 1.73 0 0 1 1.73-1.73h20.54A1.73 1.73 0 0 1 24 6.345v11.308a1.73 1.73 0 0 1-1.73 1.731zM5.769 15.923v-4.5l2.308 2.885 2.307-2.885v4.5h2.308V8.078h-2.308l-2.307 2.885-2.308-2.885H3.46v7.847zM21.232 12h-2.309V8.077h-2.307V12h-2.308l3.461 4.039z"/>
              </svg>
            </button>
          </div>
          <div class="gantt-label-summary" title="${wave.name}">${wave.name}</div>
        </div>
      </div>
      <div class="gantt-timeline">
        ${start && end ? `
          <div class="gantt-bar planned ${wave.status}" style="left:${plannedLeft}%;width:${plannedWidth}%;">
            <div class="gantt-bar-progress" style="width:${progress}%"></div>
            <span class="gantt-bar-label">${wave.tasks_done}/${wave.tasks_total}</span>
          </div>
        ` : `<div class="gantt-no-dates">No dates</div>`}
        ${actual_start && wave.status !== 'done' ? `
          <div class="gantt-bar actual" style="left:${actualLeft}%;width:${actualWidth}%;"></div>
        ` : ''}
      </div>
      <div class="gantt-dates">
        <span class="gantt-date-start">${startStr}</span>
        <span class="gantt-date-end">${endStr}</span>
      </div>
    </div>
  `;
}

console.log('Views waves loaded');
