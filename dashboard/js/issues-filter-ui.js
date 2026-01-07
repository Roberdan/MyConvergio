/**
 * Issues Filter - UI Module
 * Filter UI creation and event handling
 */
IssuesFilter.prototype.createFilterUI = function() {
  const filterContainer = document.getElementById('issuesFilterContainer');
  if (!filterContainer) return;
  filterContainer.innerHTML = `
    <div class="issues-filter-container">
      <div class="filter-search">
        <input type="text" class="filter-search-input" id="issuesSearchInput"
          placeholder="Search issues, bugs, labels..." aria-label="Search issues">
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
        <button class="filter-reset-btn" onclick="window.issuesFilter.reset()">Reset Filters</button>
      </div>
      <div class="filter-results-info">
        <span id="resultsCount">0 results</span>
        <div class="filter-tags" id="activeTags"></div>
      </div>
    </div>
  `;
};
IssuesFilter.prototype.attachEventListeners = function() {
  const searchInput = document.getElementById('issuesSearchInput');
  if (searchInput) {
    searchInput.addEventListener('keyup', (e) => {
      if (e.key === 'Enter') this.search();
    });
  }
};
IssuesFilter.prototype.updateActiveTags = function() {
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
      <button class="tag-remove" onclick="window.issuesFilter.removeTag('${tag.key}')" aria-label="Remove ${tag.label}">x</button>
    </span>
  `).join('');
};
IssuesFilter.prototype.removeTag = function(key) {
  const resetMap = {
    search: () => { this.searchTerm = ''; document.getElementById('issuesSearchInput').value = ''; },
    status: () => { this.filters.status = 'all'; document.getElementById('filterStatus').value = 'all'; },
    priority: () => { this.filters.priority = 'all'; document.getElementById('filterPriority').value = 'all'; },
    type: () => { this.filters.type = 'all'; document.getElementById('filterType').value = 'all'; },
    assignee: () => { this.filters.assignee = 'all'; document.getElementById('filterAssignee').value = 'all'; }
  };
  if (resetMap[key]) resetMap[key]();
  this.applyFilters();
};

