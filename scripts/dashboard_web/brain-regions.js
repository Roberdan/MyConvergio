/* brain-regions.js — Brain anatomy layout: maps AI components to brain regions */
'use strict';

const BrainRegions = {
  prefrontal: {
    name: 'Prefrontal Cortex', shortName: 'Planning',
    center: { x: 0.5, y: 0.15 }, radius: 0.12,
    color: { h: 210, s: 80, l: 50 },
    systems: ['planner', 'strategic-planner', 'prompt'],
    triggers: ['plan_created', 'plan_started', 'wave_planned'],
    description: 'Decision making, planning, strategy',
  },
  motor: {
    name: 'Motor Cortex', shortName: 'Execution',
    center: { x: 0.5, y: 0.3 }, radius: 0.14,
    color: { h: 45, s: 100, l: 55 },
    systems: ['executor', 'task-executor', 'copilot-worker', 'agents'],
    triggers: ['task_started', 'agent_running', 'task_in_progress'],
    description: 'Task execution, code generation, active work',
  },
  parietalLeft: {
    name: 'Left Parietal', shortName: 'Analysis',
    center: { x: 0.25, y: 0.35 }, radius: 0.09,
    color: { h: 220, s: 65, l: 48 },
    systems: ['code-review', 'debugging', 'explore', 'research'],
    triggers: ['review_started', 'debug_session', 'exploration'],
    description: 'Code analysis, debugging, research',
  },
  parietalRight: {
    name: 'Right Parietal', shortName: 'Generation',
    center: { x: 0.75, y: 0.35 }, radius: 0.09,
    color: { h: 320, s: 65, l: 48 },
    systems: ['code-gen', 'refactor', 'create', 'design'],
    triggers: ['file_created', 'code_written', 'refactored'],
    description: 'Code generation, creation, design',
  },
  corpusCallosum: {
    name: 'Corpus Callosum', shortName: 'Comms',
    center: { x: 0.5, y: 0.4 }, radius: 0.05,
    shape: 'band', bandWidth: 0.6,
    color: { h: 180, s: 60, l: 45 },
    systems: ['sse', 'webhook', 'api', 'mesh-sync-config'],
    triggers: ['sse_event', 'api_call', 'sync_triggered'],
    description: 'Inter-region communication, data flow',
  },
  amygdala: {
    name: 'Amygdala', shortName: 'Security',
    center: { x: 0.35, y: 0.45 }, radius: 0.06,
    color: { h: 0, s: 85, l: 50 },
    systems: ['thor', 'guardian', 'security-audit', 'validate'],
    triggers: ['thor_validation', 'security_check', 'gate_failed', 'task_rejected'],
    description: 'Threat detection, quality gates, validation',
  },
  hippocampus: {
    name: 'Hippocampus', shortName: 'Memory',
    center: { x: 0.5, y: 0.55 }, radius: 0.08,
    color: { h: 280, s: 70, l: 50 },
    systems: ['agent-memory', 'knowledge-base', 'session-store', 'kb-write', 'kb-search'],
    triggers: ['memory_written', 'kb_entry', 'skill_earned', 'checkpoint_saved'],
    description: 'Memory formation, learning, knowledge retention',
  },
  visualCortex: {
    name: 'Visual Cortex', shortName: 'Dashboard',
    center: { x: 0.5, y: 0.7 }, radius: 0.09,
    color: { h: 50, s: 90, l: 55 },
    systems: ['dashboard', 'server.py', 'sse-stream', 'websocket'],
    triggers: ['page_load', 'widget_refresh', 'sse_connect'],
    description: 'Visualization, monitoring, observation',
  },
  cerebellum: {
    name: 'Cerebellum', shortName: 'Coordination',
    center: { x: 0.5, y: 0.85 }, radius: 0.11,
    color: { h: 160, s: 70, l: 45 },
    systems: ['mesh-coordinator', 'mesh-sync', 'mesh-dispatch', 'autosync'],
    triggers: ['peer_sync', 'task_dispatched', 'node_online', 'node_offline'],
    description: 'Mesh coordination, load balancing, synchronization',
  },
  brainstem: {
    name: 'Brainstem', shortName: 'Autonomic',
    center: { x: 0.5, y: 0.95 }, radius: 0.06,
    color: { h: 30, s: 60, l: 40 },
    systems: ['heartbeat', 'dashboard-db', 'cron', 'plan-db'],
    triggers: ['heartbeat_write', 'db_query', 'daemon_pulse'],
    description: 'Heartbeat, database, background processes',
  },
};

const BrainOutline = {
  path: [
    { type: 'move', x: 0.5, y: 0.02 },
    { type: 'curve', cx1: 0.15, cy1: 0.0, cx2: 0.05, cy2: 0.2, x: 0.08, y: 0.35 },
    { type: 'curve', cx1: 0.04, cy1: 0.45, cx2: 0.06, cy2: 0.6, x: 0.12, y: 0.7 },
    { type: 'curve', cx1: 0.18, cy1: 0.85, cx2: 0.35, cy2: 0.95, x: 0.5, y: 0.98 },
    { type: 'curve', cx1: 0.65, cy1: 0.95, cx2: 0.82, cy2: 0.85, x: 0.88, y: 0.7 },
    { type: 'curve', cx1: 0.94, cy1: 0.6, cx2: 0.96, cy2: 0.45, x: 0.92, y: 0.35 },
    { type: 'curve', cx1: 0.95, cy1: 0.2, cx2: 0.85, cy2: 0.0, x: 0.5, y: 0.02 },
  ],
  fissure: [{ x: 0.5, y: 0.05 }, { x: 0.5, y: 0.75 }],
  lateralSulcus: [{ x: 0.15, y: 0.45 }, { x: 0.45, y: 0.4 }],
};

