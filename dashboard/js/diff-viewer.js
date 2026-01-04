// Diff Viewer - VS Code Style File Diff Display

let currentDiffFile = null;

async function openFileDiff(filePath) {
  if (!currentProjectId) {
    showToast('No project selected', 'warning');
    return;
  }

  currentDiffFile = filePath;

  // Show diff view, hide dashboard
  showDiffView(filePath);

  try {
    const res = await fetch(`${API_BASE}/project/${currentProjectId}/git/diff/${encodeURIComponent(filePath)}`);
    const data = await res.json();

    if (data.error) {
      showToast(data.error, 'error');
      return;
    }

    renderDiff(data);
  } catch (e) {
    showToast('Failed to load diff: ' + e.message, 'error');
  }
}

function showDiffView(filePath) {
  // Hide main content areas
  document.querySelectorAll('.main-content > *').forEach(el => {
    el.style.display = 'none';
  });

  // Create or show diff viewer
  let diffViewer = document.getElementById('diffViewer');
  if (!diffViewer) {
    diffViewer = document.createElement('div');
    diffViewer.id = 'diffViewer';
    diffViewer.className = 'diff-viewer';
    document.querySelector('.main-content').appendChild(diffViewer);
  }

  const fileName = filePath.split('/').pop();
  const ext = fileName.split('.').pop().toLowerCase();
  const isMarkdown = ext === 'md' || ext === 'markdown';

  // Eye icon for markdown preview toggle
  const previewBtn = isMarkdown ? `
    <button class="diff-action-btn diff-preview-btn" onclick="toggleMarkdownPreview()" title="Toggle preview" id="previewToggleBtn">
      <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
        <path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z"></path>
        <circle cx="12" cy="12" r="3"></circle>
      </svg>
    </button>
  ` : '';

  diffViewer.innerHTML = `
    <div class="diff-header">
      <button class="diff-back" onclick="closeDiffView()">&#x2190; Back to Dashboard</button>
      <div class="diff-file-info">
        <span class="diff-file-icon">${getFileIcon(fileName)}</span>
        <span class="diff-file-path">${filePath}</span>
      </div>
      <div class="diff-actions">
        ${previewBtn}
        <button class="diff-action-btn" onclick="stageFile('${filePath}')" title="Stage file">+ Stage</button>
        <button class="diff-action-btn" onclick="discardFile('${filePath}')" title="Discard changes">Discard</button>
      </div>
    </div>
    <div class="diff-content" id="diffContent">
      <div class="diff-loading">Loading diff...</div>
    </div>
  `;
  diffViewer.style.display = 'block';
}

function closeDiffView() {
  currentDiffFile = null;

  const diffViewer = document.getElementById('diffViewer');
  if (diffViewer) diffViewer.style.display = 'none';

  // Restore main content
  document.querySelectorAll('.main-content > *').forEach(el => {
    if (el.id !== 'diffViewer') {
      el.style.display = '';
    }
  });

  // Reset view to dashboard
  showView('dashboard');
}

function renderDiff(data) {
  const container = document.getElementById('diffContent');
  if (!container) return;

  // Handle markdown files - show both diff and preview
  if (data.language === 'markdown') {
    renderMarkdownWithDiff(container, data);
    return;
  }

  // Handle new files (no diff)
  if (data.isNew && data.content) {
    renderNewFile(container, data.content, data.language);
    return;
  }

  // Handle diff
  if (data.diff) {
    renderGitDiff(container, data.diff, data.language);
    return;
  }

  container.innerHTML = '<div class="diff-empty">No changes to display</div>';
}

function renderGitDiff(container, diff, language) {
  const lines = diff.split('\n');
  let html = '<div class="diff-lines">';
  let oldLineNum = 0;
  let newLineNum = 0;
  let inHunk = false;

  lines.forEach((line, i) => {
    // Parse hunk header @@ -a,b +c,d @@
    const hunkMatch = line.match(/^@@ -(\d+),?\d* \+(\d+),?\d* @@/);
    if (hunkMatch) {
      oldLineNum = parseInt(hunkMatch[1]) - 1;
      newLineNum = parseInt(hunkMatch[2]) - 1;
      inHunk = true;
      html += `<div class="diff-line hunk"><span class="diff-gutter">...</span><span class="diff-gutter">...</span><span class="diff-text">${escapeHtml(line)}</span></div>`;
      return;
    }

    // Skip diff headers
    if (line.startsWith('diff --git') || line.startsWith('index ') ||
        line.startsWith('---') || line.startsWith('+++') || line.startsWith('\\')) {
      return;
    }

    if (!inHunk) return;

    const type = line.startsWith('+') ? 'add' : line.startsWith('-') ? 'del' : 'ctx';
    const content = line.substring(1);

    if (type === 'add') {
      newLineNum++;
      html += `<div class="diff-line ${type}"><span class="diff-gutter"></span><span class="diff-gutter">${newLineNum}</span><span class="diff-text">${highlightLine(content, language)}</span></div>`;
    } else if (type === 'del') {
      oldLineNum++;
      html += `<div class="diff-line ${type}"><span class="diff-gutter">${oldLineNum}</span><span class="diff-gutter"></span><span class="diff-text">${highlightLine(content, language)}</span></div>`;
    } else {
      oldLineNum++;
      newLineNum++;
      html += `<div class="diff-line ${type}"><span class="diff-gutter">${oldLineNum}</span><span class="diff-gutter">${newLineNum}</span><span class="diff-text">${highlightLine(content, language)}</span></div>`;
    }
  });

  html += '</div>';
  container.innerHTML = html;
}

