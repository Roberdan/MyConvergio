// Dashboard State and Configuration
// Global state variables with centralized state management

let data = null;
let mainChart = null;
let sparkCharts = [];
let registry = null;
let currentProjectId = null;
let currentPlanId = null;
let currentPlans = [];
let currentView = 'dashboard';
let drilldownState = { level: 'plan', waveId: null, taskId: null };
let chartMode = 'tokens';
let lastNotificationId = 0;
let notificationPollingInterval = null;
let dataRefreshInterval = null;
let notificationsFilter = 'unread';
let notificationsSearch = '';

// API base URL
const API_BASE = '/api';

// Update navigation state based on project selection
function updateNavState(hasProject) {
  const projectDependentItems = [
    { selector: '.nav-menu a[onclick*="dashboard"]', action: 'link' },
    { selector: '.nav-menu a[onclick*="tasks"]', action: 'link' },
    { selector: '#throughputBadge', action: 'element' },
    { selector: '#bugTrackerBtn', action: 'button' },
    { selector: '#exportBtn', action: 'button' }
  ];

  projectDependentItems.forEach(item => {
    const el = document.querySelector(item.selector);
    if (!el) return;
    
    if (hasProject) {
      el.classList.remove('disabled');
      el.removeAttribute('disabled');
      if (item.action === 'link') {
        el.style.pointerEvents = '';
      }
    } else {
      el.classList.add('disabled');
      el.setAttribute('disabled', 'true');
      if (item.action === 'link') {
        el.style.pointerEvents = 'none';
      }
    }
  });
}

// Theme colors for ApexCharts
const themeColors = {
  voltrex: { line: '#f7931a', accent: '#22c55e', grid: 'rgba(139, 92, 246, 0.08)', text: '#6b7280' },
  midnight: { line: '#2dd4bf', accent: '#38bdf8', grid: 'rgba(56, 189, 248, 0.08)', text: '#64748b' },
  frost: { line: '#3b82f6', accent: '#059669', grid: 'rgba(71, 85, 105, 0.1)', text: '#64748b' },
  dawn: { line: '#f59e0b', accent: '#16a34a', grid: 'rgba(180, 83, 9, 0.08)', text: '#78716c' }
};

// Centralized State Management
const DashboardState = {
  _state: {
    projectId: null,
    view: 'dashboard',
    gantt: {
      expandedWaves: new Set(),
      viewMode: 'timeline',
      filters: { showCompleted: true, showBlocked: true },
      navigation: { level: 'waves', waveId: null, taskId: null }
    },
    ui: { theme: 'dark', sidebarOpen: true }
  },

  _listeners: new Map(),

  get(key) {
    const keys = key.split('.');
    let value = this._state;
    for (const k of keys) {
      value = value?.[k];
    }
    return value;
  },

  set(key, value) {
    const keys = key.split('.');
    let obj = this._state;
    for (let i = 0; i < keys.length - 1; i++) {
      obj = obj[keys[i]];
    }
    obj[keys[keys.length - 1]] = value;
  },

  update(key, patch) {
    const current = this.get(key);
    if (current && typeof current === 'object') {
      this.set(key, { ...current, ...patch });
    }
  },

  subscribe(key, callback) {
    if (!this._listeners.has(key)) {
      this._listeners.set(key, new Set());
    }
    this._listeners.get(key).add(callback);
    return () => this._listeners.get(key)?.delete(callback);
  },

  reset() {
    this._state = {
      projectId: null, view: 'dashboard',
      gantt: {
        expandedWaves: new Set(),
        viewMode: 'timeline',
        filters: { showCompleted: true, showBlocked: true },
        navigation: { level: 'waves', waveId: null, taskId: null }
      },
      ui: { theme: 'dark', sidebarOpen: true }
    };
    this._listeners.clear();
  }
};

// Debounced render helper
function debouncedRender(delay = 150) {
  let timeout;
  return (fn) => {
    clearTimeout(timeout);
    timeout = setTimeout(fn, delay);
  };
}

// Throttled function helper
function throttledFn(limit = 100) {
  let lastCall = 0;
  return (fn) => {
    const now = Date.now();
    if (now - lastCall >= limit) {
      lastCall = now;
      fn();
    }
  };
}

window.DashboardState = DashboardState;
window.debouncedRender = debouncedRender;
window.throttledFn = throttledFn;
