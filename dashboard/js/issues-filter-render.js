/**
 * Issues Filter - Render Module
 * Result rendering and display
 */

IssuesFilter.prototype.updateResults = function(items) {
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

  resultsContainer.innerHTML = items.map(item => this.renderResultItem(item)).join('');
};

IssuesFilter.prototype.renderResultItem = function(item) {
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
        <span class="result-date">Updated: ${new Date(item.updatedAt || item.updated_at).toLocaleDateString()}</span>
        ${item.assignee ? `<span class="result-assignee">@ ${item.assignee}</span>` : ''}
        ${item.labels?.length ? `<span class="result-labels">${item.labels.map(l => `<span class="label-tag">${this.sanitize(l)}</span>`).join('')}</span>` : ''}
      </div>
      <div class="result-actions">
        <button class="result-link-btn" onclick="window.open('${item.url || '#'}', '_blank')">View</button>
      </div>
    </div>
  `;
};

IssuesFilter.prototype.updateResultsInfo = function() {
  const countEl = document.getElementById('resultsCount');
  if (countEl) {
    countEl.textContent = `${this.totalResults} result${this.totalResults !== 1 ? 's' : ''}`;
  }
};

// Initialize and export
window.issuesFilter = new IssuesFilter();
window.issuesFilter.init();
