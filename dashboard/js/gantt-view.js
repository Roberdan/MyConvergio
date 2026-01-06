// Gantt View - Unified Interface
// Combines core data loading and rendering

const GanttView = {
  renderTarget: 'ganttContentArea',

  async load(projectId, targetId = null) {
    if (targetId) this.renderTarget = targetId;
    await GanttCore.load(projectId);
    this.render();
  },

  render() {
    const target = document.getElementById(this.renderTarget);
    if (!target) return;

    if (!GanttCore.hasData()) {
      target.innerHTML = '<div class="empty-state"><div class="empty-state-title">No data available</div></div>';
      return;
    }

    const waves = GanttCore.getWaves();
    const timeline = GanttCore.getTimeline();

    target.innerHTML = waves.length ? waves.map(wave => this.renderWaveRow(wave, timeline)).join('') :
      '<div class="empty-state"><div class="empty-state-title">No waves found</div></div>';
  },

  renderWaveRow(wave, timeline) {
    const isExpanded = GanttCore.isExpanded(wave.wave_id);
    const progress = wave.tasks_total > 0 ? Math.round((wave.tasks_done / wave.tasks_total) * 100) : 0;

    let plannedLeft = 0, plannedWidth = 0;
    if (wave.planned_start && wave.planned_end && timeline?.duration) {
      const start = new Date(wave.planned_start);
      const end = new Date(wave.planned_end);
      plannedLeft = ((start - timeline.start) / timeline.duration) * 100;
      plannedWidth = Math.max(1, ((end - start) / timeline.duration) * 100);
    }

    return `
      <div class="gantt-wave-row ${isExpanded ? 'expanded' : ''}" data-wave-id="${wave.wave_id}">
        <div class="gantt-wave-info" onclick="GanttView.toggleWave('${wave.wave_id}')">
          <div class="gantt-wave-expand-icon">${isExpanded ? '▼' : '▶'}</div>
          <div class="gantt-wave-details">
            <div class="gantt-wave-id">${wave.wave_id}</div>
            <div class="gantt-wave-name">${wave.name || ''}</div>
            <div class="gantt-wave-meta">
              <span>${wave.tasks_total || 0} tasks</span>
              ${wave.assignee ? `<span>👤 ${wave.assignee}</span>` : ''}
            </div>
          </div>
        </div>
        <div class="gantt-wave-timeline">${this.renderTimelineBar(wave, timeline)}</div>
        <div class="gantt-wave-status">
          <span class="gantt-status-badge ${wave.status || ''}">${wave.status || 'pending'}</span>
        </div>
        <div class="gantt-wave-progress">
          ${this.renderProgress(wave)}
        </div>
      </div>
      ${isExpanded ? this.renderWaveTasks(wave) : ''}
    `;
  },

  renderTimelineBar(wave, timeline) {
    if (!timeline?.duration) return '<div class="gantt-wave-bar-container"></div>';

    let plannedLeft = 0, plannedWidth = 0;
    let actualLeft = 0, actualWidth = 0;

    if (wave.planned_start && wave.planned_end) {
      const start = new Date(wave.planned_start);
      const end = new Date(wave.planned_end);
      plannedLeft = ((start - timeline.start) / timeline.duration) * 100;
      plannedWidth = Math.max(1, ((end - start) / timeline.duration) * 100);
    }

    if (wave.started_at) {
      const start = new Date(wave.started_at);
      const end = wave.completed_at ? new Date(wave.completed_at) : new Date();
      actualLeft = ((start - timeline.start) / timeline.duration) * 100;
      actualWidth = Math.max(1, ((end - start) / timeline.duration) * 100);
    }

    return `
      <div class="gantt-wave-bar-container">
        ${plannedWidth > 0 ? `<div class="gantt-wave-bar planned" style="left: ${plannedLeft}%; width: ${plannedWidth}%"></div>` : ''}
        ${actualWidth > 0 ? `<div class="gantt-wave-bar actual" style="left: ${actualLeft}%; width: ${actualWidth}%"></div>` : ''}
      </div>
    `;
  },

  renderProgress(wave) {
    const progress = wave.tasks_total > 0 ? Math.round((wave.tasks_done / wave.tasks_total) * 100) : 0;
    const circumference = 2 * Math.PI * 18;
    const strokeDasharray = (progress / 100) * circumference;

    return `
      <div class="gantt-progress-circle">
        <svg viewBox="0 0 40 40">
          <circle cx="20" cy="20" r="18" class="gantt-progress-bg" />
          <circle cx="20" cy="20" r="18" class="gantt-progress-fill" stroke-dasharray="${strokeDasharray} ${circumference}" />
        </svg>
        <div class="gantt-progress-text">${progress}%</div>
      </div>
      <div class="gantt-progress-label">${wave.tasks_done || 0}/${wave.tasks_total || 0}</div>
    `;
  },

  renderWaveTasks(wave) {
    const tasks = wave.tasks || [];
    if (!tasks.length) {
      return '<div class="gantt-task-row"><div class="gantt-task-info">No tasks</div></div>';
    }

    return tasks
      .filter(t => GanttCore.filters.showCompleted || t.status !== 'done')
      .filter(t => GanttCore.filters.showBlocked || t.status !== 'blocked')
      .map(task => {
        const statusIcon = task.status === 'done' ? '✅' : task.status === 'doing' ? '🔄' : task.status === 'blocked' ? '🚫' : '⏳';
        return `
          <div class="gantt-task-row" onclick="GanttView.showTaskDetails('${task.task_id}')">
            <div class="gantt-task-info">
              <div class="gantt-task-icon">📋</div>
              <div class="gantt-task-details">
                <div class="gantt-task-id">${task.task_id}</div>
                <div class="gantt-task-title">${task.title || ''}</div>
              </div>
            </div>
            <div class="gantt-task-timeline"><div class="gantt-task-bar-container"></div></div>
            <div class="gantt-task-status"><span class="gantt-status-badge ${task.status || ''}">${statusIcon}</span></div>
          </div>
        `;
      }).join('');
  },

  toggleWave(waveId) {
    GanttCore.toggleWave(waveId);
    this.render();
  },

  expandAll() {
    GanttCore.expandAll();
    this.render();
  },

  collapseAll() {
    GanttCore.collapseAll();
    this.render();
  },

  refresh() {
    if (currentProjectId) {
      this.load(currentProjectId);
    }
  },

  toggleCompletedTasks() {
    GanttCore.filters.showCompleted = !GanttCore.filters.showCompleted;
    const checkbox = document.getElementById('showCompletedTasks');
    if (checkbox) checkbox.checked = GanttCore.filters.showCompleted;
    this.render();
  },

  toggleBlockedTasks() {
    GanttCore.filters.showBlocked = !GanttCore.filters.showBlocked;
    const checkbox = document.getElementById('showBlockedTasks');
    if (checkbox) checkbox.checked = GanttCore.filters.showBlocked;
    this.render();
  },

  showTaskDetails(taskId) {
    const wave = GanttCore.getWaves().find(w => w.tasks?.some(t => t.task_id === taskId));
    if (!wave) return;

    const task = wave.tasks.find(t => t.task_id === taskId);
    if (!task) return;

    // Create or show task details modal
    let modal = document.getElementById('taskDetailsModal');
    if (!modal) {
      modal = document.createElement('div');
      modal.id = 'taskDetailsModal';
      modal.className = 'task-details-modal';
      document.body.appendChild(modal);
    }

    const statusIcon = task.status === 'done' ? '✅' : task.status === 'doing' ? '🔄' : task.status === 'blocked' ? '🚫' : '⏳';
    const priorityBadge = task.priority ? `<span class="task-priority-badge priority-${task.priority}">${task.priority}</span>` : '';

    modal.innerHTML = `
      <div class="task-details-overlay" onclick="GanttView.closeTaskDetails()"></div>
      <div class="task-details-content">
        <div class="task-details-header">
          <div class="task-details-title">
            <span class="task-id-badge">${task.task_id}</span>
            <h3>${task.title || 'Untitled Task'}</h3>
          </div>
          <button class="task-details-close" onclick="GanttView.closeTaskDetails()">×</button>
        </div>
        <div class="task-details-body">
          <div class="task-detail-row">
            <span class="task-detail-label">Status</span>
            <span class="task-detail-value"><span class="gantt-status-badge ${task.status}">${statusIcon} ${task.status}</span></span>
          </div>
          <div class="task-detail-row">
            <span class="task-detail-label">Wave</span>
            <span class="task-detail-value">${wave.wave_id} - ${wave.name || ''}</span>
          </div>
          ${task.priority ? `<div class="task-detail-row">
            <span class="task-detail-label">Priority</span>
            <span class="task-detail-value">${priorityBadge}</span>
          </div>` : ''}
          ${task.assignee ? `<div class="task-detail-row">
            <span class="task-detail-label">Assignee</span>
            <span class="task-detail-value">👤 ${task.assignee}</span>
          </div>` : ''}
          ${task.description ? `<div class="task-detail-row full-width">
            <span class="task-detail-label">Description</span>
            <div class="task-detail-description">${task.description}</div>
          </div>` : ''}
          ${task.created_at ? `<div class="task-detail-row">
            <span class="task-detail-label">Created</span>
            <span class="task-detail-value">${new Date(task.created_at).toLocaleString()}</span>
          </div>` : ''}
          ${task.completed_at ? `<div class="task-detail-row">
            <span class="task-detail-label">Completed</span>
            <span class="task-detail-value">${new Date(task.completed_at).toLocaleString()}</span>
          </div>` : ''}
        </div>
      </div>
    `;

    modal.style.display = 'flex';
  },

  closeTaskDetails() {
    const modal = document.getElementById('taskDetailsModal');
    if (modal) modal.style.display = 'none';
  }
};

window.GanttView = GanttView;
