(function () {
  const DEFAULT_TICK_MS = 1000;

  const PollScheduler = {
    _jobs: [],
    _timer: null,
    _paused: false,
    _currentSection: "overview",
    _lastTick: 0,

    register(name, fn, intervalMs, sections = ["all"]) {
      if (!name || typeof fn !== "function") return null;
      const interval = Math.max(1000, Number(intervalMs) || DEFAULT_TICK_MS);
      const normalizedSections = Array.isArray(sections) && sections.length ? sections : ["all"];
      const now = Date.now();
      const idx = this._jobs.findIndex((job) => job.name === name);
      const job = { name, fn, intervalMs: interval, sections: normalizedSections, nextRunAt: now + interval };
      if (idx >= 0) this._jobs[idx] = job;
      else this._jobs.push(job);
      return job;
    },

    unregister(name) {
      this._jobs = this._jobs.filter((job) => job.name !== name);
    },

    setInterval(name, intervalMs) {
      const job = this._jobs.find((item) => item.name === name);
      if (!job) return;
      job.intervalMs = Math.max(1000, Number(intervalMs) || DEFAULT_TICK_MS);
      job.nextRunAt = Date.now() + job.intervalMs;
    },

    setSection(section) {
      this._currentSection = section || "overview";
    },

    _matchesSection(job) {
      return job.sections.includes("all") || job.sections.includes(this._currentSection);
    },

    _runDueJobs() {
      if (this._paused) return;
      const now = Date.now();
      for (const job of this._jobs) {
        if (now < job.nextRunAt) continue;
        job.nextRunAt = now + job.intervalMs;
        if (!this._matchesSection(job)) continue;
        try {
          job.fn();
        } catch (error) {
          console.error(`[PollScheduler] Job "${job.name}" failed`, error);
        }
      }
    },

    tickNow() {
      this._runDueJobs();
    },

    trigger(name) {
      const job = this._jobs.find((item) => item.name === name);
      if (!job || this._paused || !this._matchesSection(job)) return;
      try {
        job.fn();
      } catch (error) {
        console.error(`[PollScheduler] Job "${name}" failed`, error);
      }
      job.nextRunAt = Date.now() + job.intervalMs;
    },

    start() {
      if (this._timer) return;
      this._lastTick = Date.now();
      this._timer = setInterval(() => this._runDueJobs(), DEFAULT_TICK_MS);
    },

    pause() {
      this._paused = true;
    },

    resume() {
      this._paused = false;
      const now = Date.now();
      this._jobs.forEach((job) => {
        if (job.nextRunAt < now) job.nextRunAt = now;
      });
      this._runDueJobs();
    },
  };

  window.PollScheduler = PollScheduler;

  document.addEventListener("visibilitychange", () => {
    document.hidden ? PollScheduler.pause() : PollScheduler.resume();
  });
})();
