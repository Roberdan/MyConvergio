/* idea-jar.js — Idea Jar CRUD: list, create/edit modal, notes, filter, hotkey */
let _ideas = [];
let _projects = [];

async function fetchIdeas(params = {}) {
  const q = new URLSearchParams(params).toString();
  const data = await fetchJson('/api/ideas' + (q ? '?' + q : ''));
  _ideas = Array.isArray(data) ? data : (data?.ideas || []);
  return _ideas;
}

async function _fetchProjects() {
  if (_projects.length) return _projects;
  const data = await fetchJson('/api/projects');
  _projects = Array.isArray(data) ? data : (data?.projects || []);
  return _projects;
}

function _priorityLabel(p) {
  return { P0: '🔴 P0', P1: '🟠 P1', P2: '🟡 P2', P3: '⚪ P3' }[p] || p || '';
}

function _statusBadge(s) {
  const colors = { active: 'var(--cyan)', promoted: 'var(--green)', archived: 'var(--text-dim)' };
  const c = colors[s] || 'var(--text-dim)';
  return `<span style="border:1px solid ${c};color:${c};padding:1px 6px;border-radius:10px;font-size:11px">${esc(s || 'active')}</span>`;
}

function _ideaCard(idea) {
  const tags = (idea.tags || []).map(t => `<span style="background:var(--bg);border:1px solid var(--border);border-radius:10px;padding:1px 6px;font-size:11px">${esc(t)}</span>`).join(' ');
  return `<div class="idea-card" style="background:var(--bg-card);border:1px solid var(--border);border-radius:8px;padding:12px;margin-bottom:8px;cursor:pointer" data-id="${idea.id}">
    <div style="display:flex;justify-content:space-between;align-items:flex-start;gap:8px">
      <strong style="flex:1">${esc(idea.title)}</strong>
      <span>${_priorityLabel(idea.priority)}</span>
      ${_statusBadge(idea.status)}
    </div>
    ${idea.description ? `<div style="color:var(--text-dim);font-size:13px;margin-top:4px">${esc(idea.description.slice(0, 120))}${idea.description.length > 120 ? '…' : ''}</div>` : ''}
    <div style="margin-top:6px;display:flex;gap:6px;flex-wrap:wrap">${tags}</div>
    <div style="margin-top:8px;display:flex;gap:8px">
      <button class="btn-secondary" style="font-size:12px" onclick="event.stopPropagation();openIdeaModal(${idea.id})">Edit</button>
      <button class="btn-secondary" style="font-size:12px" onclick="event.stopPropagation();openNoteModal(${idea.id})">Notes</button>
      <button class="btn-secondary" style="font-size:12px;color:var(--red)" onclick="event.stopPropagation();deleteIdea(${idea.id})">Delete</button>
    </div>
  </div>`;
}

function renderIdeaJarTab() {
  const el = $('#ideajar-content') || $('#ideas-section') || $('#section-ideas');
  if (!el) return;
  el.innerHTML = `
    <div style="display:flex;gap:8px;margin-bottom:12px;flex-wrap:wrap;align-items:center">
      <input id="idea-search" placeholder="Search…" style="flex:1;min-width:140px;padding:6px 10px;background:var(--bg-card);border:1px solid var(--border);border-radius:6px;color:var(--text)">
      <select id="idea-filter-status" style="padding:6px;background:var(--bg-card);border:1px solid var(--border);border-radius:6px;color:var(--text)">
        <option value="">All statuses</option>
        <option value="active">Active</option>
        <option value="promoted">Promoted</option>
        <option value="archived">Archived</option>
      </select>
      <select id="idea-filter-priority" style="padding:6px;background:var(--bg-card);border:1px solid var(--border);border-radius:6px;color:var(--text)">
        <option value="">All priorities</option>
        <option value="P0">P0</option><option value="P1">P1</option><option value="P2">P2</option><option value="P3">P3</option>
      </select>
      <button class="btn-primary" onclick="openIdeaModal()">+ New Idea</button>
    </div>
    <div id="idea-list"></div>
    <div id="idea-jar-canvas"></div>`;
  el.querySelector('#idea-search').addEventListener('input', _debounceFilter);
  el.querySelector('#idea-filter-status').addEventListener('change', _debounceFilter);
  el.querySelector('#idea-filter-priority').addEventListener('change', _debounceFilter);
  fetchIdeas().then(ideas => {
    _renderIdeaList(ideas);
    if (window.JarCanvas) JarCanvas.initJarCanvas('idea-jar-canvas', ideas, { onSlipClick: id => openIdeaModal(id), compact: false });
  });
}