function renderNewFile(container, content, language) {
  const lines = content.split('\n');
  let html = '<div class="diff-lines new-file">';
  html += '<div class="diff-line hunk"><span class="diff-gutter">+</span><span class="diff-gutter"></span><span class="diff-text">New file</span></div>';

  lines.forEach((line, i) => {
    html += `<div class="diff-line add"><span class="diff-gutter"></span><span class="diff-gutter">${i + 1}</span><span class="diff-text">${highlightLine(line, language)}</span></div>`;
  });

  html += '</div>';
  container.innerHTML = html;
}

// Markdown with Diff - Diff only by default, toggle for preview (Zed-style)
let markdownPreviewVisible = false;
let cachedMarkdownHtml = '';

function renderMarkdownWithDiff(container, data) {
  const content = data.content || '';
  const diff = data.diff || '';

  // Convert markdown to HTML and cache it
  cachedMarkdownHtml = markdownToHtml(content);

  // Build diff HTML if there's a diff
  let diffHtml = '';
  if (diff) {
    diffHtml = buildDiffHtml(diff, 'markdown');
  } else if (data.isNew) {
    diffHtml = buildNewFileHtml(content);
  }

  // Show only diff by default
  markdownPreviewVisible = false;
  container.innerHTML = `
    <div class="diff-markdown-container" id="diffMarkdownContainer">
      <div class="diff-pane-full" id="diffPane">
        ${diffHtml || '<div class="diff-empty">No diff available</div>'}
      </div>
      <div class="diff-preview-pane" id="previewPane" style="display: none;">
        <div class="diff-pane-header">Preview</div>
        <div class="diff-pane-content markdown-body">
          ${cachedMarkdownHtml}
        </div>
      </div>
    </div>
  `;
  updatePreviewButton();
}

function toggleMarkdownPreview() {
  markdownPreviewVisible = !markdownPreviewVisible;
  const container = document.getElementById('diffMarkdownContainer');
  const diffPane = document.getElementById('diffPane');
  const previewPane = document.getElementById('previewPane');

  if (!container || !diffPane || !previewPane) return;

  if (markdownPreviewVisible) {
    container.classList.add('split-view');
    diffPane.classList.add('split');
    previewPane.style.display = '';
  } else {
    container.classList.remove('split-view');
    diffPane.classList.remove('split');
    previewPane.style.display = 'none';
  }
  updatePreviewButton();
}

function updatePreviewButton() {
  const btn = document.getElementById('previewToggleBtn');
  if (btn) {
    btn.classList.toggle('active', markdownPreviewVisible);
  }
}

function switchDiffTab(mode) {
  document.querySelectorAll('.diff-tab').forEach(t => t.classList.remove('active'));
  document.querySelector(`.diff-tab[onclick*="${mode}"]`)?.classList.add('active');

  const diffPane = document.getElementById('diffPane');
  const previewPane = document.getElementById('previewPane');
  const container = document.getElementById('diffSplitContainer');

  if (mode === 'split') {
    container.classList.remove('single-pane');
    diffPane.style.display = '';
    previewPane.style.display = '';
  } else if (mode === 'diff') {
    container.classList.add('single-pane');
    diffPane.style.display = '';
    previewPane.style.display = 'none';
  } else if (mode === 'preview') {
    container.classList.add('single-pane');
    diffPane.style.display = 'none';
    previewPane.style.display = '';
  }
}

