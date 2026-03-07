/* brain-organism.js — Neuron state machine & synaptic firing */
'use strict';
const NeuronStates = {
  DORMANT:'dormant', SPAWNING:'spawning', PREPARING:'preparing',
  FIRING:'firing', TRANSMITTING:'transmitting', COOLING:'cooling', DEAD:'dead',
};

const STATE_PARAMS = {
  dormant:      { intensity:0.1, pulseSpeed:0.3, h:200, s:20,  l:20 },
  spawning:     { intensity:0.5, pulseSpeed:0,   h:200, s:50,  l:30 },
  preparing:    { intensity:0.3, pulseSpeed:0.8, h:210, s:60,  l:40 },
  firing:       { intensity:1.0, pulseSpeed:2.0, h:45,  s:100, l:60 },
  transmitting: { intensity:0.8, pulseSpeed:3.0, h:45,  s:100, l:60 },
  cooling:      { intensity:0.9, pulseSpeed:0.5, h:140, s:80,  l:50 },
  dead:         { intensity:0.4, pulseSpeed:0,   h:0,   s:80,  l:30 },
};

class NeuronState {
  constructor(id) {
    this.id = id; this.state = NeuronStates.DORMANT; this.stateTime = 0;
    this.intensity = 0.1; this.pulseSpeed = 0.3;
    this.color = { h: 200, s: 50, l: 30 };
    this.size = 0; this.targetSize = 8;
    this.trail = []; this._prevState = null;
  }

  transition(newState) {
    if (newState === this.state) return;
    this._prevState = this.state;
    this.state = newState;
    this.stateTime = 0;

    const p = STATE_PARAMS[newState];
    if (!p) return;
    this.intensity = p.intensity;
    this.pulseSpeed = p.pulseSpeed;
    this.color = { h: p.h, s: p.s, l: p.l };

    if (newState === NeuronStates.SPAWNING) this.size = 0;
    if (newState === NeuronStates.TRANSMITTING) this._spawnTrail();
  }

  _spawnTrail() {
    this.trail = [];
    for (let i = 0; i < 5; i++) {
      this.trail.push({
        t: -i * 0.12,
        speed: 0.7 + Math.random() * 0.5,
        size: 1.5 + Math.random() * 1.5,
        alpha: 0.8 + Math.random() * 0.2,
      });
    }
  }

  update(dt) {
    this.stateTime += dt;
    const t = this.stateTime;

    switch (this.state) {
      case NeuronStates.SPAWNING:
        this.size = Math.min(this.targetSize, this.targetSize * (t / 300));
        if (t >= 300) this.transition(NeuronStates.PREPARING);
        break;

      case NeuronStates.FIRING: {
        const wave = Math.sin(t * this.pulseSpeed * 2 * Math.PI / 1000);
        this.intensity = 0.8 + 0.2 * wave;
        break;
      }

      case NeuronStates.COOLING:
        this.intensity = 0.9 * Math.exp(-t / 800);
        if (t > 2000) this.intensity = 0;
        break;

      case NeuronStates.TRANSMITTING:
        this.trail.forEach(p => { p.t += dt * p.speed * 0.001; });
        this.trail = this.trail.filter(p => p.t < 1.2);
        if (this.trail.length === 0) this.transition(NeuronStates.COOLING);
        break;

      case NeuronStates.DORMANT: {
        const breathe = Math.sin(t * 0.3 * 2 * Math.PI / 1000);
        this.intensity = 0.08 + 0.04 * breathe;
        break;
      }

      case NeuronStates.PREPARING: {
        const pulse = Math.sin(t * this.pulseSpeed * 2 * Math.PI / 1000);
        this.intensity = 0.25 + 0.1 * pulse;
        break;
      }

      case NeuronStates.DEAD:
        this.intensity = 0.3 + 0.1 * Math.exp(-t / 500);
        break;
    }

    if (this.state !== NeuronStates.SPAWNING) {
      this.size += (this.targetSize - this.size) * Math.min(1, dt * 0.005);
    }
  }

  toHSL(alphaOverride) {
    const a = alphaOverride !== undefined ? alphaOverride : this.intensity;
    return 'hsla(' + this.color.h + ',' + this.color.s + '%,' + this.color.l + '%,' + a.toFixed(3) + ')';
  }
}