function _debounceFilter() {
  clearTimeout(_debounceFilter._t);
  _debounceFilter._t = setTimeout(() => {
    const q = { search: $('#idea-search')?.value, status: $('#idea-filter-status')?.value, priority: $('#idea-filter-priority')?.value };
    filterIdeas(q);
  }, 300);
}

function _renderIdeaList(ideas) {
  const el = $('#idea-list');
  if (!el) return;
  if (!ideas.length) { el.innerHTML = '<div style="color:var(--text-dim);padding:20px 0">No ideas yet — press Cmd/Ctrl+I to add one.</div>'; return; }
  el.innerHTML = ideas.map(_ideaCard).join('');
  el.querySelectorAll('.idea-card').forEach(card => card.addEventListener('click', () => openIdeaModal(+card.dataset.id)));
}

async function filterIdeas(params) {
  const cleaned = Object.fromEntries(Object.entries(params).filter(([, v]) => v));
  const ideas = await fetchIdeas(cleaned);
  _renderIdeaList(ideas);
}

async function openIdeaModal(id) {
  const projects = await _fetchProjects();
  let idea = {};
  if (id) {
    idea = await fetchJson(`/api/ideas/${id}`) || {};
  }
  const existing = document.getElementById('idea-modal-overlay');
  if (existing) existing.remove();
  const overlay = document.createElement('div');
  overlay.id = 'idea-modal-overlay';
  overlay.className = 'modal-overlay';
  const tagsVal = Array.isArray(idea.tags) ? idea.tags.join(', ') : (idea.tags || '');
  const projOpts = projects.map(p => `<option value="${p.id}"${idea.project_id == p.id ? ' selected' : ''}>${esc(p.name)}</option>`).join('');
  const priorities = ['P0','P1','P2','P3'].map(p => `<option${idea.priority === p ? ' selected' : ''}>${p}</option>`).join('');
  overlay.innerHTML = `<div style="background:var(--bg-card);border:1px solid var(--border);border-radius:10px;padding:24px;width:480px;max-width:95vw;max-height:90vh;overflow-y:auto">
    <h3 style="margin:0 0 16px">${id ? 'Edit Idea' : 'New Idea'}</h3>
    <form id="idea-form">
      <label style="display:block;margin-bottom:10px">Title *<input name="title" required value="${esc(idea.title||'')}" style="display:block;width:100%;margin-top:4px;padding:6px 10px;background:var(--bg);border:1px solid var(--border);border-radius:6px;color:var(--text);box-sizing:border-box"></label>
      <label style="display:block;margin-bottom:10px">Description<textarea name="description" rows="3" style="display:block;width:100%;margin-top:4px;padding:6px 10px;background:var(--bg);border:1px solid var(--border);border-radius:6px;color:var(--text);box-sizing:border-box">${esc(idea.description||'')}</textarea></label>
      <label style="display:block;margin-bottom:10px">Tags (comma separated)<input name="tags" value="${esc(tagsVal)}" style="display:block;width:100%;margin-top:4px;padding:6px 10px;background:var(--bg);border:1px solid var(--border);border-radius:6px;color:var(--text);box-sizing:border-box"></label>
      <div style="display:flex;gap:12px;margin-bottom:10px">
        <label style="flex:1">Priority<select name="priority" style="display:block;width:100%;margin-top:4px;padding:6px;background:var(--bg);border:1px solid var(--border);border-radius:6px;color:var(--text)">${priorities}</select></label>
        <label style="flex:1">Project<select name="project_id" style="display:block;width:100%;margin-top:4px;padding:6px;background:var(--bg);border:1px solid var(--border);border-radius:6px;color:var(--text)"><option value="">—</option>${projOpts}</select></label>
      </div>
      <label style="display:block;margin-bottom:10px">Links<textarea name="links" rows="2" placeholder="One URL per line" style="display:block;width:100%;margin-top:4px;padding:6px 10px;background:var(--bg);border:1px solid var(--border);border-radius:6px;color:var(--text);box-sizing:border-box">${esc(idea.links||'')}</textarea></label>
      <div style="display:flex;justify-content:space-between;align-items:center;margin-top:4px">
        <span>Status: ${_statusBadge(idea.status)}</span>
        <div style="display:flex;gap:8px">
          ${idea.status === 'ready' ? `<button type="button" style="color:var(--gold);border-color:var(--gold)" onclick="document.getElementById('idea-modal-overlay').remove();promoteIdea(${id})">📋 Promote to Plan</button>` : ''}
          <button type="button" onclick="document.getElementById('idea-modal-overlay').remove()">Cancel</button>
          <button type="submit" class="btn-primary">Save</button>
        </div>
      </div>
    </form></div>`;
  document.body.appendChild(overlay);
  overlay.addEventListener('click', e => { if (e.target === overlay) overlay.remove(); });
  overlay.querySelector('#idea-form').addEventListener('submit', async e => {
    e.preventDefault();
    const fd = new FormData(e.target);
    const body = Object.fromEntries(fd.entries());
    body.tags = body.tags ? body.tags.split(',').map(t => t.trim()).filter(Boolean) : [];
    await saveIdea(id, body);
    overlay.remove();
  });
}

