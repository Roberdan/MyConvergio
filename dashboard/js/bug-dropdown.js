/**
 * Bug Dropdown Component
 * Handles CRUD operations for saved bugs with localStorage persistence
 */

class BugDropdown {
  constructor() {
    this.bugs = this.loadBugs();
    this.dropdown = document.querySelector('.bug-dropdown');
    this.toggle = this.dropdown?.querySelector('.bug-dropdown-toggle');
    this.menu = this.dropdown?.querySelector('.bug-dropdown-menu');
    this.list = this.dropdown?.querySelector('.bug-list');
    this.addBtn = this.dropdown?.querySelector('.add-bug-btn');
    this.archiveBtn = this.dropdown?.querySelector('.archive-btn');

    if (!this.dropdown) {
      console.warn('Bug dropdown component not found in DOM');
      return;
    }

    this.bindEvents();
    this.render();
  }

  /**
   * Load bugs from localStorage
   */
  loadBugs() {
    try {
      const saved = localStorage.getItem('myconvergio-bugs');
      return saved ? JSON.parse(saved) : [];
    } catch (e) {
      console.error('Failed to load bugs from localStorage:', e);
      return [];
    }
  }

  /**
   * Save bugs to localStorage
   */
  saveBugs() {
    try {
      localStorage.setItem('myconvergio-bugs', JSON.stringify(this.bugs));
    } catch (e) {
      console.error('Failed to save bugs to localStorage:', e);
      this.showToast('Storage quota exceeded', 'error');
    }
  }

  /**
   * Bind event listeners
   */
  bindEvents() {
    // Toggle dropdown menu
    this.toggle.addEventListener('click', (e) => {
      e.stopPropagation();
      const wasOpen = this.menu.classList.contains('is-open');
      // Close other dropdowns before opening this one
      if (!wasOpen && typeof closeAllDropdowns === 'function') {
        closeAllDropdowns('bugDropdownMenu');
      }
      const isOpen = this.menu.classList.toggle('is-open');
      this.toggle.setAttribute('aria-expanded', isOpen);
    });

    // Add bug button
    this.addBtn.addEventListener('click', (e) => {
      e.stopPropagation();
      this.addBug();
    });

    // Archive button
    this.archiveBtn.addEventListener('click', (e) => {
      e.stopPropagation();
      this.archiveCompleted();
    });

    // Close dropdown when clicking outside
    document.addEventListener('click', (e) => {
      if (!this.dropdown.contains(e.target)) {
        this.menu.classList.remove('is-open');
        this.toggle.setAttribute('aria-expanded', 'false');
      }
    });

    // Close dropdown on Escape key
    document.addEventListener('keydown', (e) => {
      if (e.key === 'Escape' && this.menu.classList.contains('is-open')) {
        this.menu.classList.remove('is-open');
        this.toggle.setAttribute('aria-expanded', 'false');
      }
    });
  }

  /**
   * Add a new bug
   */
  addBug() {
    const title = prompt('Enter bug title:');
    if (!title || !title.trim()) return;

    let priority = (prompt('Priority (p0/p1/p2):', 'p1') || 'p1').toLowerCase();
    if (!['p0', 'p1', 'p2'].includes(priority)) {
      alert('Invalid priority. Using p1.');
      priority = 'p1';
    }

    const bug = {
      id: `bug-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`,
      title: title.trim(),
      priority,
      version: this.getAppVersion(),
      date: new Date().toISOString().split('T')[0],
      done: false,
      createdAt: new Date().toISOString()
    };

    this.bugs.push(bug);
    this.saveBugs();
    this.render();
    this.showToast(`Bug "${bug.title}" added`);
  }

  /**
   * Edit a bug's title
   */
  editBug(id) {
    const bug = this.bugs.find(b => b.id === id);
    if (!bug) return;

    const newTitle = prompt('Edit bug title:', bug.title);
    if (newTitle && newTitle.trim()) {
      bug.title = newTitle.trim();
      this.saveBugs();
      this.render();
      this.showToast(`Bug updated`);
    }
  }

