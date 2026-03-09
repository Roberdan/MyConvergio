/* idea-jar.js v5 — Idea Jar CRUD with inline dark-theme styles */
let _ideas = [];
let _projects = [];
const _I = 'background:var(--bg-deep,#04060e);border:1px solid var(--border,#1a2040);border-radius:4px;color:var(--text,#c8d0e8);font:12px/1.5 "JetBrains Mono",monospace;padding:6px 10px;box-sizing:border-box;outline:none;width:100%;display:block;margin-top:4px';
const _L = 'font-size:10px;letter-spacing:1px;text-transform:uppercase;color:var(--text-dim,#5a6080)';

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
function _parseTags(t) { return typeof t === 'string' ? t.split(',').map(s=>s.trim()).filter(Boolean) : Array.isArray(t) ? t : []; }

function _statusDot(s) {
  const c = {active:'var(--cyan)',draft:'var(--text-dim)',promoted:'var(--green)',archived:'var(--text-dim)',ready:'var(--gold)'}[s] || 'var(--text-dim)';
  return `<span class="badge" style="background:${c}22;color:${c}">${esc(s||'draft')}</span>`;
}

function _ideaCard(idea) {
  const tags = _parseTags(idea.tags).map(t => `<span class="badge" style="background:rgba(90,96,128,0.15);color:var(--text-dim)">${esc(t)}</span>`).join('');
  const priC = {P0:'var(--red)',P1:'var(--gold)',P2:'var(--cyan)',P3:'var(--text-dim)'}[idea.priority] || 'var(--text-dim)';
  return `<div class="mission-plan idea-item" onclick="openIdeaModal(${idea.id})" style="border-left:3px solid ${priC}">
    <div style="display:flex;align-items:center;gap:8px">
      <span style="font-weight:600;color:#e0e4f0;font-size:13px;flex:1">${esc(idea.title)}</span>
      ${idea.priority ? `<span class="badge" style="background:${priC}22;color:${priC}">${idea.priority}</span>` : ''}
      ${_statusDot(idea.status)}
      <span class="idea-hover-actions" onclick="event.stopPropagation()">
        <button class="widget-action-btn" onclick="openIdeaModal(${idea.id})" title="Edit"><svg width="11" height="11" viewBox="0 0 24 24"><path d="M11 4H4a2 2 0 00-2 2v14a2 2 0 002 2h14a2 2 0 002-2v-7"/><path d="M18.5 2.5a2.12 2.12 0 013 3L12 15l-4 1 1-4 9.5-9.5z"/></svg></button>
        <button class="widget-action-btn" onclick="openNoteModal(${idea.id})" title="Notes"><svg width="11" height="11" viewBox="0 0 24 24"><path d="M14 2H6a2 2 0 00-2 2v16a2 2 0 002 2h12a2 2 0 002-2V8z"/><path d="M14 2v6h6M16 13H8M16 17H8M10 9H8"/></svg></button>
        <button class="widget-action-btn" style="color:var(--red);border-color:rgba(255,51,85,0.2)" onclick="deleteIdea(${idea.id})" title="Delete"><svg width="11" height="11" viewBox="0 0 24 24"><path d="M3 6h18M19 6v14a2 2 0 01-2 2H7a2 2 0 01-2-2V6m3 0V4a2 2 0 012-2h4a2 2 0 012 2v2"/></svg></button>
      </span>
    </div>
    ${idea.description ? `<div style="color:var(--text-dim);font-size:12px;margin-top:3px">${esc(idea.description.slice(0,120))}${idea.description.length>120?'…':''}</div>` : ''}
    ${tags ? `<div style="display:flex;gap:4px;flex-wrap:wrap;margin-top:4px">${tags}</div>` : ''}
  </div>`;
}