async function promoteIdea(id) {
  const idea = _ideas.find(i => i.id === id) || await fetchJson(`/api/ideas/${id}`) || {};
  await fetch(`/api/ideas/${id}/promote`, { method: 'POST' });
  await navigator.clipboard.writeText(`# ${idea.title || ''}\n\n${idea.description || ''}\n\nProject: ${idea.project_id || ''}`);
  showToast('Idea Jar', 'Promoted! Content copied to clipboard', null, 'info');
  fetchIdeas().then(_renderIdeaList);
}
async function saveIdea(id, data) {
  const url = id ? `/api/ideas/${id}` : '/api/ideas';
  const method = id ? 'PUT' : 'POST';
  try {
    const res = await fetch(url, { method, headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(data) });
    const json = await res.json();
    if (json.error) { showToast('Error', json.error, document.body, 'error'); return; }
    showToast('Saved', 'Idea saved', document.body, 'success');
    fetchIdeas().then(_renderIdeaList);
  } catch (e) { showToast('Error', e.message, document.body, 'error'); }
}

async function deleteIdea(id) {
  if (!confirm('Delete this idea?')) return;
  await fetch(`/api/ideas/${id}`, { method: 'DELETE' });
  fetchIdeas().then(_renderIdeaList);
}

async function openNoteModal(ideaId) {
  const data = await fetchJson(`/api/ideas/${ideaId}/notes`) || [];
  const notes = Array.isArray(data) ? data : (data?.notes || []);
  const existing = document.getElementById('note-modal-overlay');
  if (existing) existing.remove();
  const overlay = document.createElement('div');
  overlay.id = 'note-modal-overlay';
  overlay.className = 'modal-overlay';
  const noteItems = notes.map(n => `<div style="padding:8px 0;border-bottom:1px solid var(--border)"><div style="font-size:12px;color:var(--text-dim)">${esc(n.created_at||'')}</div><div>${esc(n.content||'')}</div></div>`).join('') || '<div style="color:var(--text-dim)">No notes yet.</div>';
  overlay.innerHTML = `<div style="background:var(--bg-card);border:1px solid var(--border);border-radius:10px;padding:24px;width:420px;max-width:95vw;max-height:80vh;display:flex;flex-direction:column">
    <h3 style="margin:0 0 12px">Notes</h3>
    <div style="flex:1;overflow-y:auto;margin-bottom:12px">${noteItems}</div>
    <form id="note-form" style="display:flex;gap:8px">
      <textarea name="content" rows="2" placeholder="Add a note…" required style="flex:1;padding:6px 10px;background:var(--bg);border:1px solid var(--border);border-radius:6px;color:var(--text)"></textarea>
      <button type="submit" class="btn-primary" style="align-self:flex-end">Add</button>
    </form>
    <button type="button" style="margin-top:8px" onclick="document.getElementById('note-modal-overlay').remove()">Close</button>
  </div>`;
  document.body.appendChild(overlay);
  overlay.addEventListener('click', e => { if (e.target === overlay) overlay.remove(); });
  overlay.querySelector('#note-form').addEventListener('submit', async e => {
    e.preventDefault();
    const content = new FormData(e.target).get('content');
    await fetch(`/api/ideas/${ideaId}/notes`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ content }) });
    overlay.remove();
    openNoteModal(ideaId);
  });
}

