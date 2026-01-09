// Gantt View - Unified Interface
// Combines core data loading and rendering

const GanttView = {
  renderTarget: 'ganttContentArea',

  // Use GanttRender icons if available, fallback to simple text
  getIcon(name) {
    if (window.GanttRender?.icons?.[name]) {
      return window.GanttRender.icons[name];
    }
    // Fallback icons
    const fallbacks = {
      expand: '▼',
      collapse: '▶',
      done: '●',
      doing: '◐',
      blocked: '○',
      pending: '◯',
      task: '□',
      user: ''
    };
    return fallbacks[name] || '';
  },

  getStatusIcon(status) {
    if (window.GanttRender?.getStatusIcon) {
      return window.GanttRender.getStatusIcon(status);
    }
    const iconMap = {
      done: this.getIcon('done'),
      doing: this.getIcon('doing'),
      in_progress: this.getIcon('doing'),
      blocked: this.getIcon('blocked'),
      pending: this.getIcon('pending'),
      todo: this.getIcon('pending')
    };
    return iconMap[status] || this.getIcon('pending');
  },

  async load(projectId, targetId = null) {
    if (targetId) this.renderTarget = targetId;
    await GanttCore.load(projectId);
    this.render();
  },

  render() {
    // Use GanttRender for the new layout
    if (window.GanttRender) {
      GanttRender.render();
      return;
    }
    
    // Fallback if GanttRender not available
    const target = document.getElementById(this.renderTarget);
    if (!target) return;

    if (!GanttCore.hasData()) {
      target.innerHTML = '<div class="empty-state"><div class="empty-state-title">No data available</div></div>';
      return;
    }

    const waves = GanttCore.getWaves();
    target.innerHTML = waves.length ? waves.map((wave, i) => this.renderWaveRowFallback(wave, i)).join('') :
      '<div class="empty-state"><div class="empty-state-title">No waves found</div></div>';
  },

  // Fallback wave row (simplified)
  renderWaveRowFallback(wave, index) {
    const isExpanded = GanttCore.isExpanded(wave.wave_id);
    const done = wave.tasks_done || 0;
    const total = wave.tasks_total || 0;
    const progress = total > 0 ? Math.round((done / total) * 100) : 0;

    return `
      <div class="gantt-wave-row ${isExpanded ? 'expanded' : ''}" data-wave-id="${wave.wave_id}">
        <div class="gantt-row-header" onclick="GanttView.toggleWave('${wave.wave_id}')">
          <div class="gantt-row-expand">${isExpanded ? '▼' : '▶'}</div>
          <div class="gantt-row-id">${wave.wave_id}</div>
          <div class="gantt-row-title">${wave.name || ''}</div>
        </div>
        <div class="gantt-row-progress-area">
          <div class="gantt-progress-bar">
            <div class="gantt-progress-done" style="width: ${progress}%"></div>
            <div class="gantt-progress-remaining" style="width: ${100 - progress}%"></div>
            <span class="gantt-progress-text">${progress}%</span>
          </div>
          <div class="gantt-row-details">
            <span class="gantt-detail-item">${done}/${total} tasks</span>
          </div>
        </div>
      </div>
      ${isExpanded ? this.renderWaveTasksFallback(wave) : ''}
    `;
  },

  renderWaveTasksFallback(wave) {
    const tasks = wave.tasks || [];
    if (!tasks.length) return '<div class="gantt-task-row empty"><span style="padding-left:40px;color:var(--text-muted)">No tasks</span></div>';

    return tasks
      .filter(t => GanttCore.filters.showCompleted || t.status !== 'done')
      .filter(t => GanttCore.filters.showBlocked || t.status !== 'blocked')
      .map(task => {
        const status = task.status || 'pending';
        const isDone = status === 'done';
        const isDoing = status === 'doing' || status === 'in_progress';
        const isBlocked = status === 'blocked';
        let progress = isDone ? 100 : isDoing ? 50 : 0;

        return `
          <div class="gantt-task-row ${isBlocked ? 'blocked' : isDone ? 'complete' : isDoing ? 'in-progress' : ''}" onclick="GanttView.showTaskDetails('${task.task_id}')">
            <div class="gantt-row-header">
              <div class="gantt-task-indent"></div>
              <div class="gantt-row-id">${task.task_id}</div>
              <div class="gantt-row-title">${task.title || ''}</div>
            </div>
            <div class="gantt-row-progress-area">
              <div class="gantt-progress-bar ${isBlocked ? 'blocked' : isDone ? 'complete' : isDoing ? 'in-progress' : ''}">
                <div class="gantt-progress-done" style="width: ${isBlocked ? 100 : progress}%"></div>
                <div class="gantt-progress-remaining" style="width: ${isBlocked ? 0 : (100 - progress)}%"></div>
                <span class="gantt-progress-text">${isBlocked ? 'BLOCKED' : isDone ? 'DONE' : isDoing ? 'IN PROGRESS' : 'PENDING'}</span>
              </div>
              <div class="gantt-row-details">
                <span class="gantt-detail-item">${(task.priority || 'P3').toUpperCase()}</span>
              </div>
            </div>
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
    const btn = document.getElementById('filterCompleted');
    if (btn) btn.classList.toggle('active', GanttCore.filters.showCompleted);
    this.render();
  },

  toggleBlockedTasks() {
    GanttCore.filters.showBlocked = !GanttCore.filters.showBlocked;
    const btn = document.getElementById('filterBlocked');
    if (btn) btn.classList.toggle('active', GanttCore.filters.showBlocked);
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

    // --- Derived data ---
    const status = task.status || 'pending';

    // Extract F-xx requirement from title
    const fxxMatch = (task.title || '').match(/\[F-(\d+)\]/);
    const fxxCode = fxxMatch ? `F-${fxxMatch[1]}` : null;

    // Task type with colors
    const typeColors = { bug: '#ef4444', feature: '#3b82f6', chore: '#6b7280', doc: '#8b5cf6', test: '#10b981' };
    const taskType = task.type || 'feature';

    // Wave progress context
    const waveTasksDone = wave.tasks_done || 0;
    const waveTasksTotal = wave.tasks_total || 0;
    const taskIndex = wave.tasks?.findIndex(t => t.task_id === taskId) + 1 || 0;

    // Calculate duration from started_at to completed_at or now
    const startedAt = task.started_at ? new Date(task.started_at) : null;
    const completedAt = task.completed_at ? new Date(task.completed_at) : null;
    const actualDuration = startedAt ? this.formatDuration(startedAt, completedAt || new Date()) : null;

    // Time in current status
    const statusSince = task.started_at || task.completed_at;
    const timeInStatus = statusSince ? this.formatTimeAgo(new Date(statusSince)) : null;

    // Cost estimate (rough: $0.01 per 1k tokens average)
    const costEstimate = task.tokens ? (task.tokens / 1000 * 0.01).toFixed(2) : null;

    // Executor status
    const executorStatus = task.executor_status;
    const executorActive = executorStatus === 'running' || executorStatus === 'paused';

    // Blocking reason
    const blockingReason = status === 'blocked' && task.notes ? task.notes : null;

    // Markdown path
    const markdownPath = task.markdown_path || null;

    // Status color for header
    const statusColors = {
      done: '#22c55e', doing: '#f59e0b', in_progress: '#f59e0b',
      blocked: '#ef4444', pending: '#6b7280', skipped: '#9ca3af'
    };
    const headerColor = statusColors[status] || '#6b7280';

    modal.innerHTML = `
      <div class="task-details-overlay" onclick="GanttView.closeTaskDetails()"></div>
      <div class="task-details-content">
        <div class="task-details-header" style="border-left: 4px solid ${headerColor};">
          <div class="task-details-title">
            <div class="task-header-badges">
              <span class="task-id-badge">${task.task_id}</span>
              ${fxxCode ? `<span class="task-fxx-badge">${fxxCode}</span>` : ''}
              <span class="task-type-badge" style="background: ${typeColors[taskType]}20; color: ${typeColors[taskType]}; border: 1px solid ${typeColors[taskType]}40;">${taskType}</span>
              ${task.priority ? `<span class="task-priority-badge priority-${task.priority}">${task.priority}</span>` : ''}
            </div>
            <h3>${task.title || 'Untitled Task'}</h3>
          </div>
          <button class="task-details-close" onclick="GanttView.closeTaskDetails()">×</button>
        </div>

        <div class="task-details-body">
          <!-- Status Section -->
          <div class="task-detail-section">
            <div class="task-detail-row">
              <span class="task-detail-label">Status</span>
              <span class="task-detail-value">
                <span class="task-status-pill status-${status}">${status.replace('_', ' ')}</span>
                ${timeInStatus ? `<span class="task-time-ago">${timeInStatus}</span>` : ''}
              </span>
            </div>
            ${executorStatus ? `<div class="task-detail-row">
              <span class="task-detail-label">Executor</span>
              <span class="task-detail-value">
                <span class="executor-status ${executorActive ? 'active' : ''}">${executorStatus}</span>
                ${task.executor_session_id ? `<span class="executor-session">${task.executor_session_id.slice(0, 8)}...</span>` : ''}
              </span>
            </div>` : ''}
          </div>

          ${blockingReason ? `
          <div class="task-detail-section blocking">
            <div class="task-detail-row full-width">
              <span class="task-detail-label">⚠ Blocking Reason</span>
              <div class="task-detail-blocking">${blockingReason}</div>
            </div>
          </div>` : ''}

          <!-- Context Section -->
          <div class="task-detail-section">
            <div class="task-detail-row">
              <span class="task-detail-label">Wave</span>
              <span class="task-detail-value">${wave.name || wave.wave_id}</span>
            </div>
            <div class="task-detail-row">
              <span class="task-detail-label">Progress</span>
              <span class="task-detail-value">Task ${taskIndex} of ${waveTasksTotal} <span class="task-progress-mini">(${waveTasksDone} done)</span></span>
            </div>
          </div>

          <!-- Time Section -->
          ${startedAt || completedAt ? `
          <div class="task-detail-section">
            ${startedAt ? `<div class="task-detail-row">
              <span class="task-detail-label">Started</span>
              <span class="task-detail-value">${startedAt.toLocaleString('it-IT')}</span>
            </div>` : ''}
            ${completedAt ? `<div class="task-detail-row">
              <span class="task-detail-label">Completed</span>
              <span class="task-detail-value">${completedAt.toLocaleString('it-IT')}</span>
            </div>` : ''}
            ${actualDuration ? `<div class="task-detail-row">
              <span class="task-detail-label">Duration</span>
              <span class="task-detail-value"><strong>${actualDuration}</strong></span>
            </div>` : ''}
          </div>` : ''}

          <!-- Metrics Section -->
          ${task.tokens || task.validated_at ? `
          <div class="task-detail-section">
            ${task.tokens ? `<div class="task-detail-row">
              <span class="task-detail-label">Tokens</span>
              <span class="task-detail-value">${task.tokens.toLocaleString()} <span class="task-cost">(~$${costEstimate})</span></span>
            </div>` : ''}
            ${task.validated_at ? `<div class="task-detail-row">
              <span class="task-detail-label">Validated</span>
              <span class="task-detail-value"><span class="thor-check">✓</span> ${task.validated_by || 'Thor'} @ ${new Date(task.validated_at).toLocaleString('it-IT')}</span>
            </div>` : ''}
          </div>` : ''}

          <!-- Source Document -->
          ${markdownPath ? `
          <div class="task-detail-section">
            <div class="task-detail-row full-width">
              <span class="task-detail-label">Source</span>
              <button class="task-markdown-btn" onclick="GanttView.openMarkdownPreview('${markdownPath.replace(/'/g, "\\'")}')">
                <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"></path><polyline points="14 2 14 8 20 8"></polyline></svg>
                View Markdown
              </button>
              <span class="task-markdown-path">${markdownPath.split('/').pop()}</span>
            </div>
          </div>` : ''}

          ${task.assignee ? `
          <div class="task-detail-section">
            <div class="task-detail-row">
              <span class="task-detail-label">Assignee</span>
              <span class="task-detail-value">${task.assignee}</span>
            </div>
          </div>` : ''}
        </div>
      </div>
    `;

    modal.style.display = 'flex';
  },

  // Format duration as HH:MM:SS or MM:SS
  formatDuration(start, end) {
    const diffMs = end - start;
    if (diffMs < 0) return '—';

    const seconds = Math.floor(diffMs / 1000) % 60;
    const minutes = Math.floor(diffMs / (1000 * 60)) % 60;
    const hours = Math.floor(diffMs / (1000 * 60 * 60));

    const pad = n => n.toString().padStart(2, '0');
    if (hours > 0) return `${hours}h ${pad(minutes)}m`;
    if (minutes > 0) return `${minutes}m ${pad(seconds)}s`;
    return `${seconds}s`;
  },

  // Format time ago
  formatTimeAgo(date) {
    const now = new Date();
    const diffMs = now - date;
    const minutes = Math.floor(diffMs / 60000);
    const hours = Math.floor(minutes / 60);
    const days = Math.floor(hours / 24);

    if (days > 0) return `${days}d ago`;
    if (hours > 0) return `${hours}h ago`;
    if (minutes > 0) return `${minutes}m ago`;
    return 'just now';
  },

  closeTaskDetails() {
    const modal = document.getElementById('taskDetailsModal');
    if (modal) modal.style.display = 'none';
  },

  openMarkdown(filePath) {
    this.openMarkdownPreview(filePath);
  },

  // Open markdown preview modal
  openMarkdownPreview(filePath) {
    if (!filePath) return;

    // Create or get preview modal
    let modal = document.getElementById('markdownPreviewModal');
    if (!modal) {
      modal = document.createElement('div');
      modal.id = 'markdownPreviewModal';
      modal.className = 'markdown-preview-modal';
      document.body.appendChild(modal);
    }

    // Show loading state
    modal.innerHTML = `
      <div class="markdown-preview-overlay" onclick="GanttView.closeMarkdownPreview()"></div>
      <div class="markdown-preview-content">
        <div class="markdown-preview-header">
          <div class="markdown-preview-title">
            <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"></path><polyline points="14 2 14 8 20 8"></polyline><line x1="16" y1="13" x2="8" y2="13"></line><line x1="16" y1="17" x2="8" y2="17"></line></svg>
            <span>${filePath.split('/').pop()}</span>
          </div>
          <button class="markdown-preview-close" onclick="GanttView.closeMarkdownPreview()">×</button>
        </div>
        <div class="markdown-preview-body">
          <div class="markdown-loading">Loading...</div>
        </div>
      </div>
    `;
    modal.style.display = 'flex';

    // Fetch markdown content using the file API
    fetch(`/api/file/${encodeURIComponent(filePath)}`)
      .then(res => res.ok ? res.text() : Promise.reject('File not found'))
      .then(content => {
        const body = modal.querySelector('.markdown-preview-body');
        // Simple markdown to HTML conversion (basic)
        const html = this.renderMarkdown(content);
        body.innerHTML = `<div class="markdown-rendered">${html}</div>`;
      })
      .catch(err => {
        const body = modal.querySelector('.markdown-preview-body');
        body.innerHTML = `
          <div class="markdown-error">
            <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="10"></circle><line x1="12" y1="8" x2="12" y2="12"></line><line x1="12" y1="16" x2="12.01" y2="16"></line></svg>
            <p>Could not load file: ${filePath}</p>
            <p class="error-detail">${err}</p>
          </div>
        `;
      });
  },

  closeMarkdownPreview() {
    const modal = document.getElementById('markdownPreviewModal');
    if (modal) modal.style.display = 'none';
  },

  // Simple markdown renderer
  renderMarkdown(text) {
    if (!text) return '';
    
    // Use marked.js if available, otherwise basic conversion
    if (window.marked) {
      return marked.parse(text);
    }
    
    // Basic markdown conversion
    return text
      // Headers
      .replace(/^### (.*$)/gm, '<h3>$1</h3>')
      .replace(/^## (.*$)/gm, '<h2>$1</h2>')
      .replace(/^# (.*$)/gm, '<h1>$1</h1>')
      // Bold and italic
      .replace(/\*\*\*(.*?)\*\*\*/g, '<strong><em>$1</em></strong>')
      .replace(/\*\*(.*?)\*\*/g, '<strong>$1</strong>')
      .replace(/\*(.*?)\*/g, '<em>$1</em>')
      // Code blocks
      .replace(/```(\w*)\n([\s\S]*?)```/g, '<pre><code class="language-$1">$2</code></pre>')
      .replace(/`([^`]+)`/g, '<code>$1</code>')
      // Lists
      .replace(/^\s*[-*]\s+(.*)$/gm, '<li>$1</li>')
      .replace(/(<li>.*<\/li>\n?)+/g, '<ul>$&</ul>')
      // Links
      .replace(/\[([^\]]+)\]\(([^)]+)\)/g, '<a href="$2" target="_blank">$1</a>')
      // Line breaks
      .replace(/\n\n/g, '</p><p>')
      .replace(/\n/g, '<br>')
      // Wrap in paragraphs
      .replace(/^(.+)$/gm, '<p>$1</p>')
      .replace(/<p><h/g, '<h')
      .replace(/<\/h(\d)><\/p>/g, '</h$1>')
      .replace(/<p><ul>/g, '<ul>')
      .replace(/<\/ul><\/p>/g, '</ul>')
      .replace(/<p><pre>/g, '<pre>')
      .replace(/<\/pre><\/p>/g, '</pre>');
  }
};

window.GanttView = GanttView;
