/**
 * Issues & Bugs Search/Filter Module
 * Provides powerful filtering and search capabilities for GitHub issues and custom bugs
 */

class IssuesFilter {
  constructor() {
    this.issues = [];
    this.bugs = [];
    this.filteredIssues = [];
    this.filteredBugs = [];
    this.searchTerm = '';
    this.filters = {
      status: 'all',      // all, open, closed
      priority: 'all',    // all, p0, p1, p2
      type: 'all',        // all, bug, feature, issue
      assignee: 'all',    // all, assigned, unassigned, or specific assignee
      label: 'all',       // filter by label
      sortBy: 'updated',  // created, updated, priority
      sortOrder: 'desc'   // asc, desc
    };
    this.resultsPerPage = 20;
    this.currentPage = 1;
    this.totalResults = 0;
    this.init();
  }

  /**
   * Initialize filter UI
   */
  init() {
    this.createFilterUI();
    this.attachEventListeners();
  }

  /**
   * Create filter UI elements
   */
  createFilterUI() {
    const filterContainer = document.getElementById('issuesFilterContainer');
    if (!filterContainer) return;

    const filterHTML = `
      <div class="issues-filter-container">
        <div class="filter-search">
          <input
            type="text"
            class="filter-search-input"
            id="issuesSearchInput"
            placeholder="Search issues, bugs, labels..."
            aria-label="Search issues"
          >
          <button class="filter-search-btn" onclick="window.issuesFilter.search()" aria-label="Search">
            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <circle cx="11" cy="11" r="8"></circle>
              <path d="m21 21-4.35-4.35"></path>
            </svg>
          </button>
        </div>

        <div class="filter-controls">
          <div class="filter-group">
            <label for="filterStatus" class="filter-label">Status</label>
            <select id="filterStatus" class="filter-select" onchange="window.issuesFilter.applyFilters()">
              <option value="all">All</option>
              <option value="open">Open</option>
              <option value="closed">Closed</option>
            </select>
          </div>

          <div class="filter-group">
            <label for="filterPriority" class="filter-label">Priority</label>
            <select id="filterPriority" class="filter-select" onchange="window.issuesFilter.applyFilters()">
              <option value="all">All</option>
              <option value="p0">P0 - Critical</option>
              <option value="p1">P1 - High</option>
              <option value="p2">P2 - Normal</option>
            </select>
          </div>

          <div class="filter-group">
            <label for="filterType" class="filter-label">Type</label>
            <select id="filterType" class="filter-select" onchange="window.issuesFilter.applyFilters()">
              <option value="all">All</option>
              <option value="bug">Bug</option>
              <option value="feature">Feature</option>
              <option value="issue">Issue</option>
            </select>
          </div>

          <div class="filter-group">
            <label for="filterAssignee" class="filter-label">Assignee</label>
            <select id="filterAssignee" class="filter-select" onchange="window.issuesFilter.applyFilters()">
              <option value="all">All</option>
              <option value="assigned">Assigned</option>
              <option value="unassigned">Unassigned</option>
            </select>
          </div>

          <div class="filter-group">
            <label for="filterSort" class="filter-label">Sort</label>
            <select id="filterSort" class="filter-select" onchange="window.issuesFilter.applyFilters()">
              <option value="updated">Last Updated</option>
              <option value="created">Created</option>
              <option value="priority">Priority</option>
            </select>
          </div>

          <button class="filter-reset-btn" onclick="window.issuesFilter.reset()">
            Reset Filters
          </button>
        </div>

        <div class="filter-results-info">
          <span id="resultsCount">0 results</span>
          <div class="filter-tags" id="activeTags"></div>
        </div>
      </div>
    `;

    filterContainer.innerHTML = filterHTML;
  }

  /**
   * Attach event listeners
   */
  attachEventListeners() {
    const searchInput = document.getElementById('issuesSearchInput');
    if (searchInput) {
      searchInput.addEventListener('keyup', (e) => {
        if (e.key === 'Enter') {
          this.search();
        }
      });
    }
  }

  /**
   * Search by term
   */
  search() {
    const searchInput = document.getElementById('issuesSearchInput');
    if (searchInput) {
      this.searchTerm = searchInput.value.toLowerCase().trim();
    }
    this.currentPage = 1;
    this.applyFilters();
  }