  /**
   * Delete a bug
   */
  deleteBug(id) {
    const bug = this.bugs.find(b => b.id === id);
    if (!bug) return;

    if (!confirm(`Delete bug "${bug.title}"?`)) return;

    this.bugs = this.bugs.filter(b => b.id !== id);
    this.saveBugs();
    this.render();
    this.showToast(`Bug deleted`);
  }

  /**
   * Toggle bug done status
   */
  toggleBugDone(id, done) {
    const bug = this.bugs.find(b => b.id === id);
    if (bug) {
      bug.done = done;
      this.saveBugs();
      this.render();
    }
  }

  /**
   * Execute bug with planner
   */
  executeWithPlanner(id) {
    const bug = this.bugs.find(b => b.id === id);
    if (!bug) return;

    const params = new URLSearchParams({
      bug: bug.id,
      title: bug.title,
      priority: bug.priority,
      version: bug.version
    });

    window.open(`planner.html?${params.toString()}`, '_blank');
  }

  /**
   * Copy CLI command to clipboard
   */
  copyCLICommand(id) {
    const bug = this.bugs.find(b => b.id === id);
    if (!bug) return;

    const command = `plan-db.sh add-task "${bug.title.replace(/"/g, '\\"')}" --priority ${bug.priority.toUpperCase()} --version ${bug.version}`;

    // Try modern clipboard API first
    if (navigator.clipboard && navigator.clipboard.writeText) {
      navigator.clipboard.writeText(command)
        .then(() => this.showToast('CLI command copied to clipboard!'))
        .catch(() => this.fallbackCopyToClipboard(command));
    } else {
      this.fallbackCopyToClipboard(command);
    }
  }

  /**
   * Fallback clipboard copy for older browsers
   */
  fallbackCopyToClipboard(text) {
    const textarea = document.createElement('textarea');
    textarea.value = text;
    textarea.style.position = 'fixed';
    textarea.style.opacity = '0';
    textarea.style.top = '0';
    textarea.style.left = '0';
    document.body.appendChild(textarea);
    textarea.select();
    try {
      document.execCommand('copy');
      this.showToast('CLI command copied to clipboard!');
    } catch (e) {
      console.error('Failed to copy to clipboard:', e);
      this.showToast('Failed to copy command', 'error');
    }
    document.body.removeChild(textarea);
  }

  /**
   * Archive completed bugs
   */
  archiveCompleted() {
    const completed = this.bugs.filter(b => b.done);
    if (completed.length === 0) {
      alert('No completed bugs to archive');
      return;
    }

    if (!confirm(`Archive ${completed.length} completed bug(s)?`)) return;

    try {
      const archive = JSON.parse(localStorage.getItem('myconvergio-bugs-archive') || '[]');
      archive.push(...completed);
      localStorage.setItem('myconvergio-bugs-archive', JSON.stringify(archive));

      this.bugs = this.bugs.filter(b => !b.done);
      this.saveBugs();
      this.render();
      this.showToast(`${completed.length} bug(s) archived`);
    } catch (e) {
      console.error('Failed to archive bugs:', e);
      this.showToast('Failed to archive bugs', 'error');
    }
  }

  /**
   * Get application version from localStorage or default
   */
  getAppVersion() {
    return localStorage.getItem('app-version') || '1.0.0';
  }

  /**
   * Render bug list
   */
  render() {
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
  }

  /**
   * Update bug count badge
   */
  updateBugCount() {
    const count = this.bugs.filter(b => !b.done).length;
    const countEl = this.toggle?.querySelector('.bug-count');
    if (countEl) {
      countEl.textContent = count;
      countEl.style.display = count > 0 ? 'flex' : 'none';
    }
  }

  /**
   * Show toast notification
   */
  showToast(message, type = 'success') {
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

    // Trigger animation
    setTimeout(() => {
      toast.style.opacity = '1';
      toast.style.transform = 'translateY(0)';
    }, 10);

    // Remove after 2 seconds
    setTimeout(() => {
      toast.style.opacity = '0';
      toast.style.transform = 'translateY(20px)';
      setTimeout(() => {
        if (toast.parentElement) {
          toast.remove();
        }
      }, 300);
    }, 2000);
  }

  /**
   * Escape HTML special characters to prevent XSS
   */
  escapeHtml(text) {
    if (!text) return '';
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
  }
}

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
