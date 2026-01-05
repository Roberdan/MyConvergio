// Dashboard State Management
// Global state variables
export let data = null;
export let mainChart = null;
export let sparkCharts = [];
export let registry = null;
export let currentProjectId = null;
export let drilldownState = { level: 'plan', waveId: null, taskId: null };

// State setters
export function setData(newData) { data = newData; }
export function setMainChart(chart) { mainChart = chart; }
export function setSparkCharts(charts) { sparkCharts = charts; }
export function setRegistry(reg) { registry = reg; }
export function setCurrentProjectId(id) { currentProjectId = id; }
export function setDrilldownState(state) { drilldownState = state; }

// Theme colors for ApexCharts
export const themeColors = {
  voltrex: { line: '#f7931a', accent: '#22c55e', grid: 'rgba(139, 92, 246, 0.08)', text: '#6b7280' },
  midnight: { line: '#2dd4bf', accent: '#38bdf8', grid: 'rgba(56, 189, 248, 0.08)', text: '#64748b' },
  frost: { line: '#3b82f6', accent: '#059669', grid: 'rgba(71, 85, 105, 0.1)', text: '#64748b' },
  dawn: { line: '#f59e0b', accent: '#16a34a', grid: 'rgba(180, 83, 9, 0.08)', text: '#78716c' }
};

// Theme management
export function initTheme() {
  const saved = localStorage.getItem('dashboard-theme') || 'voltrex';
  document.documentElement.setAttribute('data-theme', saved);
  const themeSelect = document.getElementById('themeSelect');
  if (themeSelect) themeSelect.value = saved;
}

export function setTheme(theme, renderCallback, destroyCallback) {
  document.documentElement.setAttribute('data-theme', theme);
  localStorage.setItem('dashboard-theme', theme);
  if (data && destroyCallback && renderCallback) {
    destroyCallback();
    renderCallback();
  }
}

export function getCurrentTheme() {
  return localStorage.getItem('dashboard-theme') || 'voltrex';
}

// API base URL
export const API_BASE = '/api';
