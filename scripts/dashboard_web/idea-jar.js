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

function _statusDot(s) {
  const colors = { active: 'var(--cyan)', draft: 'var(--text-dim)', promoted: 'var(--green)', archived: 'var(--text-dim)', ready: 'var(--gold)' };
  const c = colors[s] || 'var(--text-dim)';
  return `<span class="badge" style="background:${c}22;color:${c}">${esc(s || 'draft')}</span>`;
}

function _ideaCard(idea) {
  const tags = (idea.tags || []).map(t => `<span class="badge" style="background:rgba(90,96,128,0.15);color:var(--text-dim)">${esc(t)}</span>`).join('');
  const priColors = { P0: 'var(--red)', P1: 'var(--gold)', P2: 'var(--cyan)', P3: 'var(--text-dim)' };
  const priC = priColors[idea.priority] || 'var(--text-dim)';
  return `<div class="mission-plan" onclick="openIdeaModal(${idea.id})" style="border-left:3px solid ${priC}">
    <div style="margin-bottom:4px">
      <span style="font-weight:600;color:#e0e4f0;font-size:14px">${esc(idea.title)}</span>
      ${_statusDot(idea.status)}
      ${idea.priority ? `<span class="badge" style="background:${priC}22;color:${priC}">${idea.priority}</span>` : ''}
    </div>
    ${idea.description ? `<div class="mission-summary" style="margin:4px 0 6px">${esc(idea.description.slice(0, 160))}${idea.description.length > 160 ? '…' : ''}</div>` : ''}
    ${tags ? `<div style="display:flex;gap:4px;flex-wrap:wrap;margin-bottom:6px">${tags}</div>` : ''}
    <div style="display:flex;gap:6px" onclick="event.stopPropagation()">
      <button class="widget-action-btn" onclick="openIdeaModal(${idea.id})" title="Edit"><svg width="12" height="12" viewBox="0 0 24 24"><path d="M11 4H4a2 2 0 00-2 2v14a2 2 0 002 2h14a2 2 0 002-2v-7"/><path d="M18.5 2.5a2.12 2.12 0 013 3L12 15l-4 1 1-4 9.5-9.5z"/></svg> Edit</button>
      <button class="widget-action-btn" onclick="openNoteModal(${idea.id})" title="Notes"><svg width="12" height="12" viewBox="0 0 24 24"><path d="M14 2H6a2 2 0 00-2 2v16a2 2 0 002 2h12a2 2 0 002-2V8z"/><path d="M14 2v6h6M16 13H8M16 17H8M10 9H8"/></svg> Notes</button>
      ${idea.status === 'ready' ? `<button class="widget-action-btn" style="color:var(--gold);border-color:rgba(255,183,0,0.3)" onclick="promoteIdea(${idea.id})" title="Promote to plan"><svg width="12" height="12" viewBox="0 0 24 24"><path d="M22 2L11 13"/><path d="M22 2L15 22L11 13L2 9L22 2Z"/></svg> Promote</button>` : ''}
      <button class="widget-action-btn" style="color:var(--red);border-color:rgba(255,51,85,0.2)" onclick="deleteIdea(${idea.id})" title="Delete"><svg width="12" height="12" viewBox="0 0 24 24"><path d="M3 6h18M19 6v14a2 2 0 01-2 2H7a2 2 0 01-2-2V6m3 0V4a2 2 0 012-2h4a2 2 0 012 2v2"/></svg></button>
    </div>
  </div>`;
}