  /**
   * Apply all filters
   */
  applyFilters() {
    // Update filters from UI
    this.filters.status = document.getElementById('filterStatus')?.value || 'all';
    this.filters.priority = document.getElementById('filterPriority')?.value || 'all';
    this.filters.type = document.getElementById('filterType')?.value || 'all';
    this.filters.assignee = document.getElementById('filterAssignee')?.value || 'all';
    this.filters.sortBy = document.getElementById('filterSort')?.value || 'updated';

    // Combine issues and bugs
    const allItems = [
      ...this.issues.map(i => ({ ...i, sourceType: 'issue' })),
      ...this.bugs.map(b => ({ ...b, sourceType: 'bug' }))
    ];

    // Apply filters
    let filtered = allItems.filter(item => {
      // Search term
      if (this.searchTerm) {
        const searchableText = `${item.title} ${item.description || ''} ${item.labels?.join(' ') || ''}`.toLowerCase();
        if (!searchableText.includes(this.searchTerm)) return false;
      }

      // Status filter
      if (this.filters.status !== 'all') {
        const itemStatus = item.status || (item.state === 'closed' ? 'closed' : 'open');
        if (itemStatus !== this.filters.status) return false;
      }

      // Priority filter
      if (this.filters.priority !== 'all') {
        const itemPriority = item.priority || this.extractPriority(item);
        if (itemPriority !== this.filters.priority) return false;
      }

      // Type filter
      if (this.filters.type !== 'all') {
        const itemType = item.type || this.extractType(item);
        if (itemType !== this.filters.type) return false;
      }

      // Assignee filter
      if (this.filters.assignee !== 'all') {
        const isAssigned = !!item.assignee;
        if (this.filters.assignee === 'assigned' && !isAssigned) return false;
        if (this.filters.assignee === 'unassigned' && isAssigned) return false;
      }

      return true;
    });

    // Sort
    filtered = this.sortResults(filtered);

    // Pagination
    this.totalResults = filtered.length;
    this.filteredIssues = filtered.filter(i => i.sourceType === 'issue');
    this.filteredBugs = filtered.filter(i => i.sourceType === 'bug');

    const startIdx = (this.currentPage - 1) * this.resultsPerPage;
    const paginatedResults = filtered.slice(startIdx, startIdx + this.resultsPerPage);

    // Update UI
    this.updateResults(paginatedResults);
    this.updateResultsInfo();
    this.updateActiveTags();
  }

  /**
   * Sort results
   */
  sortResults(items) {
    const sortBy = this.filters.sortBy;
    const sortOrder = this.filters.sortOrder === 'asc' ? 1 : -1;

    return items.sort((a, b) => {
      let aVal, bVal;

      switch (sortBy) {
        case 'created':
          aVal = new Date(a.createdAt || a.created_at || 0);
          bVal = new Date(b.createdAt || b.created_at || 0);
          break;
        case 'priority':
          aVal = this.priorityValue(this.extractPriority(a));
          bVal = this.priorityValue(this.extractPriority(b));
          break;
        case 'updated':
        default:
          aVal = new Date(a.updatedAt || a.updated_at || 0);
          bVal = new Date(b.updatedAt || b.updated_at || 0);
          break;
      }

      if (aVal < bVal) return sortOrder;
      if (aVal > bVal) return -sortOrder;
      return 0;
    });
  }

  /**
   * Priority value for sorting
   */
  priorityValue(priority) {
    const map = { 'p0': 0, 'p1': 1, 'p2': 2 };
    return map[priority] || 3;
  }

  /**
   * Extract priority from labels/properties
   */
  extractPriority(item) {
    if (item.priority) return item.priority;
    const label = (item.labels || []).find(l => l.match(/^p[0-2]$/i));
    return label ? label.toLowerCase() : 'p2';
  }

  /**
   * Extract type from item
   */
  extractType(item) {
    if (item.type) return item.type;
    if (item.sourceType === 'bug') return 'bug';
    const label = (item.labels || []).find(l => ['bug', 'feature', 'issue'].includes(l.toLowerCase()));
    return label ? label.toLowerCase() : 'issue';
  }

  /**
   * Update results display
   */
  updateResults(items) {
    const resultsContainer = document.getElementById('issuesFilterResults');
    if (!resultsContainer) return;

    if (items.length === 0) {
      resultsContainer.innerHTML = `
        <div class="filter-no-results">
          <p>No issues or bugs match your search.</p>
          <p class="filter-suggestion">Try adjusting your filters or search term.</p>
        </div>
      `;
      return;
    }

    const resultsHTML = items.map(item => this.renderResultItem(item)).join('');
    resultsContainer.innerHTML = resultsHTML;
  }