function markdownToHtml(content) {
  return content
    .replace(/^### (.+)$/gm, '<h3>$1</h3>')
    .replace(/^## (.+)$/gm, '<h2>$1</h2>')
    .replace(/^# (.+)$/gm, '<h1>$1</h1>')
    .replace(/\*\*(.+?)\*\*/g, '<strong>$1</strong>')
    .replace(/\*(.+?)\*/g, '<em>$1</em>')
    .replace(/`([^`]+)`/g, '<code>$1</code>')
    .replace(/```(\w*)\n([\s\S]*?)```/g, (m, lang, code) => {
      return `<pre><code class="language-${lang || 'plaintext'}">${escapeHtml(code.trim())}</code></pre>`;
    })
    .replace(/^\- (.+)$/gm, '<li>$1</li>')
    .replace(/(<li>[\s\S]*?<\/li>)+/g, '<ul>$&</ul>')
    .replace(/^\d+\. (.+)$/gm, '<li>$1</li>')
    .replace(/\n\n/g, '</p><p>')
    .replace(/\[([^\]]+)\]\(([^)]+)\)/g, '<a href="$2" target="_blank">$1</a>')
    .replace(/^(?!<[huplo])/gm, '<p>$&')
    .replace(/(?<![>])$/gm, '</p>');
}

function buildDiffHtml(diff, language) {
  const lines = diff.split('\n');
  let html = '<div class="diff-lines">';
  let oldLineNum = 0;
  let newLineNum = 0;
  let inHunk = false;

  lines.forEach((line) => {
    const hunkMatch = line.match(/^@@ -(\d+),?\d* \+(\d+),?\d* @@/);
    if (hunkMatch) {
      oldLineNum = parseInt(hunkMatch[1]) - 1;
      newLineNum = parseInt(hunkMatch[2]) - 1;
      inHunk = true;
      html += `<div class="diff-line hunk"><span class="diff-gutter">...</span><span class="diff-gutter">...</span><span class="diff-text">${escapeHtml(line)}</span></div>`;
      return;
    }

    if (line.startsWith('diff --git') || line.startsWith('index ') ||
        line.startsWith('---') || line.startsWith('+++') || line.startsWith('\\')) {
      return;
    }

    if (!inHunk) return;

    const type = line.startsWith('+') ? 'add' : line.startsWith('-') ? 'del' : 'ctx';
    const content = line.substring(1);

    if (type === 'add') {
      newLineNum++;
      html += `<div class="diff-line ${type}"><span class="diff-gutter"></span><span class="diff-gutter">${newLineNum}</span><span class="diff-text">${escapeHtml(content)}</span></div>`;
    } else if (type === 'del') {
      oldLineNum++;
      html += `<div class="diff-line ${type}"><span class="diff-gutter">${oldLineNum}</span><span class="diff-gutter"></span><span class="diff-text">${escapeHtml(content)}</span></div>`;
    } else {
      oldLineNum++;
      newLineNum++;
      html += `<div class="diff-line ${type}"><span class="diff-gutter">${oldLineNum}</span><span class="diff-gutter">${newLineNum}</span><span class="diff-text">${escapeHtml(content)}</span></div>`;
    }
  });

  html += '</div>';
  return html;
}

function buildNewFileHtml(content) {
  const lines = content.split('\n');
  let html = '<div class="diff-lines new-file">';
  html += '<div class="diff-line hunk"><span class="diff-gutter">+</span><span class="diff-gutter"></span><span class="diff-text">New file</span></div>';

  lines.forEach((line, i) => {
    html += `<div class="diff-line add"><span class="diff-gutter"></span><span class="diff-gutter">${i + 1}</span><span class="diff-text">${escapeHtml(line)}</span></div>`;
  });

  html += '</div>';
  return html;
}

function highlightLine(text, language) {
  // Basic syntax highlighting for common patterns
  let html = escapeHtml(text);

  // Keywords
  const keywords = {
    javascript: /\b(const|let|var|function|return|if|else|for|while|class|import|export|from|default|async|await|try|catch|throw|new|this|typeof|instanceof)\b/g,
    typescript: /\b(const|let|var|function|return|if|else|for|while|class|import|export|from|default|async|await|try|catch|throw|new|this|typeof|instanceof|interface|type|enum|implements|extends|public|private|protected|readonly)\b/g,
    python: /\b(def|class|if|elif|else|for|while|return|import|from|as|try|except|raise|with|lambda|yield|async|await|True|False|None)\b/g,
    css: /\b(display|flex|grid|margin|padding|border|color|background|font|width|height|position|top|left|right|bottom|z-index)\b/g
  };

  const kwPattern = keywords[language] || keywords.javascript;
  html = html.replace(kwPattern, '<span class="hl-keyword">$1</span>');

  // Strings
  html = html.replace(/(&quot;[^&]*&quot;|&#39;[^&]*&#39;|`[^`]*`)/g, '<span class="hl-string">$1</span>');

  // Numbers
  html = html.replace(/\b(\d+\.?\d*)\b/g, '<span class="hl-number">$1</span>');

  // Comments
  html = html.replace(/(\/\/.*$|\/\*[\s\S]*?\*\/|#.*$)/gm, '<span class="hl-comment">$1</span>');

  return html;
}

function escapeHtml(text) {
  return text
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}
