// Diff Utilities - Markdown conversion, HTML escaping, syntax highlighting

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
  let html = escapeHtml(text);

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
