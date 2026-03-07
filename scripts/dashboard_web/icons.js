/**
 * Centralized SVG icon library — monoline stroke style, Lucide/Feather aesthetic.
 * All icons: 24x24 viewBox, stroke="currentColor", stroke-width="2", no fill.
 */
const _ic = (size, d) =>
  `<svg width="${size}" height="${size}" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="vertical-align:-2px;display:inline-block">${d}</svg>`;

const Icons = {
  brain: (s = 14) => _ic(s, '<path d="M9.5 2a5.5 5.5 0 0 0-5 3.5A5 5 0 0 0 5 15c0 2.8 2.2 5 5 5h2"/><path d="M14.5 2a5.5 5.5 0 0 1 5 3.5A5 5 0 0 1 19 15c0 2.8-2.2 5-5 5h-2"/><path d="M12 2v20"/>'),
  clock: (s = 14) => _ic(s, '<circle cx="12" cy="12" r="10"/><path d="M12 6v6l4 2"/>'),
  eye: (s = 14) => _ic(s, '<path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z"/><circle cx="12" cy="12" r="3"/>'),
  gitMerge: (s = 14) => _ic(s, '<circle cx="18" cy="18" r="3"/><circle cx="6" cy="6" r="3"/><path d="M6 21V9a9 9 0 0 0 9 9"/>'),
  shield: (s = 14) => _ic(s, '<path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/><path d="M9 12l2 2 4-4"/>'),
  cpu: (s = 14) => _ic(s, '<rect x="4" y="4" width="16" height="16" rx="2"/><rect x="9" y="9" width="6" height="6"/><path d="M9 1v3M15 1v3M9 20v3M15 20v3M20 9h3M20 14h3M1 9h3M1 14h3"/>'),
  check: (s = 14) => _ic(s, '<path d="M20 6L9 17l-5-5"/>'),
  x: (s = 14) => _ic(s, '<path d="M18 6L6 18M6 6l12 12"/>'),
  checkCircle: (s = 14) => _ic(s, '<path d="M22 11.08V12a10 10 0 1 1-5.93-9.14"/><path d="M22 4L12 14.01l-3-3"/>'),
  xCircle: (s = 14) => _ic(s, '<circle cx="12" cy="12" r="10"/><path d="M15 9l-6 6M9 9l6 6"/>'),
  alertTriangle: (s = 14) => _ic(s, '<path d="M10.29 3.86L1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z"/><path d="M12 9v4M12 17h.01"/>'),
  search: (s = 14) => _ic(s, '<circle cx="11" cy="11" r="8"/><path d="M21 21l-4.35-4.35"/>'),
  zap: (s = 14) => _ic(s, '<polygon points="13 2 3 14 12 14 11 22 21 10 12 10 13 2"/>'),
  globe: (s = 14) => _ic(s, '<circle cx="12" cy="12" r="10"/><path d="M2 12h20"/><path d="M12 2a15.3 15.3 0 0 1 4 10 15.3 15.3 0 0 1-4 10 15.3 15.3 0 0 1-4-10 15.3 15.3 0 0 1 4-10z"/>'),
  monitor: (s = 14) => _ic(s, '<rect x="2" y="3" width="20" height="14" rx="2"/><path d="M8 21h8M12 17v4"/>'),
  waveComplete: (s = 14) => _ic(s, '<path d="M12 2l10 10-10 10L2 12z"/>'),
  dot: (s = 14) => _ic(s, '<circle cx="12" cy="12" r="4"/>'),
};

window.Icons = Icons;
