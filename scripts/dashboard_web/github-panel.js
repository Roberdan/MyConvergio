(function () {
  const byId = (id) => document.getElementById(id);
  const esc = (v) =>
    String(v ?? '').replace(/[&<>"']/g, (m) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[m]);
  const state = { contextKey: '', timer: null };

  async function jsonFetch(url) {
    const res = await fetch(url);
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    return res.json();
  }

  function activeSessionId() {
    return window.chatTabs?.getActiveState?.()?.session_id || '';
  }

  async function resolveContext() {
    const sid = activeSessionId();
    if (!sid) return null;
    const sessions = await jsonFetch('/api/chat/sessions');
    const session = (sessions.sessions || []).find((row) => row.id === sid);
    const planId = Number(session?.plan_id || 0);
    const projectId = Number(session?.project_id || 0);
    if (!planId || !projectId) return null;
    return { sid, planId, projectId };
  }

  function summarizeReviews(events = []) {
    const counts = { approved: 0, changes: 0, commented: 0 };
    events
      .filter((evt) => evt.type === 'PullRequestReviewEvent')
      .forEach((evt) => {
        const state = String(evt.payload?.review?.state || '').toUpperCase();
        if (state === 'APPROVED') counts.approved += 1;
        else if (state === 'CHANGES_REQUESTED') counts.changes += 1;
        else if (state) counts.commented += 1;
      });
    return counts;
  }

  function summarizeCi(events = []) {
    const latest = events.find((evt) => evt.type === 'CheckSuiteEvent' || evt.type === 'CheckRunEvent' || evt.type === 'StatusEvent');
    if (!latest) return 'unknown';
    return (
      latest.payload?.check_suite?.conclusion ||
      latest.payload?.check_run?.conclusion ||
      latest.payload?.state ||
      latest.payload?.check_suite?.status ||
      latest.payload?.check_run?.status ||
      'unknown'
    );
  }

  function pullRequests(events = []) {
    const map = new Map();
    events
      .filter((evt) => evt.type === 'PullRequestEvent')
      .forEach((evt) => {
        const pr = evt.payload?.pull_request;
        const number = Number(pr?.number || 0);
        if (!number) return;
        if (map.has(number)) return;
        map.set(number, {
          number,
          title: pr?.title || `PR #${number}`,
          url: pr?.html_url || '',
          state: pr?.state || evt.payload?.action || 'unknown',
          branch: pr?.head?.ref || 'unknown',
        });
      });
    return [...map.values()].slice(0, 5);
  }

  function linkedIssues(stats, events = []) {
    const issueSet = new Set();
    const issueRows = [];
    const addIssue = (number, title, url, state = '') => {
      const n = Number(number || 0);
      if (!n || issueSet.has(n)) return;
      issueSet.add(n);
      issueRows.push({ number: n, title: title || `Issue #${n}`, url: url || '', state: state || 'open' });
    };
    addIssue(stats?.github_issue, `Plan issue #${stats?.github_issue || ''}`, '', 'linked');
    events.forEach((evt) => {
      if (evt.type !== 'IssuesEvent' && evt.type !== 'IssueCommentEvent') return;
      const issue = evt.payload?.issue;
      addIssue(issue?.number, issue?.title, issue?.html_url, issue?.state);
    });
    return issueRows.slice(0, 5);
  }

  function renderPanel(ctx, payload) {
    const root = byId('chat-github-panel');
    if (!root) return;
    if (!ctx) {
      root.innerHTML = '<div class="github-panel-empty">Attach chat to a plan to load GitHub context.</div>';
      return;
    }
    const repo = payload.stats?.repo_stats?.nameWithOwner || payload.stats?.repo || payload.commits?.repo || 'unknown';
    const prs = pullRequests(payload.events?.remote_events || []);
    const reviews = summarizeReviews(payload.events?.remote_events || []);
    const ci = summarizeCi(payload.events?.remote_events || []);
    const branch = prs[0]?.branch || 'unknown';
    const remoteCommits = (payload.commits?.remote_commits || []).slice(0, 5);
    const issues = linkedIssues(payload.stats, payload.events?.remote_events || []);
    root.innerHTML = `
      <div class="github-panel-meta">
        <span>Repo: <b>${esc(repo)}</b></span>
        <span>Branch: <b>${esc(branch)}</b></span>
      </div>
      <div class="github-panel-section">
        <h5>Pull Requests</h5>
        ${(prs.length
          ? prs
              .map(
                (pr) => `<div class="github-row">
              <a href="${esc(pr.url)}" target="_blank" rel="noreferrer">#${pr.number}</a>
              <span class="github-muted">${esc(pr.state)}</span>
            </div><div class="github-sub">${esc(pr.title)}</div>`,
              )
              .join('')
          : '<div class="github-panel-empty">No PR activity.</div>')}
        <div class="github-foot">CI: ${esc(ci)} · Reviews A:${reviews.approved} C:${reviews.changes} M:${reviews.commented}</div>
      </div>
      <div class="github-panel-section">
        <h5>Recent Commits</h5>
        ${(remoteCommits.length
          ? remoteCommits
              .map((c) => {
                const sha = String(c.sha || '').slice(0, 7);
                const msg = c.commit?.message || c.commit_message || 'commit';
                return `<div class="github-row"><span>${esc(sha)}</span><span class="github-muted">${esc(msg)}</span></div>`;
              })
              .join('')
          : '<div class="github-panel-empty">No commits available.</div>')}
      </div>
      <div class="github-panel-section">
        <h5>Linked Issues</h5>
        ${(issues.length
          ? issues
              .map((i) => `<div class="github-row"><span>#${i.number}</span><span class="github-muted">${esc(i.state)}</span></div><div class="github-sub">${esc(i.title)}</div>`)
              .join('')
          : '<div class="github-panel-empty">No linked issues found.</div>')}
      </div>`;
  }

  async function fetchGitHubData(context) {
    if (!context) return { stats: null, commits: null, events: null };
    const [stats, commits, events] = await Promise.all([
      jsonFetch(`/api/github/stats/${context.planId}`),
      jsonFetch(`/api/github/commits/${context.planId}`),
      jsonFetch(`/api/github/events/${context.projectId}`),
    ]);
    return { stats: stats?.ok ? stats : null, commits: commits?.ok ? commits : null, events: events?.ok ? events : null };
  }

  async function refreshGitHubPanel() {
    try {
      const ctx = await resolveContext();
      const nextKey = ctx ? `${ctx.sid}:${ctx.planId}:${ctx.projectId}` : '';
      state.contextKey = nextKey;
      const data = await fetchGitHubData(ctx);
      renderPanel(ctx, data);
    } catch (err) {
      const root = byId('chat-github-panel');
      if (root) root.innerHTML = `<div class="github-panel-empty">GitHub context unavailable: ${esc(err.message)}</div>`;
    }
  }

  function boot() {
    if (state.timer) clearInterval(state.timer);
    state.timer = setInterval(refreshGitHubPanel, 30000);
    refreshGitHubPanel();
    window.githubPanel = { fetchGitHubData, refresh: refreshGitHubPanel };
  }

  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', boot);
  else boot();
})();
