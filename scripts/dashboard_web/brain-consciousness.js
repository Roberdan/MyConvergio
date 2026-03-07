// brain-consciousness.js — Human as "consciousness" layer of the AI brain.
// Augmented Intelligence: human commands cascade as cortical impulses through brain regions.
'use strict';

class ConsciousnessStream {
  constructor(maxEvents = 200) {
    this.events = [];
    this.maxEvents = maxEvents;
    this.listeners = [];
  }
  push(type, data) {
    const event = { id: Date.now() + Math.random(), type, data: data || {}, timestamp: Date.now() };
    this.events.push(event);
    if (this.events.length > this.maxEvents) this.events.shift();
    this.listeners.forEach(fn => fn(event));
    return event;
  }
  onEvent(fn) { this.listeners.push(fn); }
  removeListener(fn) { this.listeners = this.listeners.filter(l => l !== fn); }
  recent(type, ms = 5000) {
    const cutoff = Date.now() - ms;
    return this.events.filter(e => e.type === type && e.timestamp > cutoff);
  }
  window(ms = 10000) {
    const cutoff = Date.now() - ms;
    return this.events.filter(e => e.timestamp > cutoff);
  }
  get length() { return this.events.length; }
}
ConsciousnessStream.TYPES = {
  HUMAN_COMMAND: 'human_command', HUMAN_DECISION: 'human_decision',
  HUMAN_OVERRIDE: 'human_override', AI_RESPONSE: 'ai_response',
  AGENT_SPAWN: 'agent_spawn', AGENT_COMPLETE: 'agent_complete',
  PLAN_CHANGE: 'plan_change', SYNAPSE_FIRE: 'synapse_fire',
  MEMORY_WRITE: 'memory_write', THOR_JUDGMENT: 'thor_judgment',
  SESSION_CHILD_SPAWN: 'session_child_spawn',
  SESSION_CHILD_COMPLETE: 'session_child_complete',
};

class CorticalImpulse {
  constructor(event, sourceRegion) {
    this.event = event;
    this.sourceRegion = sourceRegion || 'prefrontal';
    this.time = 0;
    this.radius = 0;
    this.intensity = 1.0;
    this.color = CorticalImpulse.colorForType(event.type);
    this.done = false;
  }
  static colorForType(type) {
    const map = {
      human_command:  { h: 45,  s: 100, l: 65 }, human_decision: { h: 30,  s: 100, l: 60 },
      human_override: { h: 0,   s: 100, l: 65 }, ai_response:    { h: 200, s: 80,  l: 55 },
      agent_spawn:    { h: 160, s: 80,  l: 50 }, agent_complete: { h: 140, s: 90,  l: 55 },
      plan_change:    { h: 280, s: 70,  l: 55 }, synapse_fire:   { h: 190, s: 70,  l: 50 },
      memory_write:   { h: 270, s: 75,  l: 55 }, thor_judgment:  { h: 30,  s: 90,  l: 50 },
      session_child_spawn:    { h: 180, s: 85, l: 55 },
      session_child_complete: { h: 120, s: 80, l: 50 },
    };
    return map[type] || { h: 200, s: 50, l: 50 };
  }
  update(dt) {
    this.time += dt;
    this.radius = Math.min(1, this.time / 1500);
    this.intensity = Math.max(0, 1 - this.time / 2000);
    if (this.time > 2500) this.done = true;
  }
  getActivatedRegions(brainRegions) {
    if (!brainRegions) return [];
    const src = (brainRegions[this.sourceRegion] && brainRegions[this.sourceRegion].center)
      || { x: 0.5, y: 0.15 };
    const activated = [];
    for (const [key, def] of Object.entries(brainRegions)) {
      if (!def || !def.center) continue;
      const dx = def.center.x - src.x, dy = def.center.y - src.y;
      const dist = Math.sqrt(dx * dx + dy * dy);
      if (this.radius >= dist) {
        const activation = Math.max(0, 1 - (this.radius - dist) * 1500 / 1000);
        if (activation > 0.01) activated.push({ region: key, activation });
      }
    }
    return activated;
  }
  toHSLA(alpha) {
    const c = this.color, a = alpha !== undefined ? alpha : this.intensity;
    return `hsla(${c.h},${c.s}%,${c.l}%,${a.toFixed(3)})`;
  }
}