function renderIdeaJarTab() {
  const headerActions = document.getElementById('ideajar-header-actions');
  if (headerActions) {
    headerActions.innerHTML = `
      <input id="idea-search" type="search" placeholder="Search…" style="padding:3px 8px;background:var(--bg-card);border:1px solid var(--border);border-radius:4px;color:var(--text);font-family:inherit;font-size:11px;width:160px;outline:none">
      <select id="idea-filter-status" style="padding:3px 6px;background:var(--bg-card);border:1px solid var(--border);border-radius:4px;color:var(--text);font-family:inherit;font-size:11px">
        <option value="">All statuses</option>
        <option value="active">Active</option><option value="draft">Draft</option>
        <option value="ready">Ready</option><option value="promoted">Promoted</option>
        <option value="archived">Archived</option>
      </select>
      <select id="idea-filter-priority" style="padding:3px 6px;background:var(--bg-card);border:1px solid var(--border);border-radius:4px;color:var(--text);font-family:inherit;font-size:11px">
        <option value="">All priorities</option>
        <option value="P0">P0</option><option value="P1">P1</option><option value="P2">P2</option><option value="P3">P3</option>
      </select>
      <button class="widget-action-btn" onclick="openIdeaModal()"><svg width="10" height="10" viewBox="0 0 24 24"><line x1="12" y1="5" x2="12" y2="19"/><line x1="5" y1="12" x2="19" y2="12"/></svg> New Idea</button>`;
    headerActions.querySelector('#idea-search').addEventListener('input', _debounceFilter);
    headerActions.querySelector('#idea-filter-status').addEventListener('change', _debounceFilter);
    headerActions.querySelector('#idea-filter-priority').addEventListener('change', _debounceFilter);
  }

  const el = document.getElementById('ideajar-content');
  if (!el) return;
  el.innerHTML = '<div id="idea-list" style="padding:12px 16px"></div><div id="idea-jar-canvas" style="padding:0 16px 16px"></div>';

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
  if (!ideas.length) { el.innerHTML = '<div style="color:var(--text-dim);padding:12px 0;font-size:12px">No ideas yet — press <kbd style="background:var(--bg-card);border:1px solid var(--border);padding:1px 5px;border-radius:3px;font-size:10px">⌘I</kbd> to add one.</div>'; return; }
  el.innerHTML = ideas.map(_ideaCard).join('');
}

async function filterIdeas(params) {
  const cleaned = Object.fromEntries(Object.entries(params).filter(([, v]) => v));
  const ideas = await fetchIdeas(cleaned);
  _renderIdeaList(ideas);
}

