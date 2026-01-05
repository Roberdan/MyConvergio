// Dashboard State and Configuration
// Global state variables

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

// Theme colors for ApexCharts
const themeColors = {
  voltrex: { line: '#f7931a', accent: '#22c55e', grid: 'rgba(139, 92, 246, 0.08)', text: '#6b7280' },
  midnight: { line: '#2dd4bf', accent: '#38bdf8', grid: 'rgba(56, 189, 248, 0.08)', text: '#64748b' },
  frost: { line: '#3b82f6', accent: '#059669', grid: 'rgba(71, 85, 105, 0.1)', text: '#64748b' },
  dawn: { line: '#f59e0b', accent: '#16a34a', grid: 'rgba(180, 83, 9, 0.08)', text: '#78716c' }
};