class InteractionTimeline {
  constructor() {
    this.impulses = [];
    this.stream = new ConsciousnessStream();
    this.humanPresence = 0;
    this.aiActivity = 0;
    this._regions = typeof window.BrainRegions !== 'undefined' ? window.BrainRegions : null;
    this.stream.onEvent((event) => {
      const isHuman = event.type.startsWith('human_');
      const source = isHuman ? 'prefrontal' : this._eventToRegion(event.type);
      this.impulses.push(new CorticalImpulse(event, source));
      if (isHuman) this.humanPresence = 1.0;
    });
  }
  _eventToRegion(type) {
    const m = { agent_spawn: 'motor', agent_complete: 'motor', thor_judgment: 'amygdala',
      memory_write: 'hippocampus', plan_change: 'prefrontal', synapse_fire: 'corpusCallosum',
      ai_response: 'parietalLeft',
      session_child_spawn: 'motor', session_child_complete: 'motor' };
    return m[type] || 'corpusCallosum';
  }
  update(dt) {
    for (let i = this.impulses.length - 1; i >= 0; i--) {
      this.impulses[i].update(dt);
      if (this.impulses[i].done) this.impulses.splice(i, 1);
    }
    this.humanPresence *= Math.exp(-dt * 0.0001);
    if (this.humanPresence < 0.001) this.humanPresence = 0;
  }
  _resolveRegions() {
    if (!this._regions) this._regions = window.BrainRegions || null;
    return this._regions;
  }
  getRegionBoosts() {
    const regions = this._resolveRegions();
    const boosts = {};
    for (const imp of this.impulses) {
      for (const { region, activation } of imp.getActivatedRegions(regions)) {
        boosts[region] = Math.min(1, (boosts[region] || 0) + activation * imp.intensity * 0.5);
      }
    }
    return boosts;
  }
  getActiveImpulses() {
    const regions = this._resolveRegions();
    return this.impulses.map(imp => {
      const reg = regions && regions[imp.sourceRegion];
      const c = (reg && reg.center) || { x: 0.5, y: 0.15 };
      return { x: c.x, y: c.y, radius: imp.radius, intensity: imp.intensity,
        color: imp.color, hsla: imp.toHSLA(), type: imp.event.type,
        isHuman: imp.event.type.startsWith('human_') };
    });
  }
  getStats() {
    const recent = this.stream.window(30000);
    return { humanPresence: this.humanPresence, activeImpulses: this.impulses.length,
      eventsLast30s: recent.length, totalEvents: this.stream.length,
      humanEventsLast30s: recent.filter(e => e.type.startsWith('human_')).length,
      aiEventsLast30s: recent.filter(e => !e.type.startsWith('human_')).length };
  }
}

// --- Global instance + integration hooks ---
const _consciousness = new InteractionTimeline();
const _s = _consciousness.stream;

window.consciousnessTrackPlanChange = (planId, field, oldVal, newVal) =>
  _s.push('plan_change', { planId, field, oldVal, newVal });
window.consciousnessTrackAgentSpawn = (agentId, taskId, planId) =>
  _s.push('agent_spawn', { agentId, taskId, planId });
window.consciousnessTrackAgentComplete = (agentId, taskId, success) =>
  _s.push('agent_complete', { agentId, taskId, success });
window.consciousnessTrackHumanCommand = (command) =>
  _s.push('human_command', { command });
window.consciousnessTrackHumanDecision = (decision, context) =>
  _s.push('human_decision', { decision, context });
window.consciousnessTrackHumanOverride = (what, from, to) =>
  _s.push('human_override', { what, from, to });
window.consciousnessTrackThor = (taskId, passed) =>
  _s.push('thor_judgment', { taskId, passed });
window.consciousnessTrackMemory = (key, value) =>
  _s.push('memory_write', { key, value });
window.consciousnessTrackSessionChild = (sessionId, agentId, type) => {
  const evType = type === 'complete' ? 'session_child_complete' : 'session_child_spawn';
  _s.push(evType, { sessionId, agentId });
};

// SSE / DOM event auto-hooks
function hookIntoSSE() {
  document.addEventListener('dashboard:task-update', (e) => {
    const d = e.detail || {};
    if (d.status === 'in_progress') _s.push('agent_spawn', d);
    else if (d.status === 'done' || d.status === 'submitted') _s.push('agent_complete', d);
  });
  document.addEventListener('dashboard:plan-update', (e) =>
    _s.push('plan_change', e.detail || {}));
  document.addEventListener('dashboard:thor-result', (e) => {
    const d = e.detail || {};
    _s.push('thor_judgment', { taskId: d.taskId, passed: d.passed });
  });
  // Session cluster events from brain-sessions.js
  document.addEventListener('dashboard:session-child-spawn', (e) => {
    const d = e.detail || {};
    _s.push('session_child_spawn', { sessionId: d.sessionId, agentId: d.agentId });
  });
  document.addEventListener('dashboard:session-child-complete', (e) => {
    const d = e.detail || {};
    _s.push('session_child_complete', { sessionId: d.sessionId, agentId: d.agentId });
  });
}
if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', hookIntoSSE);
else hookIntoSSE();

// Session awareness: poll for active CLI sessions as consciousness nodes
(function pollSessions() {
  let _prev = [];
  setInterval(async () => {
    try {
      const res = await fetch('/api/sessions');
      const sessions = await res.json();
      sessions.forEach(s => {
        if (!_prev.find(p => p.agent_id === s.agent_id))
          _s.push('agent_spawn', { agentId: s.agent_id, type: s.type, description: s.description, isSession: true });
      });
      _prev.forEach(p => {
        if (!sessions.find(s => s.agent_id === p.agent_id))
          _s.push('agent_complete', { agentId: p.agent_id, type: p.type, isSession: true });
      });
      _prev = sessions;
    } catch (e) { /* ignore fetch errors */ }
  }, 10000);
})();

// Exports
window._consciousness = _consciousness;
window.ConsciousnessStream = ConsciousnessStream;
window.CorticalImpulse = CorticalImpulse;
window.InteractionTimeline = InteractionTimeline;