  /**
   * Render single result item
   */
  renderResultItem(item) {
    const priority = this.extractPriority(item);
    const type = this.extractType(item);
    const status = item.status || (item.state === 'closed' ? 'closed' : 'open');

    return `
      <div class="filter-result-item" data-id="${item.id || item.bug_id}">
        <div class="result-header">
          <span class="result-badge result-${type}">${type.toUpperCase()}</span>
          <span class="result-priority priority-${priority}">${priority.toUpperCase()}</span>
          <span class="result-status result-status-${status}">${status.charAt(0).toUpperCase() + status.slice(1)}</span>
        </div>
        <h4 class="result-title">${this.sanitize(item.title)}</h4>
        ${item.description ? `<p class="result-description">${this.sanitize(item.description.substring(0, 100))}...</p>` : ''}
        <div class="result-meta">
          <span class="result-date">
            Updated: ${new Date(item.updatedAt || item.updated_at).toLocaleDateString()}
          </span>
          ${item.assignee ? `<span class="result-assignee">👤 ${item.assignee}</span>` : ''}
          ${item.labels?.length ? `<span class="result-labels">${item.labels.map(l => `<span class="label-tag">${this.sanitize(l)}</span>`).join('')}</span>` : ''}
        </div>
        <div class="result-actions">
          <button class="result-link-btn" onclick="window.open('${item.url || '#'}', '_blank')">
            View →
          </button>
        </div>
      </div>
    `;
  }

  /**
   * Sanitize HTML
   */
  sanitize(text) {
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
  }

  /**
   * Update results info
   */
  updateResultsInfo() {
    const countEl = document.getElementById('resultsCount');
    if (countEl) {
      countEl.textContent = `${this.totalResults} result${this.totalResults !== 1 ? 's' : ''}`;
    }
  }

  /**
   * Update active filter tags
   */
  updateActiveTags() {
    const tagsContainer = document.getElementById('activeTags');
    if (!tagsContainer) return;

    const tags = [];
    if (this.searchTerm) tags.push({ label: `Search: "${this.searchTerm}"`, key: 'search' });
    if (this.filters.status !== 'all') tags.push({ label: `Status: ${this.filters.status}`, key: 'status' });
    if (this.filters.priority !== 'all') tags.push({ label: `Priority: ${this.filters.priority}`, key: 'priority' });
    if (this.filters.type !== 'all') tags.push({ label: `Type: ${this.filters.type}`, key: 'type' });
    if (this.filters.assignee !== 'all') tags.push({ label: `Assignee: ${this.filters.assignee}`, key: 'assignee' });

    tagsContainer.innerHTML = tags.map(tag => `
      <span class="filter-tag">
        ${tag.label}
        <button class="tag-remove" onclick="window.issuesFilter.removeTag('${tag.key}')" aria-label="Remove ${tag.label}">×</button>
      </span>
    `).join('');
  }

  /**
   * Remove single tag
   */
  removeTag(key) {
    switch (key) {
      case 'search':
        this.searchTerm = '';
        document.getElementById('issuesSearchInput').value = '';
        break;
      case 'status':
        this.filters.status = 'all';
        document.getElementById('filterStatus').value = 'all';
        break;
      case 'priority':
        this.filters.priority = 'all';
        document.getElementById('filterPriority').value = 'all';
        break;
      case 'type':
        this.filters.type = 'all';
        document.getElementById('filterType').value = 'all';
        break;
      case 'assignee':
        this.filters.assignee = 'all';
        document.getElementById('filterAssignee').value = 'all';
        break;
    }
    this.applyFilters();
  }

  /**
   * Reset all filters
   */
  reset() {
    this.searchTerm = '';
    this.filters = {
      status: 'all',
      priority: 'all',
      type: 'all',
      assignee: 'all',
      label: 'all',
      sortBy: 'updated',
      sortOrder: 'desc'
    };
    this.currentPage = 1;

    // Reset UI
    document.getElementById('issuesSearchInput').value = '';
    document.getElementById('filterStatus').value = 'all';
    document.getElementById('filterPriority').value = 'all';
    document.getElementById('filterType').value = 'all';
    document.getElementById('filterAssignee').value = 'all';
    document.getElementById('filterSort').value = 'updated';

    this.applyFilters();
  }

  /**
   * Update data
   */
  setData(issues = [], bugs = []) {
    this.issues = issues;
    this.bugs = bugs;
    this.applyFilters();
  }
}

// Initialize globally
window.issuesFilter = new IssuesFilter();

console.log('✅ Issues filter module loaded');
