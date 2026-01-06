// Conversation Viewer - Live Module
// SSE streaming and export
// Start SSE live stream
function startConversationLiveStream(projectId, taskId) {
  if (conversationLiveStream) {
    conversationLiveStream.close();
  }
  const url = `${API_BASE}/project/${projectId}/task/${taskId}/live`;
  conversationLiveStream = new EventSource(url);
  conversationLiveStream.onmessage = (event) => {
    try {
      const data = JSON.parse(event.data);
      if (data.type === 'message' && data.message) {
        appendLiveMessage(data.message);
      }
    } catch (e) {
      console.error('SSE parse error:', e);
    }
  };
  conversationLiveStream.onerror = (err) => {
    console.error('SSE error:', err);
    conversationLiveStream.close();
    conversationLiveStream = null;
    const body = document.getElementById('conversationBody');
    if (body) {
      const notice = document.createElement('div');
      notice.className = 'conversation-notice';
      notice.textContent = 'Live stream disconnected';
      body.appendChild(notice);
    }
  };
}
// Append live message to conversation
function appendLiveMessage(msg) {
  const body = document.getElementById('conversationBody');
  if (!body) return;
  const time = new Date(msg.timestamp).toLocaleTimeString('it-IT', { hour: '2-digit', minute: '2-digit', second: '2-digit' });
  const html = msg.role === 'tool' ? renderToolMessage(msg, time) : renderTextMessage(msg, time);
  body.insertAdjacentHTML('beforeend', html);
  body.scrollTop = body.scrollHeight;
}
// Export conversation to markdown
async function exportConversation(projectId, taskId) {
  try {
    const convRes = await fetch(`${API_BASE}/project/${projectId}/task/${taskId}/conversation`);
    const messages = await convRes.json();
    let markdown = `# Conversation: ${taskId}\n\n`;
    markdown += `**Date**: ${new Date().toLocaleString('it-IT')}\n\n`;
    markdown += `---\n\n`;
    messages.forEach(msg => {
      const time = new Date(msg.timestamp).toLocaleTimeString('it-IT');
      markdown += `## [${time}] ${msg.role.toUpperCase()}\n\n`;
      if (msg.role === 'tool') {
        markdown += `**Tool**: ${msg.tool_name}\n\n`;
        if (msg.tool_input) {
          markdown += `**Input**:\n\`\`\`json\n${JSON.stringify(JSON.parse(msg.tool_input), null, 2)}\n\`\`\`\n\n`;
        }
        if (msg.tool_output) {
          markdown += `**Output**:\n\`\`\`\n${msg.tool_output}\n\`\`\`\n\n`;
        }
      } else {
        markdown += `${msg.content}\n\n`;
      }
      markdown += `---\n\n`;
    });
    // Download as file
    const blob = new Blob([markdown], { type: 'text/markdown' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `conversation-${taskId}-${Date.now()}.md`;
    a.click();
    URL.revokeObjectURL(url);
    showToast('Conversation exported', 'success');
  } catch (e) {
    showToast('Export failed: ' + e.message, 'error');
  }
}

