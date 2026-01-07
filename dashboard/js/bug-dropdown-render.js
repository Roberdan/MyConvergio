/**
 * Bug Dropdown - Render Module
 * Rendering, utilities, initialization
 */

BugDropdown.prototype.render = function() {
  if (!this.list) return;

  this.list.innerHTML = '';

  if (this.bugs.length === 0) {
    const emptyLi = document.createElement('li');
    emptyLi.className = 'bug-list-empty';
    emptyLi.textContent = 'No bugs saved';
    this.list.appendChild(emptyLi);
    this.updateBugCount(0);
    return;
  }

  this.bugs.forEach(bug => {
    const li = document.createElement('li');
    li.className = `bug-item ${bug.done ? 'is-done' : ''}`;

    li.innerHTML = `
      <div class="bug-priority">
        <span class="priority-badge priority-${bug.priority}">${bug.priority.toUpperCase()}</span>
      </div>
      <div class="bug-content">
        <div>
          <input type="checkbox" class="bug-checkbox" id="bug-${bug.id}" ${bug.done ? 'checked' : ''}>
          <label for="bug-${bug.id}" class="bug-title">${this.escapeHtml(bug.title)}</label>
        </div>
        <div class="bug-meta">${bug.version} • ${bug.date}</div>
      </div>
      <div class="bug-actions">
        <button class="bug-action-btn bug-edit" title="Edit" aria-label="Edit bug">✎</button>
        <button class="bug-action-btn bug-execute" title="Execute" aria-label="Execute in planner">▶</button>
        <button class="bug-action-btn bug-copy" title="Copy CLI" aria-label="Copy CLI command">📋</button>
        <button class="bug-action-btn bug-delete" title="Delete" aria-label="Delete bug">×</button>
      </div>
    `;

    // Bind event listeners
    li.querySelector('.bug-checkbox').addEventListener('change', (e) => {
      this.toggleBugDone(bug.id, e.target.checked);
    });

    li.querySelector('.bug-edit').addEventListener('click', (e) => {
      e.stopPropagation();
      this.editBug(bug.id);
    });

    li.querySelector('.bug-delete').addEventListener('click', (e) => {
      e.stopPropagation();
      this.deleteBug(bug.id);
    });

    li.querySelector('.bug-execute').addEventListener('click', (e) => {
      e.stopPropagation();
      this.executeWithPlanner(bug.id);
    });

    li.querySelector('.bug-copy').addEventListener('click', (e) => {
      e.stopPropagation();
      this.copyCLICommand(bug.id);
    });

    this.list.appendChild(li);
  });

  this.updateBugCount();
};

BugDropdown.prototype.updateBugCount = function() {
  const count = this.bugs.filter(b => !b.done).length;
  const countEl = this.toggle?.querySelector('.bug-count');
  if (countEl) {
    countEl.textContent = count;
    countEl.style.display = count > 0 ? 'flex' : 'none';
  }
};

BugDropdown.prototype.showToast = function(message, type = 'success') {
  const toast = document.createElement('div');
  toast.style.cssText = `
    position: fixed;
    bottom: 20px;
    right: 20px;
    background: ${type === 'error' ? '#dc3545' : '#22c55e'};
    color: white;
    padding: 12px 20px;
    border-radius: 6px;
    box-shadow: 0 4px 8px rgba(0,0,0,0.2);
    opacity: 0;
    transform: translateY(20px);
    transition: all 0.3s ease;
    z-index: 10000;
    font-size: 13px;
    max-width: 300px;
    word-wrap: break-word;
  `;
  toast.textContent = message;
  document.body.appendChild(toast);

  setTimeout(() => {
    toast.style.opacity = '1';
    toast.style.transform = 'translateY(0)';
  }, 10);

  setTimeout(() => {
    toast.style.opacity = '0';
    toast.style.transform = 'translateY(20px)';
    setTimeout(() => {
      if (toast.parentElement) {
        toast.remove();
      }
    }, 300);
  }, 2000);
};

BugDropdown.prototype.escapeHtml = function(text) {
  if (!text) return '';
  const div = document.createElement('div');
  div.textContent = text;
  return div.innerHTML;
};

// Initialize when DOM is ready
document.addEventListener('DOMContentLoaded', () => {
  window.bugDropdown = new BugDropdown();
});

// Also initialize if script loads after DOM ready
if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', () => {
    if (!window.bugDropdown) {
      window.bugDropdown = new BugDropdown();
    }
  });
} else {
  if (!window.bugDropdown) {
    window.bugDropdown = new BugDropdown();
  }
}
