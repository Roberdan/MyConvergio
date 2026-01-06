/**
 * Wave Pagination Optimization
 * Implements efficient pagination for wave tasks to reduce O(n²) to O(n)
 * Loads tasks on demand instead of rendering all at once
 */
class WavePagination {
  constructor() {
    this.taskPages = new Map(); // waveId -> { page, tasks, totalPages }
    this.pageSize = 20; // Tasks per page
    this.expandedWaves = new Set();
  }
  /**
   * Initialize pagination for a wave
   */
  initWavePagination(waveId, allTasks) {
    if (!allTasks || allTasks.length === 0) {
      this.taskPages.set(waveId, {
        page: 1,
        tasks: [],
        totalPages: 0,
        allTasks: []
      });
      return;
    }
    const totalPages = Math.ceil(allTasks.length / this.pageSize);
    this.taskPages.set(waveId, {
      page: 1,
      tasks: allTasks.slice(0, this.pageSize),
      totalPages,
      allTasks
    });
  }
  /**
   * Get tasks for a specific page
   */
  getTasksForPage(waveId, page) {
    const pagination = this.taskPages.get(waveId);
    if (!pagination) return [];
    const startIndex = (page - 1) * this.pageSize;
    const endIndex = startIndex + this.pageSize;
    pagination.tasks = pagination.allTasks.slice(startIndex, endIndex);
    pagination.page = page;
    return pagination.tasks;
  }
  /**
   * Get current page for wave
   */
  getCurrentPage(waveId) {
    return this.taskPages.get(waveId)?.page || 1;
  }
  /**
   * Get total pages for wave
   */
  getTotalPages(waveId) {
    return this.taskPages.get(waveId)?.totalPages || 0;
  }
  /**
   * Load next page of tasks
   */
  loadNextPage(waveId) {
    const pagination = this.taskPages.get(waveId);
    if (!pagination) return false;
    if (pagination.page < pagination.totalPages) {
      this.getTasksForPage(waveId, pagination.page + 1);
      return true;
    }
    return false;
  }
  /**
   * Load previous page of tasks
   */
  loadPreviousPage(waveId) {
    const pagination = this.taskPages.get(waveId);
    if (!pagination) return false;
    if (pagination.page > 1) {
      this.getTasksForPage(waveId, pagination.page - 1);
      return true;
    }
    return false;
  }
  /**
   * Render pagination controls
   */
  renderPaginationControls(waveId) {
    const pagination = this.taskPages.get(waveId);
    if (!pagination || pagination.totalPages <= 1) return '';
    const currentPage = pagination.page;
    const totalPages = pagination.totalPages;
    const hasMore = currentPage < totalPages;
    const hasPrev = currentPage > 1;
    return `
      <div class="wave-pagination-controls">
        <button class="pagination-btn ${hasPrev ? '' : 'disabled'}"
                onclick="wavePagination.loadAndRender('${waveId}', -1)"
                ${!hasPrev ? 'disabled' : ''}>
          ← Previous
        </button>
        <span class="pagination-info">
          Page ${currentPage} of ${totalPages}
          (${pagination.allTasks.length} total tasks)
        </span>
        <button class="pagination-btn ${hasMore ? '' : 'disabled'}"
                onclick="wavePagination.loadAndRender('${waveId}', 1)"
                ${!hasMore ? 'disabled' : ''}>
          Next →
        </button>
        <button class="pagination-btn"
                onclick="wavePagination.loadAllTasks('${waveId}')"
                title="Load all tasks (may be slow)">
          Load All
        </button>
      </div>
    `;
  }
  /**
   * Load and re-render tasks for a wave
   */
  loadAndRender(waveId, direction) {
    if (direction > 0) {
      this.loadNextPage(waveId);
    } else if (direction < 0) {
      this.loadPreviousPage(waveId);
    }
    // Re-render the wave node
    this.reRenderWaveTasks(waveId);
  }
  /**
   * Load all tasks at once
   */
  loadAllTasks(waveId) {
    const pagination = this.taskPages.get(waveId);
    if (!pagination) return;
    pagination.tasks = pagination.allTasks;
    pagination.page = 1;
    pagination.totalPages = 1;
    this.reRenderWaveTasks(waveId);
  }
  /**
   * Re-render just the tasks for a wave (not the entire tree)
   * This is efficient - O(n) instead of O(n²)
   */
  reRenderWaveTasks(waveId) {
    const waveNode = document.querySelector(`[data-wave-id="${waveId}"]`);
    if (!waveNode) return;
    const pagination = this.taskPages.get(waveId);
    if (!pagination) return;
    const childrenContainer = waveNode.querySelector('.tree-node-children');
    if (!childrenContainer) return;
    // Render only visible tasks
    const tasksHTML = pagination.tasks
      .map(task => this.renderTaskNode(waveId, task))
      .join('');
    const paginationHTML = this.renderPaginationControls(waveId);
    childrenContainer.innerHTML = tasksHTML + paginationHTML;
    // Re-bind event listeners for the newly rendered elements
    this.bindTaskEventListeners(waveNode);
  }
  /**
   * Render a single task node
   */
  renderTaskNode(waveId, task) {
    // This would normally call the existing renderTaskNode function
    // For now, returning the HTML structure
    const taskKey = `${waveId}-${task.task_id}`;
    const isLive = task.executor_status === 'running';
    return `
      <div class="tree-node task-node" data-task-id="${task.task_id}">
        <div class="tree-node-header task-header">
          <span class="tree-expand-icon">▶</span>
          <span class="tree-node-status ${task.status}">●</span>
          <span class="tree-node-label">
            <span class="tree-node-id">${task.task_id}</span>
            <span class="tree-node-name">${task.title || 'Untitled'}</span>
          </span>
          ${isLive ? '<span class="live-indicator" title="Task executing">●</span>' : ''}
          <span class="tree-node-meta">${task.status}</span>
        </div>
      </div>
    `;
  }
  /**
   * Bind event listeners to task nodes
   */
  bindTaskEventListeners(parentNode) {
    const taskHeaders = parentNode.querySelectorAll('.task-header');
    taskHeaders.forEach(header => {
      header.removeEventListener('click', this.handleTaskClick);
      header.addEventListener('click', this.handleTaskClick.bind(this));
    });
  }
  /**
   * Handle task click event
   */
  handleTaskClick(e) {
    const taskNode = e.currentTarget.closest('.task-node');
    if (!taskNode) return;
    taskNode.classList.toggle('expanded');
  }
  /**
   * Optimize: Update task status in-place without full re-render
   * When a single task changes status, only update that task's DOM
   */
  updateTaskStatus(waveId, taskId, newStatus) {
    const taskNode = document.querySelector(`[data-task-id="${taskId}"]`);
    if (!taskNode) return;
    const statusEl = taskNode.querySelector('.tree-node-status');
    if (statusEl) {
      statusEl.className = `tree-node-status ${newStatus}`;
    }
    // Update in pagination data
    const pagination = this.taskPages.get(waveId);
    if (pagination) {
      const task = pagination.allTasks.find(t => t.task_id === taskId);
      if (task) {
        task.status = newStatus;
      }
    }
  }
}
// Initialize globally
window.wavePagination = new WavePagination();
// CSS for pagination controls
const paginationStyles = `
<style>
.wave-pagination-controls {
  display: flex;
  gap: 8px;
  padding: 12px 16px;
  background: var(--bg-secondary, #f9f9f9);
  border-top: 1px solid var(--border-color, #eee);
  font-size: 12px;
  flex-wrap: wrap;
  align-items: center;
}
.pagination-btn {
  padding: 6px 12px;
  background: var(--bg-primary, #fff);
  border: 1px solid var(--border-color, #ddd);
  border-radius: 4px;
  cursor: pointer;
  font-size: 12px;
  transition: all 0.2s ease;
}
.pagination-btn:hover:not(.disabled) {
  background: var(--accent, #007bff);
  color: white;
  border-color: var(--accent, #007bff);
}
.pagination-btn.disabled {
  opacity: 0.5;
  cursor: not-allowed;
}
.pagination-info {
  color: var(--text-secondary, #999);
  white-space: nowrap;
}
</style>
`;
// Inject styles if not already present
if (!document.querySelector('style[data-pagination-styles]')) {
  const styleEl = document.createElement('style');
  styleEl.setAttribute('data-pagination-styles', 'true');
  styleEl.textContent = paginationStyles.replace(/<style>|<\/style>/g, '');
  document.head.appendChild(styleEl);
}

