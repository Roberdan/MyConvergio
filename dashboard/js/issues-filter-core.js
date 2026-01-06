/**
 * Issues Filter - Core Module
 * Class definition, initialization, data management
 */
class IssuesFilter {
  constructor() {
    this.issues = [];
    this.bugs = [];
    this.filteredIssues = [];
    this.filteredBugs = [];
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
    this.resultsPerPage = 20;
    this.currentPage = 1;
    this.totalResults = 0;
  }
  init() {
    this.createFilterUI();
    this.attachEventListeners();
  }
  setData(issues = [], bugs = []) {
    this.issues = issues;
    this.bugs = bugs;
    this.applyFilters();
  }
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
    const inputs = {
      'issuesSearchInput': '',
      'filterStatus': 'all',
      'filterPriority': 'all',
      'filterType': 'all',
      'filterAssignee': 'all',
      'filterSort': 'updated'
    };
    Object.entries(inputs).forEach(([id, val]) => {
      const el = document.getElementById(id);
      if (el) el.value = val;
    });
    this.applyFilters();
  }
  // Priority helpers
  priorityValue(priority) {
    return { 'p0': 0, 'p1': 1, 'p2': 2 }[priority] || 3;
  }
  extractPriority(item) {
    if (item.priority) return item.priority;
    const label = (item.labels || []).find(l => l.match(/^p[0-2]$/i));
    return label ? label.toLowerCase() : 'p2';
  }
  extractType(item) {
    if (item.type) return item.type;
    if (item.sourceType === 'bug') return 'bug';
    const label = (item.labels || []).find(l => ['bug', 'feature', 'issue'].includes(l.toLowerCase()));
    return label ? label.toLowerCase() : 'issue';
  }
  sanitize(text) {
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
  }
}
// Create global instance (methods added by other modules)
window.IssuesFilterClass = IssuesFilter;

