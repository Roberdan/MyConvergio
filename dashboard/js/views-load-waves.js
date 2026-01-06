// Waves View - Simplified with unified Gantt
// Uses GanttView for rendering, provides navigation structure

let ganttViewMode = 'timeline';
let ganttNavigation = { level: 'waves', waveId: null, taskId: null };

async function loadWavesView() {
  Logger.info('Loading waves view...');
  const content = document.getElementById('ganttContent');
  if (!content) return;

  content.innerHTML = '<div class="gantt-loading">Loading waves...</div>';

  if (currentProjectId) {
    await GanttView.load(currentProjectId);
    renderWavesLevel();
  } else {
    content.innerHTML = '<div class="empty-state"><div class="empty-state-title">Select a project</div></div>';
  }
}

function renderWavesLevel() {
  const content = document.getElementById('ganttContent');
  if (!content || !GanttCore.hasData()) return;

  const waves = GanttCore.getWaves();
  const timeline = GanttCore.getTimeline();

  content.innerHTML = `
    <div class="gantt-header">
      <h3>Project Waves - ${GanttCore.data?.project?.project || 'Dashboard'}</h3>
      <div class="gantt-stats">
        <span>Total: ${waves.length} waves</span>
      </div>
    </div>
    <div class="gantt-container">
      ${renderGanttContainer(waves, timeline)}
    </div>
    <div class="gantt-actions">
      <button onclick="GanttView.expandAll()" class="gantt-btn">⊕ Expand All</button>
      <button onclick="GanttView.collapseAll()" class="gantt-btn">⊖ Collapse All</button>
      <button onclick="Logger.info('Export coming soon')" class="gantt-btn">💾 Export</button>
    </div>
  `;
}

function renderGanttContainer(waves, timeline) {
  if (!waves.length) {
    return '<div class="gantt-empty">No waves found</div>';
  }

  return `
    <div class="gantt-body">
      ${waves.map(wave => renderGanttRow(wave, timeline)).join('')}
    </div>
  `;
}

function renderGanttRow(wave, timeline) {
  const isExpanded = GanttCore.isExpanded(wave.wave_id);
  const tasksHTML = isExpanded ? renderWaveTasks(wave) : '';
  const progress = wave.tasks_total > 0 ? Math.round((wave.tasks_done / wave.tasks_total) * 100) : 0;

  let plannedLeft = 0, plannedWidth = 0;
  if (wave.planned_start && wave.planned_end && timeline?.duration) {
    const start = new Date(wave.planned_start);
    const end = new Date(wave.planned_end);
    plannedLeft = ((start - timeline.start) / timeline.duration) * 100;
    plannedWidth = Math.max(1, ((end - start) / timeline.duration) * 100);
  }

  return `
    <div class="gantt-row ${isExpanded ? 'expanded' : ''}" data-wave-id="${wave.wave_id}">
      <div class="gantt-label" onclick="GanttView.toggleWave('${wave.wave_id}'); renderWavesLevel()">
        <div class="gantt-label-status ${wave.status || ''}"></div>
        <div class="gantt-label-info">
          <span class="gantt-label-text">${wave.wave_id}</span>
          <span class="gantt-label-summary">${wave.name || ''}</span>
        </div>
      </div>
      <div class="gantt-timeline">
        ${plannedWidth > 0 ? `
          <div class="gantt-bar planned ${wave.status || ''}"
               style="left:${plannedLeft}%;width:${plannedWidth}%"
               title="${wave.name}">
            <div class="gantt-bar-progress" style="width:${progress}%"></div>
            <span class="gantt-bar-label">${wave.tasks_done || 0}/${wave.tasks_total || 0}</span>
          </div>
        ` : '<div class="gantt-no-dates">No dates</div>'}
      </div>
      <div class="gantt-dates">
        <span>${wave.planned_start ? new Date(wave.planned_start).toLocaleDateString() : '-'}</span>
        <span>${wave.planned_end ? new Date(wave.planned_end).toLocaleDateString() : '-'}</span>
      </div>
    </div>
    ${tasksHTML}
  `;
}

function renderWaveTasks(wave) {
  const tasks = wave.tasks || [];
  if (!tasks.length) {
    return '<div class="gantt-task-row"><div class="gantt-task-info">No tasks</div></div>';
  }

  return tasks
    .filter(t => GanttCore.filters.showCompleted || t.status !== 'done')
    .filter(t => GanttCore.filters.showBlocked || t.status !== 'blocked')
    .map(task => `
      <div class="gantt-task-row" onclick="GanttView.showTaskDetails('${task.task_id}')">
        <div class="gantt-task-info">
          <span class="gantt-task-id">${task.task_id}</span>
          <span class="gantt-task-title">${task.title || ''}</span>
        </div>
        <div class="gantt-task-status">
          <span class="gantt-status-badge ${task.status || ''}">${task.status || 'pending'}</span>
        </div>
      </div>
    `).join('');
}

function showWaveDetails(waveId, waveName, status, done, total) {
  showToast(`Wave: ${waveName}\nID: ${waveId}\nStatus: ${status}\nTasks: ${done}/${total}`, 'info');
}

function setGanttViewMode(mode) {
  ganttViewMode = mode;
  document.querySelectorAll('.gantt-mode-btn').forEach(btn => {
    btn.classList.toggle('active', btn.textContent.toLowerCase().includes(mode));
  });
}

function expandAllGantt() {
  GanttView.expandAll();
  renderWavesLevel();
}

function collapseAllGantt() {
  GanttView.collapseAll();
  renderWavesLevel();
}

function exportGantt() {
  Logger.info('Export Gantt data');
}

function openFile(filePath) {
  Logger.info('Open file:', filePath);
}

function viewFileDiff(filePath) {
  Logger.info('View diff for:', filePath);
}

window.loadWavesView = loadWavesView;
window.showWaveDetails = showWaveDetails;
window.setGanttViewMode = setGanttViewMode;
window.expandAllGantt = expandAllGantt;
window.collapseAllGantt = collapseAllGantt;
window.exportGantt = exportGantt;
window.openFile = openFile;
window.viewFileDiff = viewFileDiff;
