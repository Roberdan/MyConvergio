// Project Management - Plan Module
// Plan loading and transformation
async function loadPlanDetails(planId) {
  try {
    const numericPlanId = parseInt(planId, 10);
    if (isNaN(numericPlanId)) {
      console.error('Invalid planId:', planId);
      return;
    }
    const res = await fetch(`${API_BASE}/plan/${numericPlanId}`);
    const plan = await res.json();
    if (plan.error) {
      console.error('Plan not found:', planId);
      return;
    }
    currentPlanId = planId;
    data = transformPlanToData(plan);
    render();
    updateNavCounts();
    const histRes = await fetch(`${API_BASE}/plan/${planId}/history`);
    const history = await histRes.json();
    data.history = history;
    renderHistory();
  } catch (e) {
    console.error('Failed to load plan details:', e);
  }
}
function transformPlanToData(plan) {
  const now = new Date().toISOString();
  const waves = plan.waves || [];
  return {
    meta: {
      project: plan.name,
      project_id: plan.project_id,
      plan_id: plan.id,
      owner: plan.validated_by || 'planner',
      created: plan.created_at,
      updated: plan.started_at || plan.created_at
    },
    metrics: {
      throughput: {
        done: plan.tasks_done || 0,
        total: plan.tasks_total || 1,
        percent: plan.tasks_total > 0 ? Math.round(100 * plan.tasks_done / plan.tasks_total) : 0
      },
      velocity: { value: '2.5' },
      cycleTime: { value: '45' },
      quality: { score: 95 }
    },
    bugs: { fixed: 0, total: 0 },
    timeline: {
      start: plan.started_at || plan.created_at || now,
      eta: plan.completed_at || now,
      remaining: plan.status === 'done' ? 'Done' : 'In progress',
      data: generateTimelineData(plan.tasks_done, plan.tasks_total)
    },
    waves: waves.map(w => ({
      id: w.wave_id,
      wave_id: w.wave_id,
      name: w.name,
      status: w.status === 'pending' ? 'pending' : w.status === 'in_progress' ? 'in_progress' : 'done',
      done: w.tasks_done || 0,
      total: w.tasks_total || 0,
      tasks_done: w.tasks_done || 0,
      tasks_total: w.tasks_total || 0,
      planned_start: w.planned_start,
      planned_end: w.planned_end,
      started_at: w.started_at,
      completed_at: w.completed_at,
      depends_on: w.depends_on,
      estimated_hours: w.estimated_hours || 8,
      tasks: (w.tasks || []).map(t => ({
        id: t.task_id,
        title: t.title,
        status: t.status,
        assignee: t.assignee,
        priority: t.priority,
        type: t.type,
        files: t.files ? t.files.split(',') : [],
        notes: t.notes,
        timing: {
          started: t.started_at,
          completed: t.completed_at,
          duration: t.duration_minutes
        }
      }))
    })),
    contributors: [
      { id: 'planner', name: 'Planner', avatar: 'P', role: 'planning', tasks: 0, status: 'idle' },
      { id: 'executor', name: 'Executor', avatar: 'E', role: 'execution', tasks: plan.tasks_done || 0, status: plan.status === 'doing' ? 'active' : 'idle' },
      { id: 'thor', name: 'Thor', avatar: 'T', role: 'validation', tasks: plan.validated_at ? 1 : 0, status: plan.validated_at ? 'done' : 'pending' }
    ],
    history: []
  };
}
function generateTimelineData(done, total) {
  const data = [];
  const steps = 8;
  for (let i = 0; i <= steps; i++) {
    const progress = Math.round((done / Math.max(total, 1)) * (i / steps) * total);
    data.push({
      time: `T${i}`,
      done: progress,
      target: Math.round((i / steps) * total)
    });
  }
  return data;
}
function createEmptyPlanData(projectId, projectName) {
  return {
    meta: { project: projectName, project_id: projectId, owner: 'none' },
    metrics: {
      throughput: { done: 0, total: 0, percent: 0 },
      velocity: { value: '0' },
      cycleTime: { value: '0' },
      quality: { score: 0 }
    },
    bugs: { fixed: 0, total: 0 },
    timeline: { start: new Date().toISOString(), eta: new Date().toISOString(), remaining: 'No plan', data: [] },
    waves: [],
    contributors: [],
    history: []
  };
}

// Export to window
window.loadPlanDetails = loadPlanDetails;
window.createEmptyPlanData = createEmptyPlanData;