function renderIdeaJarTab() {
  const ha = document.getElementById('ideajar-header-actions');
  if (ha) {
    ha.innerHTML = `
      <input id="idea-search" type="search" placeholder="Search…" style="padding:3px 8px;${_I};width:160px">
      <select id="idea-filter-status" style="padding:3px 6px;${_I};width:auto">
        <option value="">All statuses</option><option value="active">Active</option><option value="draft">Draft</option>
        <option value="ready">Ready</option><option value="promoted">Promoted</option><option value="archived">Archived</option>
      </select>
      <select id="idea-filter-priority" style="padding:3px 6px;${_I};width:auto">
        <option value="">All priorities</option><option value="P0">P0</option><option value="P1">P1</option><option value="P2">P2</option><option value="P3">P3</option>
      </select>
      <button class="widget-action-btn" onclick="openIdeaModal()"><svg width="10" height="10" viewBox="0 0 24 24"><line x1="12" y1="5" x2="12" y2="19"/><line x1="5" y1="12" x2="19" y2="12"/></svg> New Idea</button>`;
    ha.querySelector('#idea-search').addEventListener('input', _debounceFilter);
    ha.querySelector('#idea-filter-status').addEventListener('change', _debounceFilter);
    ha.querySelector('#idea-filter-priority').addEventListener('change', _debounceFilter);
  }
  const el = document.getElementById('ideajar-content');
  if (!el) return;
  el.innerHTML = '<div id="idea-list" style="padding:12px 16px"></div>';
  fetchIdeas().then(_renderIdeaList);
}

function _debounceFilter() {
  clearTimeout(_debounceFilter._t);
  _debounceFilter._t = setTimeout(() => {
    filterIdeas({ search: $('#idea-search')?.value, status: $('#idea-filter-status')?.value, priority: $('#idea-filter-priority')?.value });
  }, 300);
}
function _renderIdeaList(ideas) {
  const el = $('#idea-list');
  if (!el) return;
  if (!ideas.length) { el.innerHTML = '<div style="color:var(--text-dim);padding:12px 0;font-size:12px">No ideas yet — press ⌘I to add one.</div>'; return; }
  el.innerHTML = ideas.map(_ideaCard).join('');
}
async function filterIdeas(params) {
  const cleaned = Object.fromEntries(Object.entries(params).filter(([,v]) => v));
  _renderIdeaList(await fetchIdeas(cleaned));
}

async function openIdeaModal(id) {
  const projects = await _fetchProjects();
  let idea = {}; if (id) idea = await fetchJson(`/api/ideas/${id}`) || {};
  const existing = document.getElementById('idea-modal-overlay');
  if (existing) existing.remove();
  const overlay = document.createElement('div');
  overlay.id = 'idea-modal-overlay';
  overlay.className = 'modal-overlay';
  const tagsVal = _parseTags(idea.tags).join(', ');
  const projOpts = projects.map(p => `<option value="${p.id}"${idea.project_id==p.id?' selected':''}>${esc(p.name)}</option>`).join('');
  const pris = ['P0','P1','P2','P3'].map(p => `<option${idea.priority===p?' selected':''}>${p}</option>`).join('');
  const _f = (lbl, html) => `<label style="display:block"><span style="${_L}">${lbl}</span>${html}</label>`;
  overlay.innerHTML = `<div class="widget" style="width:500px;max-width:95vw;max-height:90vh;overflow-y:auto;box-shadow:0 0 60px rgba(0,229,255,0.1)">
    <div class="widget-header"><span class="widget-title">${id?'Edit Idea':'New Idea'}</span><span style="cursor:pointer;color:var(--red);font-size:16px" onclick="document.getElementById('idea-modal-overlay').remove()">✕</span></div>
    <div class="widget-body">
    <form id="idea-form" style="display:flex;flex-direction:column;gap:10px">
      ${_f('Title *',`<input name="title" required value="${esc(idea.title||'')}" style="${_I}">`)}
      ${_f('Description',`<textarea name="description" rows="3" style="${_I}">${esc(idea.description||'')}</textarea>`)}
      ${_f('Tags (comma separated)',`<input name="tags" value="${esc(tagsVal)}" style="${_I}">`)}
      <div style="display:flex;gap:12px">
        ${_f('Priority',`<select name="priority" style="${_I};width:auto">${pris}</select>`)}
        ${_f('Project',`<select name="project_id" style="${_I};width:auto"><option value="">—</option>${projOpts}</select>`)}
      </div>
      ${_f('Links',`<textarea name="links" rows="2" placeholder="One URL per line" style="${_I}">${esc(idea.links||'')}</textarea>`)}
      <div style="display:flex;justify-content:space-between;align-items:center;padding-top:8px;border-top:1px solid var(--border)">
        <span>${_statusDot(idea.status)}</span>
        <div style="display:flex;gap:6px">
          ${idea.status==='ready'?`<button type="button" class="widget-action-btn" style="color:var(--gold);border-color:rgba(255,183,0,0.3)" onclick="document.getElementById('idea-modal-overlay').remove();promoteIdea(${id})">Promote</button>`:''}
          <button type="button" class="widget-action-btn" onclick="document.getElementById('idea-modal-overlay').remove()">Cancel</button>
          <button type="submit" class="widget-action-btn" style="background:rgba(0,229,255,0.15)">Save</button>
        </div>
      </div>
    </form></div></div>`;
  document.body.appendChild(overlay);
  overlay.addEventListener('click', e => { if (e.target===overlay) overlay.remove(); });
  overlay.querySelector('#idea-form').addEventListener('submit', async e => {
    e.preventDefault();
    const fd = new FormData(e.target), body = Object.fromEntries(fd.entries());
    body.tags = body.tags ? body.tags.split(',').map(t=>t.trim()).filter(Boolean).join(',') : '';
    await saveIdea(id, body);
    overlay.remove();
  });
}

