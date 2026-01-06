// Gantt Core Module - Data Loading and State Management
// Part of unified Gantt system

const GanttCore = {
  data: null,
  expandedWaves: new Set(),
  filters: { showCompleted: true, showBlocked: true },
  timeline: { start: null, end: null, duration: 0 },

  async load(projectId) {
    const contentArea = document.getElementById('ganttContentArea');
    if (!contentArea) return;

    contentArea.innerHTML = '<div class="gantt-loading">Loading project timeline...</div>';

    if (!projectId) {
      contentArea.innerHTML = '<div class="empty-state"><div class="empty-state-title">No Project Selected</div></div>';
      return;
    }

    try {
      const dashboardRes = await fetch(`/api/project/${projectId}/dashboard`);
      const dashboardData = await dashboardRes.json();

      const plansPromises = (dashboardData.waves || []).map(async (planRef) => {
        // Extract numeric plan ID from plan reference like "P5"
        const planId = parseInt(planRef.id.replace('P', ''), 10);
        if (isNaN(planId)) return null;
        try {
          const planRes = await fetch(`/api/plan/${planId}`);
          const planData = await planRes.json();
          return { 
            id: planId, 
            name: planData.name || `Plan ${planId}`,
            waves: planData.waves || [] 
          };
        } catch (e) {
          Logger.warn(`Failed to load plan ${planId}:`, e);
          return null;
        }
      });

      const plansWithWaves = (await Promise.all(plansPromises)).filter(p => p !== null);

      this.data = {
        project: dashboardData.meta,
        plans: plansWithWaves,
        allWaves: []
      };

      // Create unique wave IDs by prefixing with planId
      plansWithWaves.forEach(plan => {
        (plan.waves || []).forEach(wave => {
          const uniqueWaveId = `P${plan.id}_${wave.wave_id}`;
          this.data.allWaves.push({ 
            ...wave, 
            original_wave_id: wave.wave_id,
            wave_id: uniqueWaveId, // Make unique across plans
            planId: plan.id, 
            planName: plan.name 
          });
        });
      });

      this.calculateTimeline();
      Logger.debug('Gantt data loaded:', this.data);

    } catch (error) {
      Logger.error('Failed to load Gantt data:', error);
      contentArea.innerHTML = `<div class="gantt-error">Error: ${error.message}</div>`;
    }
  },

  calculateTimeline() {
    if (!this.data?.allWaves?.length) return;

    let minDate = null, maxDate = null;

    this.data.allWaves.forEach(wave => {
      const dates = [
        wave.planned_start ? new Date(wave.planned_start) : null,
        wave.planned_end ? new Date(wave.planned_end) : null,
        wave.started_at ? new Date(wave.started_at) : null,
        wave.completed_at ? new Date(wave.completed_at) : null
      ];

      dates.forEach(d => {
        if (d && (!minDate || d < minDate)) minDate = d;
        if (d && (!maxDate || d > maxDate)) maxDate = d;
      });
    });

    const now = new Date();
    if (!minDate) minDate = new Date(now.getTime() - 7 * 86400000);
    if (!maxDate) maxDate = new Date(now.getTime() + 14 * 86400000);

    // Minimal padding - just 1% of duration
    const duration = maxDate - minDate;
    const padding = Math.max(60000, duration * 0.01); // At least 1 minute
    this.timeline = {
      start: new Date(minDate.getTime() - padding),
      end: new Date(maxDate.getTime() + padding),
      duration: 0
    };
    this.timeline.duration = this.timeline.end - this.timeline.start;
  },

  toggleWave(waveId) {
    if (this.expandedWaves.has(waveId)) {
      this.expandedWaves.delete(waveId);
    } else {
      this.expandedWaves.add(waveId);
    }
  },

  expandAll() {
    this.data?.allWaves?.forEach(w => this.expandedWaves.add(w.wave_id));
  },

  collapseAll() {
    this.expandedWaves.clear();
  },

  isExpanded(waveId) {
    return this.expandedWaves.has(waveId);
  },

  getWaves() {
    return this.data?.allWaves || [];
  },

  getTimeline() {
    return this.timeline;
  },

  hasData() {
    return this.data !== null && this.data.allWaves.length > 0;
  }
};

window.GanttCore = GanttCore;
