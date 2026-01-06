// Gantt View - Unified Interface
// Combines core data loading and rendering

const GanttView = {
  async load(projectId) {
    await GanttCore.load(projectId);
    this.render();
  },

  render() {
    GanttRender.render();
  },

  renderWithHeader() {
    GanttRender.renderWithHeader();
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

    showToast(`Task: ${task.title}\nStatus: ${task.status}\nPriority: ${task.priority || 'N/A'}`, 'info');
  }
};

window.GanttView = GanttView;
