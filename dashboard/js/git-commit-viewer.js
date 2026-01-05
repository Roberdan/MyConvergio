// Git Commit Details Viewer

// Commit details state
let currentCommitSha = null;

async function openCommitDetails(sha) {
  if (!currentProjectId) {
    showToast('No project selected', 'warning');
    return;
  }

  currentCommitSha = sha;

  try {
    const res = await fetch(`${API_BASE}/project/${currentProjectId}/git/commit/${sha}`);
    const data = await res.json();

    if (data.error) {
      showToast(data.error, 'error');
      return;
    }

    showCommitDetailsView(data.commit, data.files);
  } catch (e) {
    showToast('Failed to load commit: ' + e.message, 'error');
  }
}

function showCommitDetailsView(commit, files) {
  // Hide main content areas
  document.querySelectorAll('.main-content > *').forEach(el => {
    el.style.display = 'none';
  });

  // Create or show commit viewer
  let commitViewer = document.getElementById('commitViewer');
  if (!commitViewer) {
    commitViewer = document.createElement('div');
    commitViewer.id = 'commitViewer';
    commitViewer.className = 'commit-viewer';
    document.querySelector('.main-content').appendChild(commitViewer);
  }

  const statsHtml = `+${commit.insertions} -${commit.deletions}`;
  const tree = buildFileTree(files);

  commitViewer.innerHTML = `
    <div class="commit-header">
      <button class="diff-back" onclick="closeCommitDetails()">&#x2190; Back</button>
      <div class="commit-info">
        <span class="commit-hash-badge">${commit.shortHash}</span>
        <span class="commit-subject">${escapeHtml(commit.subject)}</span>
      </div>
      <div class="commit-stats">
        <span class="commit-stat additions">+${commit.insertions}</span>
        <span class="commit-stat deletions">-${commit.deletions}</span>
      </div>
    </div>
    <div class="commit-details-panel">
      <div class="commit-meta-card">
        <div class="commit-meta-row">
          <span class="commit-meta-label">Author</span>
          <span class="commit-meta-value">${escapeHtml(commit.author)} &lt;${escapeHtml(commit.email)}&gt;</span>
        </div>
        <div class="commit-meta-row">
          <span class="commit-meta-label">Date</span>
          <span class="commit-meta-value">${commit.date}</span>
        </div>
        <div class="commit-meta-row">
          <span class="commit-meta-label">Commit</span>
          <span class="commit-meta-value commit-full-hash">${commit.hash}</span>
        </div>
        ${commit.body ? `<div class="commit-body">${escapeHtml(commit.body)}</div>` : ''}
      </div>
      <div class="commit-files-panel">
        <div class="commit-files-header">
          <span>Changed Files</span>
          <span class="commit-files-count">${files.length} file${files.length !== 1 ? 's' : ''}</span>
        </div>
        <div class="commit-files-tree" id="commitFilesTree">
          ${renderCommitFileTree(tree, commit.hash)}
        </div>
      </div>
    </div>
    <div class="commit-diff-container" id="commitDiffContainer">
      <div class="commit-diff-placeholder">Select a file to view changes</div>
    </div>
  `;

  commitViewer.style.display = 'flex';
}

function renderCommitFileTree(tree, commitHash, parentPath = '') {
  let html = '';
  const folders = Object.keys(tree).filter(k => k !== '_files').sort();
  const files = tree._files || [];

  folders.forEach(folder => {
    const folderPath = parentPath ? `${parentPath}/${folder}` : folder;
    const fileCount = countFilesInTree(tree[folder]);
    const folderIcon = getFolderIcon(folder);
    html += `
      <div class="git-tree-folder">
        <div class="git-tree-folder-header" onclick="toggleTreeFolder(this)">
          <span class="git-tree-arrow">
            <svg width="10" height="10" viewBox="0 0 24 24" fill="currentColor"><path d="M8 5v14l11-7z"/></svg>
          </span>
          <span class="git-tree-folder-icon">${folderIcon}</span>
          <span class="git-tree-folder-name">${folder}</span>
          <span class="git-tree-folder-count">${fileCount}</span>
        </div>
        <div class="git-tree-folder-content">
          ${renderCommitFileTree(tree[folder], commitHash, folderPath)}
        </div>
      </div>`;
  });

  files.forEach(file => {
    const icon = getFileIcon(file.name);
    const statusClass = file.status === 'A' ? 'added' : file.status === 'D' ? 'deleted' : 'modified';
    html += `
      <div class="git-tree-file commit-file" onclick="openCommitFileDiff('${currentCommitSha}', '${file.path}')" title="${file.path}">
        <span class="git-tree-file-icon">${icon}</span>
        <span class="git-tree-file-name">${file.name}</span>
        <span class="git-tree-file-status ${statusClass}">${file.status}</span>
      </div>`;
  });

  return html;
}

async function openCommitFileDiff(sha, filePath) {
  if (!currentProjectId) return;

  const container = document.getElementById('commitDiffContainer');
  if (!container) return;

  container.innerHTML = '<div class="commit-diff-loading">Loading diff...</div>';

  try {
    const encodedPath = filePath.split('/').map(encodeURIComponent).join('/');
    const res = await fetch(`${API_BASE}/project/${currentProjectId}/git/commit/${sha}/diff/${encodedPath}`);
    const data = await res.json();

    if (data.error) {
      container.innerHTML = `<div class="commit-diff-error">${data.error}</div>`;
      return;
    }

    renderCommitDiff(container, data);
  } catch (e) {
    container.innerHTML = `<div class="commit-diff-error">Error: ${e.message}</div>`;
  }
}

function renderCommitDiff(container, data) {
  const fileName = data.path.split('/').pop();
  const icon = getFileIcon(fileName);

  let diffHtml = '';
  if (data.diff) {
    diffHtml = buildDiffHtml(data.diff, data.language);
  } else {
    diffHtml = '<div class="diff-empty">No changes in this file</div>';
  }

  container.innerHTML = `
    <div class="commit-diff-header">
      <div class="commit-diff-file">
        <span class="commit-diff-file-icon">${icon}</span>
        <span class="commit-diff-file-path">${data.path}</span>
      </div>
      <div class="commit-diff-commit-info">
        <span class="commit-diff-hash">${data.commit.shortHash}</span>
        <span class="commit-diff-subject">${escapeHtml(data.commit.subject)}</span>
      </div>
    </div>
    <div class="commit-diff-content">
      ${diffHtml}
    </div>
  `;
}

function closeCommitDetails() {
  currentCommitSha = null;

  const commitViewer = document.getElementById('commitViewer');
  if (commitViewer) commitViewer.style.display = 'none';

  // Restore main content
  document.querySelectorAll('.main-content > *').forEach(el => {
    if (el.id !== 'commitViewer' && el.id !== 'diffViewer') {
      el.style.display = '';
    }
  });
}