// Reverse lookup: system name → region key (built once)
const _systemToRegion = {};
Object.entries(BrainRegions).forEach(([key, def]) => {
  def.systems.forEach(s => { _systemToRegion[s] = key; });
});

function systemToRegion(systemName) {
  return _systemToRegion[systemName] || null;
}

// ── RegionActivity ──────────────────────────────────────────────
class RegionActivity {
  constructor() {
    this.regions = {};
    Object.keys(BrainRegions).forEach(key => {
      this.regions[key] = {
        activity: 0, targetActivity: 0, lastActive: 0,
        neuronCount: 0, pulsePhase: Math.random() * Math.PI * 2,
      };
    });
  }

  mapTaskToRegion(task) {
    const sub = task.substatus || '';
    if (sub === 'waiting_thor') return 'amygdala';
    if (sub === 'waiting_ci') return 'brainstem';
    if (sub === 'waiting_review') return 'parietalLeft';
    if (sub === 'agent_running') return 'motor';

    const t = (task.title || '').toLowerCase();
    if (/plan|strateg|design|architect/.test(t)) return 'prefrontal';
    if (/test|validat|thor|review|audit|secur/.test(t)) return 'amygdala';
    if (/sync|mesh|coord|dispatch|balance/.test(t)) return 'cerebellum';
    if (/memory|kb|learn|checkpoint/.test(t)) return 'hippocampus';
    if (/dashboard|visual|chart|render/.test(t)) return 'visualCortex';
    if (/debug|analyz|explor|research/.test(t)) return 'parietalLeft';
    if (/create|generat|refactor|build|implement/.test(t)) return 'parietalRight';
    return 'motor';
  }

  updateFromTasks(tasks) {
    Object.values(this.regions).forEach(r => { r.targetActivity = 0; r.neuronCount = 0; });

    tasks.forEach(t => {
      if (t.status !== 'in_progress' && t.status !== 'pending') return;
      const region = this.mapTaskToRegion(t);
      if (!this.regions[region]) return;
      const boost = t.status === 'in_progress' ? 0.3 : 0.05;
      this.regions[region].targetActivity = Math.min(1, this.regions[region].targetActivity + boost);
      if (t.status === 'in_progress') {
        this.regions[region].neuronCount++;
        this.regions[region].lastActive = Date.now();
      }
    });

    this.regions.brainstem.targetActivity = Math.max(0.15, this.regions.brainstem.targetActivity);
    this.regions.visualCortex.targetActivity = Math.max(0.2, this.regions.visualCortex.targetActivity);
  }

  activateRegion(regionKey, intensity) {
    if (!this.regions[regionKey]) return;
    this.regions[regionKey].targetActivity = Math.min(1, intensity);
    this.regions[regionKey].lastActive = Date.now();
  }

  tick(dt) {
    const smoothing = 1 - Math.exp(-dt * 0.003);
    Object.values(this.regions).forEach(r => {
      r.activity += (r.targetActivity - r.activity) * smoothing;
      r.pulsePhase += dt * 0.002 * (1 + r.activity * 2);
    });
  }
}

// ── Rendering helpers ───────────────────────────────────────────
function getRegionRenderData(regionKey, regionActivity, canvasWidth, canvasHeight) {
  const def = BrainRegions[regionKey];
  if (!def) return null;
  const act = regionActivity.regions[regionKey];
  const pulse = 0.5 + 0.5 * Math.sin(act.pulsePhase);
  const minDim = Math.min(canvasWidth, canvasHeight);

  return {
    x: def.center.x * canvasWidth,
    y: def.center.y * canvasHeight,
    radius: def.radius * minDim * (0.8 + 0.2 * pulse * act.activity),
    alpha: 0.05 + act.activity * 0.6,
    glowRadius: def.radius * minDim * (1 + act.activity * 0.5),
    glowAlpha: act.activity * 0.3 * pulse,
    color: def.color,
    label: act.activity > 0.1 ? def.shortName : '',
    neuronCount: act.neuronCount,
    shape: def.shape || 'circle',
    bandWidth: def.bandWidth || 0,
  };
}

function getAllRenderData(regionActivity, canvasWidth, canvasHeight) {
  return Object.keys(BrainRegions).map(key =>
    ({ key, ...getRegionRenderData(key, regionActivity, canvasWidth, canvasHeight) })
  ).filter(Boolean);
}

// ── Connections between regions (neural pathways) ───────────────
const BrainConnections = [
  { from: 'prefrontal', to: 'motor', weight: 0.9 },
  { from: 'motor', to: 'cerebellum', weight: 0.7 },
  { from: 'hippocampus', to: 'prefrontal', weight: 0.6 },
  { from: 'amygdala', to: 'prefrontal', weight: 0.8 },
  { from: 'corpusCallosum', to: 'parietalLeft', weight: 0.5 },
  { from: 'corpusCallosum', to: 'parietalRight', weight: 0.5 },
  { from: 'visualCortex', to: 'parietalLeft', weight: 0.4 },
  { from: 'brainstem', to: 'cerebellum', weight: 0.6 },
  { from: 'hippocampus', to: 'amygdala', weight: 0.5 },
  { from: 'motor', to: 'parietalLeft', weight: 0.4 },
  { from: 'motor', to: 'parietalRight', weight: 0.4 },
  { from: 'prefrontal', to: 'parietalLeft', weight: 0.3 },
];

// ── Exports ─────────────────────────────────────────────────────
window.BrainRegions = BrainRegions;
window.BrainOutline = BrainOutline;
window.BrainConnections = BrainConnections;
window.RegionActivity = RegionActivity;
window.getRegionRenderData = getRegionRenderData;
window.getAllRenderData = getAllRenderData;
window.systemToRegion = systemToRegion;