function renderIdeaJarWidget() {
  const el = $('#ideajar-mini-jar') || $('#idea-jar-widget');
  if (!el) return;
  fetchIdeas({ status: 'active' }).then(ideas => {
    const cnt = document.getElementById('ideajar-count');
    if (cnt) cnt.textContent = ideas.length;
    el.innerHTML = `<div style="background:var(--bg-card);border:1px solid var(--border);border-radius:8px;padding:12px;cursor:pointer" onclick="switchTab('ideas')"><div style="color:var(--gold);font-size:22px;font-weight:700">${ideas.length}</div><div style="color:var(--text-dim);font-size:12px">Active Ideas</div></div>`;
    if (window.JarCanvas) JarCanvas.initJarCanvas('ideajar-mini-jar', ideas, { onSlipClick: id => openIdeaModal(id), compact: true });
  });
}

function _isInputFocused() { const el = document.activeElement; return el && (el.tagName === 'INPUT' || el.tagName === 'TEXTAREA' || el.isContentEditable); }

document.addEventListener('keydown', e => {
  if ((e.metaKey || e.ctrlKey) && e.key === 'i' && !_isInputFocused()) {
    e.preventDefault();
    const overlay = document.createElement('div');
    overlay.id = 'idea-quick-overlay';
    overlay.className = 'modal-overlay';
    overlay.innerHTML = `<div style="background:var(--bg-card);border:1px solid var(--border);border-radius:10px;padding:24px;width:400px;max-width:95vw">
      <h3 style="margin:0 0 16px">Quick Idea</h3>
      <form id="idea-quick-form">
        <input name="title" required placeholder="Title *" autofocus style="display:block;width:100%;margin-bottom:10px;padding:6px 10px;background:var(--bg);border:1px solid var(--border);border-radius:6px;color:var(--text);box-sizing:border-box">
        <textarea name="description" rows="3" placeholder="Description" style="display:block;width:100%;margin-bottom:12px;padding:6px 10px;background:var(--bg);border:1px solid var(--border);border-radius:6px;color:var(--text);box-sizing:border-box"></textarea>
        <div style="display:flex;justify-content:flex-end;gap:8px">
          <button type="button" onclick="document.getElementById('idea-quick-overlay').remove()">Cancel</button>
          <button type="submit" class="btn-primary">Save</button>
        </div>
      </form></div>`;
    const prev = document.getElementById('idea-quick-overlay');
    if (prev) prev.remove();
    document.body.appendChild(overlay);
    overlay.addEventListener('click', ev => { if (ev.target === overlay) overlay.remove(); });
    overlay.querySelector('#idea-quick-form').addEventListener('submit', async ev => {
      ev.preventDefault();
      const fd = new FormData(ev.target);
      await saveIdea(null, { title: fd.get('title'), description: fd.get('description') });
      overlay.remove();
    });
    setTimeout(() => overlay.querySelector('input[name=title]')?.focus(), 50);
  }
});

window.fetchIdeas = fetchIdeas;
window.renderIdeaJarTab = renderIdeaJarTab;
window.renderIdeaJarWidget = renderIdeaJarWidget;
window.openIdeaModal = openIdeaModal;
window.openNoteModal = openNoteModal;
window.deleteIdea = deleteIdea;
window.filterIdeas = filterIdeas;
window.saveIdea = saveIdea;
window.promoteIdea = promoteIdea;