async function promoteIdea(id) {
  const idea = _ideas.find(i=>i.id===id) || await fetchJson(`/api/ideas/${id}`) || {};
  await fetch(`/api/ideas/${id}/promote`, { method:'POST' });
  await navigator.clipboard.writeText(`# ${idea.title||''}\n\n${idea.description||''}\n\nProject: ${idea.project_id||''}`);
  showToast('Idea Jar','Promoted! Content copied to clipboard',null,'info');
  fetchIdeas().then(_renderIdeaList);
}
async function saveIdea(id, data) {
  const url = id ? `/api/ideas/${id}` : '/api/ideas';
  try {
    const res = await fetch(url, { method: id?'PUT':'POST', headers:{'Content-Type':'application/json'}, body:JSON.stringify(data) });
    if (!res.ok) { const t = await res.text(); showToast('Error', t||`HTTP ${res.status}`, document.body,'error'); return; }
    const json = await res.json();
    if (json.error) { showToast('Error', json.error, document.body,'error'); return; }
    showToast('Saved','Idea saved',document.body,'success');
    fetchIdeas().then(_renderIdeaList);
  } catch(e) { showToast('Error',e.message,document.body,'error'); }
}
async function deleteIdea(id) {
  if (!confirm('Delete this idea?')) return;
  await fetch(`/api/ideas/${id}`, { method:'DELETE' });
  fetchIdeas().then(_renderIdeaList);
}
async function openNoteModal(ideaId) {
  const data = await fetchJson(`/api/ideas/${ideaId}/notes`) || [];
  const notes = Array.isArray(data) ? data : (data?.notes||[]);
  const existing = document.getElementById('note-modal-overlay');
  if (existing) existing.remove();
  const overlay = document.createElement('div');
  overlay.id = 'note-modal-overlay';
  overlay.className = 'modal-overlay';
  const items = notes.map(n=>`<div style="padding:6px 0;border-bottom:1px solid var(--border);font-size:12px"><span style="color:var(--text-dim);font-size:10px">${esc(n.created_at||'')}</span><div style="margin-top:2px">${esc(n.content||'')}</div></div>`).join('') || '<div style="color:var(--text-dim);font-size:12px">No notes yet.</div>';
  overlay.innerHTML = `<div class="widget" style="width:440px;max-width:95vw;max-height:80vh;display:flex;flex-direction:column;box-shadow:0 0 60px rgba(0,229,255,0.1)">
    <div class="widget-header"><span class="widget-title">Notes</span><span style="cursor:pointer;color:var(--red);font-size:16px" onclick="document.getElementById('note-modal-overlay').remove()">✕</span></div>
    <div class="widget-body" style="flex:1;overflow-y:auto">${items}</div>
    <form id="note-form" style="display:flex;gap:8px;padding:12px 16px;border-top:1px solid var(--border)">
      <textarea name="content" rows="2" placeholder="Add a note…" required style="${_I};flex:1"></textarea>
      <button type="submit" class="widget-action-btn" style="align-self:flex-end;background:rgba(0,229,255,0.15)">Add</button>
    </form></div>`;
  document.body.appendChild(overlay);
  overlay.addEventListener('click', e => { if (e.target===overlay) overlay.remove(); });
  overlay.querySelector('#note-form').addEventListener('submit', async e => {
    e.preventDefault();
    await fetch(`/api/ideas/${ideaId}/notes`, { method:'POST', headers:{'Content-Type':'application/json'}, body:JSON.stringify({content:new FormData(e.target).get('content')}) });
    overlay.remove();
    openNoteModal(ideaId);
  });
}