async function openIdeaModal(id) {
  const projects = await _fetchProjects();
  let idea = {};
  if (id) idea = await fetchJson(`/api/ideas/${id}`) || {};
  const existing = document.getElementById('idea-modal-overlay');
  if (existing) existing.remove();
  const overlay = document.createElement('div');
  overlay.id = 'idea-modal-overlay';
  overlay.className = 'modal-overlay';
  const tagsVal = Array.isArray(idea.tags) ? idea.tags.join(', ') : (idea.tags || '');
  const projOpts = projects.map(p => `<option value="${p.id}"${idea.project_id == p.id ? ' selected' : ''}>${esc(p.name)}</option>`).join('');
  const priorities = ['P0','P1','P2','P3'].map(p => `<option${idea.priority === p ? ' selected' : ''}>${p}</option>`).join('');
  const _f = (label, content) => `<label class="modal-field"><span class="modal-field-label">${label}</span>${content}</label>`;
  overlay.innerHTML = `<div class="widget" style="width:500px;max-width:95vw;max-height:90vh;overflow-y:auto;box-shadow:0 0 60px rgba(0,229,255,0.1)">
    <div class="widget-header"><span class="widget-title">${id ? 'Edit Idea' : 'New Idea'}</span><span style="cursor:pointer;color:var(--red);font-size:16px" onclick="document.getElementById('idea-modal-overlay').remove()">✕</span></div>
    <div class="widget-body">
    <form id="idea-form" style="display:flex;flex-direction:column;gap:10px">
      ${_f('Title *', `<input name="title" required value="${esc(idea.title||'')}" class="modal-input">`)}
      ${_f('Description', `<textarea name="description" rows="3" class="modal-input">${esc(idea.description||'')}</textarea>`)}
      ${_f('Tags (comma separated)', `<input name="tags" value="${esc(tagsVal)}" class="modal-input">`)}
      <div style="display:flex;gap:12px">
        ${_f('Priority', `<select name="priority" class="modal-input">${priorities}</select>`)}
        ${_f('Project', `<select name="project_id" class="modal-input"><option value="">—</option>${projOpts}</select>`)}
      </div>
      ${_f('Links', `<textarea name="links" rows="2" placeholder="One URL per line" class="modal-input">${esc(idea.links||'')}</textarea>`)}
      <div style="display:flex;justify-content:space-between;align-items:center;padding-top:8px;border-top:1px solid var(--border)">
        <span>${_statusDot(idea.status)}</span>
        <div style="display:flex;gap:6px">
          ${idea.status === 'ready' ? `<button type="button" class="widget-action-btn" style="color:var(--gold);border-color:rgba(255,183,0,0.3)" onclick="document.getElementById('idea-modal-overlay').remove();promoteIdea(${id})">Promote</button>` : ''}
          <button type="button" class="widget-action-btn" onclick="document.getElementById('idea-modal-overlay').remove()">Cancel</button>
          <button type="submit" class="widget-action-btn" style="background:rgba(0,229,255,0.15)">Save</button>
        </div>
      </div>
    </form></div></div>`;
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
  const noteItems = notes.map(n => `<div style="padding:6px 0;border-bottom:1px solid var(--border);font-size:12px"><span style="color:var(--text-dim);font-size:10px">${esc(n.created_at||'')}</span><div style="margin-top:2px">${esc(n.content||'')}</div></div>`).join('') || '<div style="color:var(--text-dim);font-size:12px">No notes yet.</div>';
  overlay.innerHTML = `<div class="widget" style="width:440px;max-width:95vw;max-height:80vh;display:flex;flex-direction:column;box-shadow:0 0 60px rgba(0,229,255,0.1)">
    <div class="widget-header"><span class="widget-title">Notes</span><span style="cursor:pointer;color:var(--red);font-size:16px" onclick="document.getElementById('note-modal-overlay').remove()">✕</span></div>
    <div class="widget-body" style="flex:1;overflow-y:auto">${noteItems}</div>
    <form id="note-form" style="display:flex;gap:8px;padding:12px 16px;border-top:1px solid var(--border)">
      <textarea name="content" rows="2" placeholder="Add a note…" required class="modal-input" style="flex:1"></textarea>
      <button type="submit" class="widget-action-btn" style="align-self:flex-end;background:rgba(0,229,255,0.15)">Add</button>
    </form>
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
    const topIdeas = ideas.slice(0, 3).map(i => {
      const priC = { P0: 'var(--red)', P1: 'var(--gold)', P2: 'var(--cyan)', P3: 'var(--text-dim)' }[i.priority] || 'var(--text-dim)';
      return `<div class="mission-plan" style="border-left:3px solid ${priC};margin-bottom:6px;padding:8px 10px" onclick="showDashboardSection('dashboard-ideajar-section');setTimeout(()=>openIdeaModal(${i.id}),200)">
        <span style="font-weight:600;font-size:12px">${esc(i.title)}</span>
        ${i.priority ? `<span class="badge" style="background:${priC}22;color:${priC};margin-left:6px">${i.priority}</span>` : ''}
      </div>`;
    }).join('');
    el.innerHTML = `<div style="cursor:pointer" onclick="showDashboardSection('dashboard-ideajar-section')">
      <div style="display:flex;align-items:baseline;gap:8px;margin-bottom:8px">
        <span style="color:var(--gold);font-family:var(--font-display);font-size:24px;font-weight:700">${ideas.length}</span>
        <span style="color:var(--text-dim);font-size:11px;letter-spacing:1px;text-transform:uppercase">active ideas</span>
      </div>
      ${topIdeas || '<div style="color:var(--text-dim);font-size:12px">No ideas yet — press ⌘I</div>'}
    </div>`;
    if (window.JarCanvas) JarCanvas.initJarCanvas('ideajar-mini-jar', ideas, { onSlipClick: id => openIdeaModal(id), compact: true });
  });
}

function _isInputFocused() { const el = document.activeElement; return el && (el.tagName === 'INPUT' || el.tagName === 'TEXTAREA' || el.isContentEditable); }

document.addEventListener('keydown', e => {
  if ((e.metaKey || e.ctrlKey) && e.key === 'i' && !_isInputFocused()) {
    e.preventDefault();
    openIdeaModal();
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
