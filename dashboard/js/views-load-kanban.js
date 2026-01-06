// Views - Kanban Data Loading
// Loads kanban board data from API
async function loadKanban() {
  const kanban = { todo: [], doing: [], done: [] };
  let totalTokens = 0;
  let totalCost = 0;
  const projectIds = new Set();
  try {
    const res = await fetch(`${API_BASE}/kanban`);
    const plans = await res.json();
    plans.forEach(plan => projectIds.add(plan.project_id));
    const tokenPromises = Array.from(projectIds).map(async (projectId) => {
      try {
        const tokRes = await fetch(`${API_BASE}/project/${projectId}/tokens`);
        const tokData = await tokRes.json();
        return { projectId, tokens: tokData.stats?.total_tokens || 0, cost: tokData.stats?.total_cost || 0 };
      } catch (e) {
        return { projectId, tokens: 0, cost: 0 };
      }
    });
    const tokenResults = await Promise.all(tokenPromises);
    const tokensByProject = {};
    tokenResults.forEach(t => {
      tokensByProject[t.projectId] = t;
      totalTokens += t.tokens;
      totalCost += t.cost;
    });
    plans.forEach(plan => {
      const status = plan.status || 'todo';
      const projectTokens = tokensByProject[plan.project_id] || { tokens: 0, cost: 0 };
      const updatedAt = plan.completed_at || plan.started_at || plan.created_at;
      const lastUpdate = updatedAt ? new Date(updatedAt) : null;
      const isRecent = lastUpdate && (Date.now() - lastUpdate.getTime()) < 3600000;
      const isRunning = status === 'doing' && isRecent;
      kanban[status].push({
        project: plan.project_name,
        projectId: plan.project_id,
        planId: plan.plan_id,
        name: plan.plan_name,
        isMaster: plan.is_master,
        progress: plan.progress || 0,
        tasksDone: plan.tasks_done || 0,
        tasksTotal: plan.tasks_total || 0,
        startedAt: plan.started_at,
        completedAt: plan.completed_at,
        updatedAt: updatedAt,
        isRunning: isRunning,
        tokens: projectTokens.tokens,
        cost: projectTokens.cost,
        validatedBy: plan.validated_by,
        validatedAt: plan.validated_at
      });
    });
  } catch (e) {
    console.error('Failed to load kanban from API:', e);
    if (!registry) await loadProjects();
    for (const [projectId, project] of Object.entries(registry.projects || {})) {
      projectIds.add(projectId);
      if (project.plans_doing > 0) {
        kanban.doing.push({ project: project.name, projectId, name: 'Active plan', progress: 50 });
      }
      if (project.plans_todo > 0) {
        kanban.todo.push({ project: project.name, projectId, name: 'Pending plan', progress: 0 });
      }
      if (project.plans_done > 0) {
        kanban.done.push({ project: project.name, projectId, name: 'Completed plan', progress: 100 });
      }
    }
  }
  document.getElementById('kanbanTotalProjects').textContent = projectIds.size;
  document.getElementById('kanbanTotalPlans').textContent = kanban.todo.length + kanban.doing.length + kanban.done.length;
  document.getElementById('kanbanActivePlans').textContent = kanban.doing.length;
  document.getElementById('kanbanCompletedPlans').textContent = kanban.done.length;
  document.getElementById('kanbanTotalTokens').textContent = totalTokens ? totalTokens.toLocaleString() : '0';
  document.getElementById('kanbanTotalCost').textContent = totalCost ? '$' + totalCost.toFixed(2) : '$0';
  renderKanban(kanban);
  
  // Render trash column if function exists
  if (typeof renderTrashColumn === 'function') {
    renderTrashColumn();
  }
}