function renderIdeaJarWidget() {
  const el = $('#ideajar-mini-jar') || $('#idea-jar-widget');
  if (!el) return;
  fetchIdeas().then(allIdeas => {
    const ideas = allIdeas.filter(i => i.status !== 'archived');
    const cnt = document.getElementById('ideajar-count');
    if (cnt) cnt.textContent = ideas.length;
    const top = ideas.slice(0,3).map(i => {
      const priC = {P0:'var(--red)',P1:'var(--gold)',P2:'var(--cyan)',P3:'var(--text-dim)'}[i.priority]||'var(--text-dim)';
      return `<div class="mission-plan" style="border-left:3px solid ${priC};margin-bottom:6px;padding:8px 10px" onclick="showDashboardSection('dashboard-ideajar-section');setTimeout(()=>openIdeaModal(${i.id}),200)">
        <span style="font-weight:600;font-size:12px">${esc(i.title)}</span>
        ${_statusDot(i.status)}
        ${i.priority?`<span class="badge" style="background:${priC}22;color:${priC};margin-left:6px">${i.priority}</span>`:''}
      </div>`;
    }).join('');
    el.innerHTML = `<div style="cursor:pointer" onclick="showDashboardSection('dashboard-ideajar-section')">
      <div style="display:flex;align-items:baseline;gap:8px;margin-bottom:8px">
        <span style="color:var(--gold);font-family:var(--font-display);font-size:24px;font-weight:700">${ideas.length}</span>
        <span style="color:var(--text-dim);font-size:11px;letter-spacing:1px;text-transform:uppercase">ideas</span>
      </div>
      ${top||'<div style="color:var(--text-dim);font-size:12px">No ideas yet — press ⌘I</div>'}
    </div>`;
    if (window.JarCanvas) JarCanvas.initJarCanvas('ideajar-mini-jar', ideas, { onSlipClick:id=>openIdeaModal(id), compact:true });
  });
}

function _isInputFocused() { const el=document.activeElement; return el&&(el.tagName==='INPUT'||el.tagName==='TEXTAREA'||el.isContentEditable); }
document.addEventListener('keydown', e => { if ((e.metaKey||e.ctrlKey)&&e.key==='i'&&!_isInputFocused()) { e.preventDefault(); openIdeaModal(); } });

window.fetchIdeas=fetchIdeas; window.renderIdeaJarTab=renderIdeaJarTab; window.renderIdeaJarWidget=renderIdeaJarWidget;
window.openIdeaModal=openIdeaModal; window.openNoteModal=openNoteModal; window.deleteIdea=deleteIdea;
window.filterIdeas=filterIdeas; window.saveIdea=saveIdea; window.promoteIdea=promoteIdea;
