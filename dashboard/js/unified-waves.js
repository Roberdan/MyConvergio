// Unified Waves Card - Tree Navigation with Live Execution Tracking
// DEPRECATED: Active waves are now highlighted directly in Gantt view

let expandedWaves = new Set();
let expandedTasks = new Set();
let liveStreams = new Map(); // task_id -> EventSource

// Render unified waves card - now disabled, Gantt shows active items
function renderUnifiedWaves() {
  const container = document.getElementById('unifiedWavesCard');
  if (container) {
    container.style.display = 'none';
  }
  return; // Disabled - Gantt view now shows active wave/task highlighting
}

// Render single wave node with tasks
function renderWaveNode(wave) {
  const isExpanded = expandedWaves.has(wave.wave_id);
  const progress = wave.tasks_total > 0 ? Math.round((wave.tasks_done / wave.tasks_total) * 100) : 0;
  const hasActiveTasks = wave.tasks?.some(t => t.status === 'in_progress');

  return `
    <div class="tree-node wave-node ${isExpanded ? 'expanded' : ''}" data-wave-id="${wave.wave_id}">
      <div class="tree-node-header wave-header" onclick="toggleWaveNode('${wave.wave_id}')">
        <span class="tree-expand-icon">${isExpanded ? '▼' : '▶'}</span>
        <span class="tree-node-status ${wave.status}">${getStatusIcon(wave.status)}</span>
        <span class="tree-node-label">
          <span class="tree-node-id">${wave.wave_id}</span>
          <span class="tree-node-name">${wave.name}</span>
        </span>
        ${hasActiveTasks ? '<span class="live-indicator" title="Task in execution">●</span>' : ''}
        <span class="tree-node-meta">${wave.tasks_done}/${wave.tasks_total} (${progress}%)</span>
        <button class="tree-node-action" onclick="event.stopPropagation(); showWaveMarkdown('${wave.wave_id}')" title="View wave documentation">
          <svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor">
            <path d="M22.27 19.385H1.73A1.73 1.73 0 0 1 0 17.655V6.345a1.73 1.73 0 0 1 1.73-1.73h20.54A1.73 1.73 0 0 1 24 6.345v11.308a1.73 1.73 0 0 1-1.73 1.731zM5.769 15.923v-4.5l2.308 2.885 2.307-2.885v4.5h2.308V8.078h-2.308l-2.307 2.885-2.308-2.885H3.46v7.847zM21.232 12h-2.309V8.077h-2.307V12h-2.308l3.461 4.039z"/>
          </svg>
        </button>
      </div>

      ${isExpanded && wave.tasks?.length > 0 ? `
        <div class="tree-node-children">
          ${wave.tasks.map(task => renderTaskNode(wave.wave_id, task)).join('')}
        </div>
      ` : isExpanded && !wave.tasks?.length ? '<div class="tree-empty">No tasks in this wave</div>' : ''}
    </div>
  `;
}

// Render single task node
function renderTaskNode(waveId, task) {
  const isExpanded = expandedTasks.has(task.task_id);
  const isLive = task.executor_status === 'running';
  const taskKey = `${waveId}-${task.task_id}`;

  return `
    <div class="tree-node task-node ${isExpanded ? 'expanded' : ''}" data-task-id="${task.task_id}">
      <div class="tree-node-header task-header" onclick="toggleTaskNode('${task.task_id}')">
        <span class="tree-expand-icon">${isExpanded ? '▼' : '▶'}</span>
        <span class="tree-node-status ${task.status}">${getStatusIcon(task.status)}</span>
        <span class="tree-node-label">
          <span class="tree-node-id">${task.task_id}</span>
          <span class="tree-node-name">${task.title}</span>
        </span>
        ${isLive ? '<span class="live-indicator pulsing" title="Executing now">●</span>' : ''}
        ${task.priority ? `<span class="tree-node-priority ${task.priority}">${task.priority}</span>` : ''}
      </div>

      ${isExpanded ? `
        <div class="tree-node-details">
          <div class="task-detail-row">
            <span class="detail-label">Status:</span>
            <span class="detail-value">${task.status.replace('_', ' ')}</span>
          </div>
          ${task.assignee ? `
            <div class="task-detail-row">
              <span class="detail-label">Assignee:</span>
              <span class="detail-value">${task.assignee}</span>
            </div>
          ` : ''}
          ${task.tokens ? `
            <div class="task-detail-row">
              <span class="detail-label">Tokens:</span>
              <span class="detail-value">${task.tokens.toLocaleString()}</span>
            </div>
          ` : ''}
          ${task.executor_session_id ? `
            <div class="task-detail-row">
              <span class="detail-label">Session:</span>
              <span class="detail-value">${task.executor_session_id.slice(0, 12)}...</span>
            </div>
          ` : ''}
          <div class="task-actions">
            <button class="task-action-btn" onclick="viewTaskConversation('${currentProjectId}', '${task.task_id}')">
              <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"></path>
              </svg>
              View Conversation
            </button>
            ${isLive ? `
              <button class="task-action-btn primary" onclick="watchTaskLive('${currentProjectId}', '${task.task_id}')">
                <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                  <circle cx="12" cy="12" r="10"></circle>
                  <circle cx="12" cy="12" r="3"></circle>
                </svg>
                Watch Live
              </button>
            ` : ''}
          </div>
        </div>
      ` : ''}
    </div>
  `;
}

// Helper: Get status icon
function getStatusIcon(status) {
  const icons = {
    'done': '✓',
    'completed': '✓',
    'in_progress': '●',
    'running': '●',
    'pending': '○',
    'blocked': '✖',
    'failed': '✖'
  };
  return icons[status] || '○';
}

// Toggle unified waves tree visibility
function toggleUnifiedWaves() {
  const tree = document.getElementById('unifiedWavesTree');
  const btn = document.getElementById('unifiedToggleBtn');
  if (!tree || !btn) return;

  const isVisible = tree.style.display !== 'none';
  tree.style.display = isVisible ? 'none' : 'block';
  btn.classList.toggle('open', !isVisible);
}

// Toggle wave node expansion
function toggleWaveNode(waveId) {
  if (expandedWaves.has(waveId)) {
    expandedWaves.delete(waveId);
  } else {
    expandedWaves.add(waveId);
  }
  renderUnifiedWaves();
}

// Toggle task node expansion
function toggleTaskNode(taskId) {
  if (expandedTasks.has(taskId)) {
    expandedTasks.delete(taskId);
  } else {
    expandedTasks.add(taskId);
  }
  renderUnifiedWaves();
}

// Expand all waves
function expandAllWaves() {
  data.waves.forEach(w => expandedWaves.add(w.wave_id));
  renderUnifiedWaves();
}

// Collapse all waves
function collapseAllWaves() {
  expandedWaves.clear();
  expandedTasks.clear();
  renderUnifiedWaves();
}

// View task conversation (opens modal)
function viewTaskConversation(projectId, taskId) {
  openConversationViewer(projectId, taskId, false);
}

// Watch task live (opens modal with live stream)
function watchTaskLive(projectId, taskId) {
  openConversationViewer(projectId, taskId, true);
}
