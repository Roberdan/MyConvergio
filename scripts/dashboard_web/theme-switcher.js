/**
 * Theme Switcher — web dashboard skin engine
 * Reads/writes theme to localStorage, renders dropdown, applies data-theme attribute.
 */

const THEMES = [
  { id: 'neon_grid', name: 'Neon Grid', sub: 'Cyberpunk', color: '#00e5ff' },
  { id: 'synthwave', name: 'Synthwave', sub: 'Retrowave', color: '#e040fb' },
  { id: 'ghost',     name: 'Ghost',     sub: 'GitS',      color: '#00e550' },
  { id: 'matrix',    name: 'Matrix',    sub: 'Digital Rain', color: '#00ff41' },
  { id: 'dark',      name: 'Dark',      sub: 'Minimal',   color: '#6495ed' },
  { id: 'light',     name: 'Light',     sub: 'Clean',     color: '#1a6baa' },
  { id: 'vintage',   name: 'Vintage',   sub: 'CRT Amber', color: '#d48e00' },
  { id: 'tron',      name: 'TRON',      sub: 'Legacy',    color: '#2196f3' },
  { id: 'fallout',   name: 'Fallout',   sub: 'Pip-Boy',   color: '#7ec850' },
  { id: 'convergio', name: 'Convergio', sub: 'Brand',     color: '#b07ee8' },
  { id: 'neumorph',  name: 'Neumorph',  sub: 'Soft UI',   color: '#7eb8ff' },
];

const STORAGE_KEY = 'dashboard-theme';

function getTheme() {
  return localStorage.getItem(STORAGE_KEY) || 'neon_grid';
}

function setTheme(id) {
  localStorage.setItem(STORAGE_KEY, id);
  applyTheme(id);
  renderDropdown();
}

function applyTheme(id) {
  if (id === 'neon_grid') {
    document.documentElement.removeAttribute('data-theme');
  } else {
    document.documentElement.setAttribute('data-theme', id);
  }
}

function renderDropdown() {
  const dd = document.getElementById('theme-dropdown');
  if (!dd) return;
  const current = getTheme();
  dd.innerHTML = THEMES.map(t =>
    `<div class="theme-option${t.id === current ? ' active' : ''}" onclick="setTheme('${t.id}')">
      <span class="theme-swatch" style="background:${t.color}"></span>
      <span>${t.name}</span>
      <span style="color:var(--text-dim);font-size:10px;margin-left:auto">${t.sub}</span>
    </div>`
  ).join('');
}

function toggleThemeDropdown() {
  const dd = document.getElementById('theme-dropdown');
  if (!dd) return;
  dd.classList.toggle('open');
}

// Close dropdown on outside click
document.addEventListener('click', (e) => {
  const dd = document.getElementById('theme-dropdown');
  const btn = document.getElementById('theme-toggle');
  if (dd && !dd.contains(e.target) && e.target !== btn) {
    dd.classList.remove('open');
  }
});

// Keyboard shortcut: T to cycle themes
document.addEventListener('keydown', (e) => {
  if (e.target.tagName === 'INPUT' || e.target.tagName === 'TEXTAREA') return;
  if (e.key === 't' || e.key === 'T') {
    const current = getTheme();
    const idx = THEMES.findIndex(t => t.id === current);
    const next = THEMES[(idx + 1) % THEMES.length];
    setTheme(next.id);
  }
});

// Init on load
applyTheme(getTheme());
renderDropdown();
