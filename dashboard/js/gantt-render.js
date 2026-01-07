// Gantt Render Module - True Gantt Timeline Visualization
// Part of unified Gantt system, uses GanttCore for data

const GanttRender = {
  timeline: null, // { start, end, duration }

  // SVG icons for consistent flat style
  icons: {
    expand: `<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="6 9 12 15 18 9"></polyline></svg>`,
    collapse: `<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="9 18 15 12 9 6"></polyline></svg>`,
    doc: `<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"></path><polyline points="14 2 14 8 20 8"></polyline><line x1="16" y1="13" x2="8" y2="13"></line><line x1="16" y1="17" x2="8" y2="17"></line></svg>`,
    checkCircle: `<svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor" stroke="none"><circle cx="12" cy="12" r="10"></circle><polyline points="9 12 11 14 15 10" fill="none" stroke="white" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"></polyline></svg>`
  },

  // Format duration intelligently: only show relevant units
  formatDuration(startDate, endDate) {
    if (!startDate || !endDate) return '';
    
    const start = new Date(startDate);
    const end = new Date(endDate);
    const diffMs = end - start;
    
    if (diffMs < 0) return '—';
    
    const seconds = Math.floor(diffMs / 1000) % 60;
    const minutes = Math.floor(diffMs / (1000 * 60)) % 60;
    const hours = Math.floor(diffMs / (1000 * 60 * 60)) % 24;
    const days = Math.floor(diffMs / (1000 * 60 * 60 * 24));
    
    const pad = (n) => n.toString().padStart(2, '0');
    
    if (days > 0) {
      return `${pad(days)}:${pad(hours)}:${pad(minutes)}:${pad(seconds)}`;
    } else if (hours > 0) {
      return `${pad(hours)}:${pad(minutes)}:${pad(seconds)}`;
    } else {
      return `${pad(minutes)}:${pad(seconds)}`;
    }
  },

  // Format short time for display on bars
  formatShortTime(dateStr) {
    if (!dateStr) return '';
    const d = new Date(dateStr);
    return d.toLocaleString('it-IT', { 
      day: '2-digit', 
      month: 'short',
      hour: '2-digit', 
      minute: '2-digit'
    });
  },

  // Format time range smartly - don't repeat date if same day
  formatTimeRange(startStr, endStr) {
    if (!startStr) return '';
    const start = new Date(startStr);
    const end = endStr ? new Date(endStr) : null;
    
    const startDate = start.toLocaleDateString('it-IT', { day: '2-digit', month: 'short' });
    const startTime = start.toLocaleTimeString('it-IT', { hour: '2-digit', minute: '2-digit' });
    
    if (!end) return `${startDate}, ${startTime}`;
    
    const endDate = end.toLocaleDateString('it-IT', { day: '2-digit', month: 'short' });
    const endTime = end.toLocaleTimeString('it-IT', { hour: '2-digit', minute: '2-digit' });
    
    // Same day? Show date once
    if (startDate === endDate) {
      return `${startTime} → ${endTime}`;
    }
    return `${startDate} ${startTime} → ${endDate} ${endTime}`;
  },

  // Calculate timeline bounds from all waves and tasks
  calculateTimeline() {
    const waves = GanttCore.getWaves();
    let minDate = null;
    let maxDate = null;

    waves.forEach(wave => {
      // Check wave dates
      [wave.started_at, wave.planned_start].forEach(d => {
        if (d) {
          const date = new Date(d);
          if (!isNaN(date.getTime()) && (!minDate || date < minDate)) minDate = date;
        }
      });
      [wave.completed_at, wave.planned_end].forEach(d => {
        if (d) {
          const date = new Date(d);
          if (!isNaN(date.getTime()) && (!maxDate || date > maxDate)) maxDate = date;
        }
      });

      // Check task dates - this is important!
      (wave.tasks || []).forEach(task => {
        [task.started_at, task.planned_start].forEach(d => {
          if (d) {
            const date = new Date(d);
            if (!isNaN(date.getTime()) && (!minDate || date < minDate)) minDate = date;
          }
        });
        [task.completed_at, task.planned_end].forEach(d => {
          if (d) {
            const date = new Date(d);
            if (!isNaN(date.getTime()) && (!maxDate || date > maxDate)) maxDate = date;
          }
        });
      });
    });

    // Default to today if no dates
    const now = new Date();
    if (!minDate) minDate = new Date(now.getTime() - 3600000); // 1 hour ago
    if (!maxDate) maxDate = new Date(now.getTime() + 3600000); // 1 hour from now

    // Calculate duration in milliseconds
    const duration = maxDate - minDate;
    
    // Add small padding (2% on each side, minimum 5 minutes)
    const minPadding = 5 * 60 * 1000; // 5 minutes
    const padding = Math.max(minPadding, duration * 0.02);
    
    this.timeline = {
      start: new Date(minDate.getTime() - padding),
      end: new Date(maxDate.getTime() + padding),
      duration: duration + (padding * 2),
      // Determine scale type based on duration
      scaleType: duration < 86400000 ? 'hours' : duration < 604800000 ? 'days' : 'weeks'
    };

    console.log('Timeline calculated:', {
      start: this.timeline.start.toISOString(),
      end: this.timeline.end.toISOString(),
      duration: this.timeline.duration,
      scaleType: this.timeline.scaleType
    });

    return this.timeline;
  },

  // Calculate position and width of a bar on the timeline
  getBarPosition(startDate, endDate) {
    if (!this.timeline || !startDate) return null;

    const start = new Date(startDate);
    const end = endDate ? new Date(endDate) : new Date();
    
    const left = ((start - this.timeline.start) / this.timeline.duration) * 100;
    const width = ((end - start) / this.timeline.duration) * 100;

    return {
      left: Math.max(0, Math.min(100, left)),
      width: Math.max(0.5, Math.min(100 - left, width))
    };
  },

  // Get status color class based on actual progress
  getStatusColor(status, progress) {
    if (status === 'blocked') return 'status-blocked';
    if (progress >= 100) return 'status-done';
    if (progress >= 75) return 'status-high-progress';
    if (progress >= 50) return 'status-medium-progress';
    if (progress >= 25) return 'status-low-progress';
    if (progress > 0) return 'status-started';
    return 'status-pending';
  },

  // Build timeline header with date labels - dynamic scale
  buildTimelineHeader() {
    if (!this.timeline) return '';

    const labels = [];
    const duration = this.timeline.duration;
    const scaleType = this.timeline.scaleType;
    
    // Determine number of ticks based on scale
    let numLabels;
    if (scaleType === 'hours') {
      // For same-day: show every hour or half-hour
      const hours = duration / 3600000;
      numLabels = Math.min(12, Math.max(4, Math.ceil(hours)));
    } else if (scaleType === 'days') {
      // For multi-day: show every day
      const days = duration / 86400000;
      numLabels = Math.min(10, Math.max(4, Math.ceil(days)));
    } else {
      numLabels = 8;
    }
    
    for (let i = 0; i <= numLabels; i++) {
      const date = new Date(this.timeline.start.getTime() + (i * this.timeline.duration / numLabels));
      
      let label, time;
      if (scaleType === 'hours') {
        // Same day: show just time prominently
        label = date.toLocaleTimeString('it-IT', { hour: '2-digit', minute: '2-digit' });
        time = ''; // No need for secondary time
      } else {
        // Multi-day: show date and time
        label = date.toLocaleDateString('it-IT', { day: '2-digit', month: 'short' });
        time = date.toLocaleTimeString('it-IT', { hour: '2-digit', minute: '2-digit' });
      }
      
      labels.push(`<div class="gantt-timeline-tick" style="left: ${(i / numLabels) * 100}%">
        <span class="gantt-tick-date">${label}</span>
        ${time ? `<span class="gantt-tick-time">${time}</span>` : ''}
      </div>`);
    }

    return `<div class="gantt-timeline-scale">${labels.join('')}</div>`;
  },

  render() {
    if (!GanttCore.hasData()) return;

    const contentArea = document.getElementById('ganttContentArea');
    const headerArea = document.getElementById('gantt-timeline-header');
    if (!contentArea) return;

    // Calculate timeline from data
    this.calculateTimeline();

    // Build header
    if (headerArea) {
      headerArea.innerHTML = `
        <div class="gantt-header-info">WAVE / TASK</div>
        <div class="gantt-header-timeline">${this.buildTimelineHeader()}</div>
      `;
    }

    // Render waves and tasks
    const wavesHTML = GanttCore.getWaves().map((wave, index) => this.renderWaveRow(wave, index)).join('');

    contentArea.innerHTML = wavesHTML || `
      <div class="empty-state">
        <div class="empty-state-icon">
          <svg width="48" height="48" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5"><rect x="3" y="4" width="18" height="18" rx="2"></rect><line x1="3" y1="10" x2="21" y2="10"></line></svg>
        </div>
        <div class="empty-state-title">No Timeline Data</div>
      </div>
    `;
  },

  renderWaveRow(wave, index) {
    const isExpanded = GanttCore.isExpanded(wave.wave_id);
    const tasksHTML = isExpanded ? this.renderWaveTasks(wave) : '';
    const expandIcon = isExpanded ? this.icons.expand : this.icons.collapse;
    
    const done = wave.tasks_done || 0;
    const total = wave.tasks_total || 0;
    const progress = total > 0 ? Math.round((done / total) * 100) : 0;
    const status = wave.status || (progress >= 100 ? 'done' : progress > 0 ? 'doing' : 'pending');
    const isActive = status === 'in_progress' || status === 'doing' || (progress > 0 && progress < 100);
    const statusColor = this.getStatusColor(status, progress);

    // Use actual dates if available, otherwise planned
    const startDate = wave.started_at || wave.planned_start;
    const endDate = wave.completed_at || wave.planned_end;
    const barPos = this.getBarPosition(startDate, endDate);
    const duration = this.formatDuration(startDate, endDate);

    // Thor validation
    const thorBadge = wave.thor_validated 
      ? `<span class="gantt-thor-badge validated" title="Validated by Thor">${this.icons.checkCircle}</span>` 
      : '';

    // Show original wave_id (without plan prefix) and plan name
    const displayId = wave.original_wave_id || wave.wave_id;
    const planLabel = wave.planName ? `<span class="gantt-plan-label" title="Plan: ${wave.planName}">P${wave.planId}</span>` : '';

    return `
      <div class="gantt-wave-row ${isExpanded ? 'expanded' : ''} ${isActive ? 'active' : ''}" data-wave-id="${wave.wave_id}">
        <div class="gantt-row-info" onclick="GanttView.toggleWave('${wave.wave_id}')">
          <div class="gantt-row-expand">${expandIcon}</div>
          <div class="gantt-row-name">
            ${planLabel}
            <span class="gantt-row-id">${displayId}</span>
            <span class="gantt-row-title" title="${wave.name || ''}">${wave.name || ''}</span>
          </div>
          <div class="gantt-row-meta">
            <span class="gantt-tasks-count">${done}/${total}</span>
            ${thorBadge}
          </div>
        </div>
        <div class="gantt-row-timeline">
          ${barPos ? `
            <div class="gantt-bar ${statusColor}" style="left: ${barPos.left}%; width: ${barPos.width}%;" 
                 title="${this.formatTimeRange(startDate, endDate)} (${duration})">
              <span class="gantt-bar-label">${progress}%</span>
            </div>
            <div class="gantt-bar-info">
              <span class="gantt-time-range">${this.formatTimeRange(startDate, endDate)}</span>
              <span class="gantt-duration">(${duration})</span>
            </div>
          ` : '<span class="gantt-no-dates">No dates</span>'}
        </div>
      </div>
      ${tasksHTML}
    `;
  },

  renderWaveTasks(wave) {
    const tasks = wave.tasks || [];

    if (tasks.length === 0) {
      return `<div class="gantt-task-row empty"><div class="gantt-row-info"><span class="gantt-empty-msg">No tasks in this wave</span></div><div class="gantt-row-timeline"></div></div>`;
    }

    return tasks
      .filter(task => {
        if (!GanttCore.filters.showCompleted && task.status === 'done') return false;
        if (!GanttCore.filters.showBlocked && task.status === 'blocked') return false;
        return true;
      })
      .map((task, index) => this.renderTaskRow(task, index))
      .join('');
  },

  renderTaskRow(task, index) {
    const status = task.status || 'pending';
    const isActive = status === 'doing' || status === 'in_progress';
    const progress = status === 'done' ? 100 : isActive ? 50 : 0;
    const statusColor = this.getStatusColor(status, progress);
    const priority = (task.priority || 'P3').toUpperCase();

    // Use actual dates if available
    const startDate = task.started_at || task.planned_start;
    const endDate = task.completed_at || task.planned_end;
    const barPos = this.getBarPosition(startDate, endDate);
    const duration = this.formatDuration(startDate, endDate);

    // Thor badge
    const thorBadge = task.thor_validated 
      ? `<span class="gantt-thor-badge validated" title="Validated by Thor">${this.icons.checkCircle}</span>` 
      : '';

    // Doc link
    const docLink = task.markdown_file 
      ? `<a href="/api/file/${encodeURIComponent(task.markdown_file)}" target="_blank" class="gantt-doc-link" onclick="event.stopPropagation();" title="Open: ${task.markdown_file}">${this.icons.doc}</a>`
      : '';

    return `
      <div class="gantt-task-row ${statusColor} ${isActive ? 'active' : ''}" onclick="GanttView.showTaskDetails('${task.task_id}')">
        <div class="gantt-row-info">
          <div class="gantt-task-indent"></div>
          <div class="gantt-row-name">
            <span class="gantt-row-id">${task.task_id}</span>
            <span class="gantt-row-title" title="${task.title || ''}">${task.title || ''}</span>
          </div>
          <div class="gantt-row-meta">
            <span class="gantt-priority priority-${priority.toLowerCase()}">${priority}</span>
            ${thorBadge}
            ${docLink}
          </div>
        </div>
        <div class="gantt-row-timeline">
          ${barPos ? `
            <div class="gantt-bar ${statusColor}" style="left: ${barPos.left}%; width: ${barPos.width}%;"
                 title="${this.formatTimeRange(startDate, endDate)} (${duration})">
              <span class="gantt-bar-label">${duration}</span>
            </div>
            <div class="gantt-bar-info">
              <span class="gantt-time-range">${this.formatTimeRange(startDate, endDate)}</span>
              <span class="gantt-duration">(${duration})</span>
            </div>
          ` : '<span class="gantt-no-dates">No dates</span>'}
        </div>
      </div>
    `;
  }
};

window.GanttRender = GanttRender;
