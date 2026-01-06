// Gantt Render Module - Rendering Logic
// Part of unified Gantt system, uses GanttCore for data

const GanttRender = {
  debouncedRender: null,

  init() {
    this.debouncedRender = debouncedRender(100);
  },

  render() {
    if (!GanttCore.hasData()) return;

    const contentArea = document.getElementById('ganttContentArea');
    if (!contentArea) return;

    const wavesHTML = GanttCore.getWaves().map(wave => this.renderWaveRow(wave)).join('');

    contentArea.innerHTML = wavesHTML || `
      <div class="empty-state">
        <div class="empty-state-icon">🌊</div>
        <div class="empty-state-title">No Waves Found</div>
      </div>
    `;
  },

  renderWithHeader() {
    if (!GanttCore.hasData()) return;

    const contentArea = document.getElementById('ganttContentArea');
    if (!contentArea) return;

    const timeline = GanttCore.getTimeline();
    const labels = this.buildTimelineLabels(timeline);

    const timelineLabelsEl = document.getElementById('ganttTimelineLabels');
    if (timelineLabelsEl) timelineLabelsEl.innerHTML = labels;

    const wavesHTML = GanttCore.getWaves().map(wave => this.renderWaveRow(wave)).join('');

    contentArea.innerHTML = wavesHTML || `
      <div class="empty-state">
        <div class="empty-state-icon">🌊</div>
        <div class="empty-state-title">No Waves Found</div>
      </div>
    `;
  },

  buildTimelineLabels(timeline) {
    if (!timeline?.start) return '';

    const labels = [];
    for (let i = 0; i <= 7; i++) {
      const date = new Date(timeline.start.getTime() + (i * timeline.duration / 7));
      const label = date.toLocaleDateString('en-US', { month: 'short', day: 'numeric' });
      labels.push(`<div class="gantt-timeline-label" style="width: 14.28%">${label}</div>`);
    }
    return labels.join('');
  },

  renderWaveRow(wave) {
    const isExpanded = GanttCore.isExpanded(wave.wave_id);
    const tasksHTML = isExpanded ? this.renderWaveTasks(wave) : '';
    const timeline = GanttCore.getTimeline();

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
        <div class="gantt-wave-progress">${this.renderProgress(wave)}</div>
      </div>
      ${tasksHTML}
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

    if (tasks.length === 0) {
      return `<div class="gantt-task-row"><div class="gantt-task-info" style="grid-column:1/-1;text-align:center;color:var(--text-muted)">No tasks</div></div>`;
    }

    return tasks
      .filter(task => {
        if (!GanttCore.filters.showCompleted && task.status === 'done') return false;
        if (!GanttCore.filters.showBlocked && task.status === 'blocked') return false;
        return true;
      })
      .map(task => this.renderTaskRow(task))
      .join('');
  },

  renderTaskRow(task) {
    const statusIcon = task.status === 'done' ? '✅' : task.status === 'doing' ? '🔄' : task.status === 'blocked' ? '🚫' : '⏳';

    return `
      <div class="gantt-task-row" onclick="GanttView.showTaskDetails('${task.task_id}')">
        <div class="gantt-task-info">
          <div class="gantt-task-icon">📋</div>
          <div class="gantt-task-details">
            <div class="gantt-task-id">${task.task_id}</div>
            <div class="gantt-task-title">${task.title || ''}</div>
            <div class="gantt-task-meta">
              <span class="gantt-task-priority ${(task.priority || 'p3').toLowerCase()}">${task.priority || 'P3'}</span>
              ${task.assignee ? `<span>👤 ${task.assignee}</span>` : ''}
            </div>
          </div>
        </div>
        <div class="gantt-task-timeline"><div class="gantt-task-bar-container"></div></div>
        <div class="gantt-task-status"><span class="gantt-status-badge ${task.status || ''}">${statusIcon}</span></div>
        <div class="gantt-task-progress">${statusIcon}</div>
      </div>
    `;
  }
};

window.GanttRender = GanttRender;
