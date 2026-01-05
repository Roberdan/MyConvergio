// Markdown Viewer Modal

let currentMarkdownContent = null;
let currentHighlightTaskId = null;

function showWaveMarkdown(waveId) {
  if (!data?.meta?.plan_id) return;

  fetch(`${API_BASE}/plan/${data.meta.plan_id}/wave/${waveId}/markdown`)
    .then(res => res.json())
    .then(result => {
      if (result.error) {
        console.error('Failed to load wave markdown:', result.error);
        return;
      }
      currentMarkdownContent = result.content;
      currentHighlightTaskId = null;
      renderMarkdownModal(result.filename, result.content);
    })
    .catch(e => console.error('Failed to fetch wave markdown:', e));
}

function showTaskMarkdown(waveId, taskId) {
  if (!data?.meta?.plan_id) return;

  fetch(`${API_BASE}/plan/${data.meta.plan_id}/wave/${waveId}/markdown`)
    .then(res => res.json())
    .then(result => {
      if (result.error) {
        console.error('Failed to load task markdown:', result.error);
        return;
      }
      currentMarkdownContent = result.content;
      currentHighlightTaskId = taskId;
      renderMarkdownModal(result.filename, result.content, taskId);
    })
    .catch(e => console.error('Failed to fetch task markdown:', e));
}

function showPlanMarkdown() {
  if (!data?.meta?.plan_id) return;

  fetch(`${API_BASE}/plan/${data.meta.plan_id}/markdown`)
    .then(res => res.json())
    .then(result => {
      if (result.error) {
        console.error('Failed to load plan markdown:', result.error);
        return;
      }
      currentMarkdownContent = result.content;
      currentHighlightTaskId = null;
      renderMarkdownModal(result.filename, result.content);
    })
    .catch(e => console.error('Failed to fetch plan markdown:', e));
}

function renderMarkdownModal(filename, content, highlightTaskId = null) {
  // Remove existing modal if any
  const existing = document.getElementById('markdownModal');
  if (existing) existing.remove();

  // Create modal
  const modal = document.createElement('div');
  modal.id = 'markdownModal';
  modal.className = 'markdown-modal';
  modal.innerHTML = `
    <div class="markdown-modal-overlay" onclick="closeMarkdownModal()"></div>
    <div class="markdown-modal-content">
      <div class="markdown-modal-header">
        <div class="markdown-modal-title">${filename}</div>
        <button class="markdown-modal-close" onclick="closeMarkdownModal()">✕</button>
      </div>
      <div class="markdown-modal-body" id="markdownBody"></div>
    </div>
  `;

  document.body.appendChild(modal);

  // Render markdown content
  const bodyEl = document.getElementById('markdownBody');
  bodyEl.innerHTML = renderMarkdown(content);

  // Highlight task if specified
  if (highlightTaskId) {
    setTimeout(() => highlightTask(highlightTaskId), 100);
  }

  // Prevent body scroll
  document.body.style.overflow = 'hidden';
}

function closeMarkdownModal() {
  const modal = document.getElementById('markdownModal');
  if (modal) {
    modal.remove();
    document.body.style.overflow = '';
  }
  currentMarkdownContent = null;
  currentHighlightTaskId = null;
}

function renderMarkdown(content) {
  // Basic markdown rendering (can be enhanced with library like marked.js)
  let html = content;

  // Code blocks
  html = html.replace(/```(\w+)?\n([\s\S]*?)```/g, (match, lang, code) => {
    return `<pre class="code-block"><code class="language-${lang || 'text'}">${escapeHtml(code)}</code></pre>`;
  });

  // Inline code
  html = html.replace(/`([^`]+)`/g, '<code class="inline-code">$1</code>');

  // Headers
  html = html.replace(/^### (.+)$/gm, '<h3>$1</h3>');
  html = html.replace(/^## (.+)$/gm, '<h2>$1</h2>');
  html = html.replace(/^# (.+)$/gm, '<h1>$1</h1>');

  // Task checkboxes
  html = html.replace(/^- \[([ xX])\] (.+)$/gm, (match, checked, text) => {
    const isChecked = checked.toLowerCase() === 'x';
    const checkmark = isChecked ? '✓' : ' ';
    const className = isChecked ? 'task-checked' : 'task-unchecked';

    // Extract task ID if present (format: T1.1, T1.2, etc.)
    const taskIdMatch = text.match(/^(T\d+\.\d+)/);
    const taskId = taskIdMatch ? taskIdMatch[1] : null;
    const dataAttr = taskId ? ` data-task-id="${taskId}"` : '';

    return `<div class="task-item ${className}"${dataAttr}><span class="task-checkbox">${checkmark}</span> ${text}</div>`;
  });

  // Regular list items
  html = html.replace(/^- (.+)$/gm, '<li>$1</li>');

  // Bold
  html = html.replace(/\*\*(.+?)\*\*/g, '<strong>$1</strong>');

  // Italic
  html = html.replace(/\*(.+?)\*/g, '<em>$1</em>');

  // Links
  html = html.replace(/\[([^\]]+)\]\(([^)]+)\)/g, '<a href="$2" target="_blank">$1</a>');

  // Line breaks
  html = html.replace(/\n\n/g, '<br><br>');
  html = html.replace(/\n/g, '<br>');

  return html;
}

function highlightTask(taskId) {
  // Find task element
  const taskElements = document.querySelectorAll('[data-task-id]');
  for (const el of taskElements) {
    if (el.dataset.taskId === taskId) {
      el.classList.add('task-highlighted');
      el.scrollIntoView({ behavior: 'smooth', block: 'center' });
      break;
    }
  }
}

function escapeHtml(text) {
  const div = document.createElement('div');
  div.textContent = text;
  return div.innerHTML;
}

// Close modal on ESC key
document.addEventListener('keydown', (e) => {
  if (e.key === 'Escape') {
    closeMarkdownModal();
  }
});
