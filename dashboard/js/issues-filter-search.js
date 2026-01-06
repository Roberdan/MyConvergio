/**
 * Issues Filter - Search Module
 * Search, filtering, and sorting logic
 */
IssuesFilter.prototype.search = function() {
  const searchInput = document.getElementById('issuesSearchInput');
  if (searchInput) {
    this.searchTerm = searchInput.value.toLowerCase().trim();
  }
  this.currentPage = 1;
  this.applyFilters();
};
IssuesFilter.prototype.applyFilters = function() {
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
};
IssuesFilter.prototype.sortResults = function(items) {
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
};