class Synapse {
  constructor(fromId, toId, type) {
    this.from = fromId; this.to = toId;
    this.type = type; // dependency | wave_sequence | thor_validation | context_pass
    this.active = false; this.particles = []; this.intensity = 0; this.lastFireTime = 0;
  }

  fire() {
    this.active = true;
    this.intensity = 1.0;
    this.lastFireTime = Date.now();
    const count = 5 + Math.floor(Math.random() * 4);
    for (let i = 0; i < count; i++) {
      this.particles.push({
        t: -i * 0.15,
        speed: 0.8 + Math.random() * 0.4,
        size: 2 + Math.random() * 2,
        brightness: 0.8 + Math.random() * 0.2,
      });
    }
  }

  update(dt) {
    if (!this.active) return;
    this.intensity *= Math.pow(0.97, dt / 16);
    this.particles.forEach(p => { p.t += dt * p.speed * 0.001; });
    this.particles = this.particles.filter(p => p.t < 1.2);
    if (this.particles.length === 0 && this.intensity < 0.05) {
      this.active = false;
      this.intensity = 0;
    }
  }

  getTypeColor() {
    switch (this.type) {
      case 'dependency':      return { h: 200, s: 80, l: 55 }; // cyan
      case 'wave_sequence':   return { h: 280, s: 70, l: 55 }; // purple
      case 'thor_validation': return { h: 45,  s: 100, l: 55 }; // gold
      case 'context_pass':    return { h: 160, s: 70, l: 50 }; // teal
      default:                return { h: 200, s: 50, l: 50 };
    }
  }
}

class OrganismBreath {
  constructor() {
    this.phase = 0;
    this.rate = 0.2; // Hz -- one breath every 5 seconds
  }

  update(dt) {
    this.phase += dt * this.rate * 2 * Math.PI / 1000;
    if (this.phase > 1e6) this.phase -= 1e6; // prevent overflow
  }

  getBreath() {
    return 0.5 + 0.5 * Math.sin(this.phase);
  }

  applyTo(neuron) {
    if (neuron.state === NeuronStates.DORMANT) {
      neuron.intensity = 0.06 + 0.06 * this.getBreath();
    }
  }
}

function taskToNeuronState(task) {
  if (!task) return NeuronStates.DORMANT;
  const s = task.status;
  const sub = task.substatus || '';

  if (s === 'done' && task._justCompleted) return NeuronStates.COOLING;
  if (s === 'done') return null; // fully resolved, hide
  if (s === 'cancelled' || s === 'skipped') return null;
  if (s === 'blocked') return NeuronStates.DEAD;
  if (s === 'submitted') return NeuronStates.COOLING;
  if (sub === 'waiting_thor') return NeuronStates.TRANSMITTING;
  if (sub === 'agent_running') return NeuronStates.FIRING;
  if (s === 'in_progress') return NeuronStates.FIRING;
  if (s === 'pending') return NeuronStates.DORMANT;
  return NeuronStates.DORMANT;
}

function detectFires(prevTasks, currTasks) {
  const fires = [];
  if (!prevTasks || !currTasks) return fires;

  const prevMap = {};
  prevTasks.forEach(t => { prevMap[t.id] = t; });

  currTasks.forEach(t => {
    const prev = prevMap[t.id];
    if (!prev) {
      fires.push({ type: 'spawn', taskId: t.id });
      return;
    }
    if (prev.status === 'pending' && t.status === 'in_progress') {
      fires.push({ type: 'activation', taskId: t.id, deps: t.depends_on || [] });
    }
    if (prev.status === 'in_progress' && t.status === 'submitted') {
      fires.push({ type: 'submit', taskId: t.id });
    }
    if (prev.status !== 'done' && t.status === 'done') {
      fires.push({ type: 'completion', taskId: t.id });
    }
    if (prev.status !== 'blocked' && t.status === 'blocked') {
      fires.push({ type: 'death', taskId: t.id });
    }
  });
  return fires;
}

function buildSynapses(tasks) {
  const synapses = [];
  const taskMap = {};
  tasks.forEach(t => { taskMap[t.id] = t; });

  tasks.forEach(t => {
    const deps = t.depends_on || [];
    deps.forEach(depId => {
      if (taskMap[depId]) {
        synapses.push(new Synapse(depId, t.id, 'dependency'));
      }
    });
  });
  return synapses;
}

window.BrainOrganism = {
  NeuronStates,
  NeuronState,
  Synapse,
  OrganismBreath,
  taskToNeuronState,
  detectFires,
  buildSynapses,
};
