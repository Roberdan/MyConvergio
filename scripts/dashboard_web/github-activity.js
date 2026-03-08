(function () {
  const byId = (id) => document.getElementById(id);
  const esc = (v) =>
    String(v ?? "").replace(/[&<>"']/g, (m) => ({
      "&": "&amp;",
      "<": "&lt;",
      ">": "&gt;",
      '"': "&quot;",
      "'": "&#39;",
    })[m]);

  function parseTs(value) {
    if (typeof value === "number") return value > 1e12 ? value : value * 1000;
    const parsed = Date.parse(String(value || ""));
    return Number.isFinite(parsed) ? parsed : 0;
  }

  function timeAgo(value) {
    const ts = parseTs(value);
    if (!ts) return "";
    const sec = Math.max(0, Math.floor((Date.now() - ts) / 1000));
    if (sec < 60) return `${sec}s`;
    if (sec < 3600) return `${Math.floor(sec / 60)}m`;
    if (sec < 86400) return `${Math.floor(sec / 3600)}h`;
    return `${Math.floor(sec / 86400)}d`;
  }

  function activeProjectId() {
    const st = window.DashboardState || {};
    const plans = Array.isArray(st.allMissionPlans) ? st.allMissionPlans : [];
    const first = plans.find((row) => row?.plan?.project_id) || plans[0];
    return first?.plan?.project_id || st.lastMissionData?.plan?.project_id || "";
  }

  function eventColor(type) {
    if (type === "PushEvent") return "var(--green)";
    if (type === "PullRequestEvent") return "var(--magenta)";
    if (type === "PullRequestReviewEvent") return "var(--gold)";
    if (type === "ReleaseEvent") return "var(--cyan)";
    if (type === "CheckRunEvent" || type === "CheckSuiteEvent" || type === "StatusEvent") {
      return "var(--blue)";
    }
    return "var(--text-dim)";
  }

  function eventIcon(type) {
    if (type === "PushEvent") return Icons.gitMerge(12);
    if (type === "PullRequestEvent") return Icons.dot(12);
    if (type === "PullRequestReviewEvent") return Icons.checkCircle(12);
    if (type === "ReleaseEvent") return Icons.zap(12);
    if (type === "CheckRunEvent" || type === "CheckSuiteEvent" || type === "StatusEvent") {
      return Icons.check(12);
    }
    return Icons.dot(12);
  }

  function normalizeRemoteEvent(evt) {
    const payload = evt?.payload || {};
    const type = String(evt?.type || "Event");
    const actor = evt?.actor?.login || evt?.actor?.display_login || "";
    let label = type;
    let details = "";
    let url = "";
    if (type === "PushEvent") {
      const commits = Number(payload?.size || payload?.commits?.length || 0);
      const ref = String(payload?.ref || "").replace("refs/heads/", "");
      label = commits === 1 ? "1 commit pushed" : `${commits || "New"} commits pushed`;
      details = ref ? `branch ${ref}` : "push event";
      url = payload?.commits?.[0]?.url || "";
    } else if (type === "PullRequestEvent") {
      const pr = payload?.pull_request || {};
      label = `PR #${pr?.number || "?"} ${payload?.action || "updated"}`;
      details = pr?.title || "pull request activity";
      url = pr?.html_url || "";
    } else if (type === "PullRequestReviewEvent") {
      const state = String(payload?.review?.state || "commented").toLowerCase().replace(/_/g, " ");
      const pr = payload?.pull_request || {};
      label = `Review ${state}`;
      details = `PR #${pr?.number || "?"}`;
      url = pr?.html_url || "";
    } else if (type === "ReleaseEvent") {
      const release = payload?.release || {};
      label = `Release ${payload?.action || "published"}`;
      details = release?.tag_name || release?.name || "new release";
      url = release?.html_url || "";
    } else if (type === "CheckRunEvent" || type === "CheckSuiteEvent" || type === "StatusEvent") {
      const conclusion = payload?.check_run?.conclusion || payload?.check_suite?.conclusion || payload?.state || payload?.check_run?.status || payload?.check_suite?.status || payload?.action || "updated";
      label = "CI status update";
      details = String(conclusion).replace(/_/g, " ");
      url = payload?.check_run?.html_url || payload?.check_suite?.url || "";
    } else {
      label = type.replace(/([A-Z])/g, " $1").trim();
      details = payload?.action || "activity";
    }
    return {
      kind: "remote",
      type,
      icon: eventIcon(type),
      color: eventColor(type),
      label,
      details,
      source: actor,
      ts: parseTs(evt?.created_at),
      planId: 0,
      url,
    };
  }

  function normalizeLocalEvent(evt) {
    const type = String(evt?.event_type || "local_event");
    return {
      kind: "local",
      type,
      icon: Icons.dot(12),
      color: "var(--text-dim)",
      label: type.replace(/_/g, " "),
      details: evt?.task_id ? `task ${evt.task_id}` : evt?.event_action || "dashboard event",
      source: evt?.status || "",
      ts: parseTs(evt?.event_at || evt?.created_at),
      planId: Number(evt?.plan_id || 0),
      url: "",
    };
  }

  function gatherEvents(payload) {
    const remote = Array.isArray(payload?.remote_events) ? payload.remote_events.map(normalizeRemoteEvent) : [];
    const local = Array.isArray(payload?.local_events) ? payload.local_events.map(normalizeLocalEvent) : [];
    return [...remote, ...local]
      .filter((evt) => evt && evt.ts)
      .sort((a, b) => b.ts - a.ts)
      .slice(0, 20);
  }

  function renderGitHubEvent(evt) {
    const clickable = evt.url || evt.planId;
    const url = String(evt.url || "").replace(/"/g, "%22");
    const click = evt.url
      ? ` onclick="window.open('${url}','_blank','noopener')"`
      : evt.planId
        ? ` onclick="location.hash='#plan/${evt.planId}'"`
        : "";
    const source = evt.source ? `<span class="event-peer">${esc(evt.source)}</span>` : "";
    const plan = evt.planId ? `<span class="event-plan">#${evt.planId}</span>` : "";
    return `<div class="event-row github-activity-row github-activity-${evt.kind}"${click} style="cursor:${clickable ? "pointer" : "default"}"><span class="github-activity-icon" style="color:${evt.color}">${evt.icon}</span><span class="event-type">${esc(evt.label)}</span>${source}${plan}<span class="event-age">${timeAgo(evt.ts)}</span></div><div class="github-activity-detail">${esc(evt.details)}</div>`;
  }

  async function renderGitHubActivity() {
    const root = byId("event-feed-content");
    if (!root) return;
    const projectId = activeProjectId();
    if (!projectId) {
      root.innerHTML =
        '<span style="color:var(--text-dim);font-size:11px">No GitHub context available</span>';
      return;
    }
    try {
      const res = await fetch(`/api/github/events/${encodeURIComponent(projectId)}`);
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      const payload = await res.json();
      const events = gatherEvents(payload);
      if (!events.length) {
        root.innerHTML =
          '<span style="color:var(--text-dim);font-size:11px">No GitHub activity yet</span>';
        return;
      }
      root.innerHTML = events.map(renderGitHubEvent).join("");
    } catch (err) {
      root.innerHTML = `<span style="color:var(--text-dim);font-size:11px">Error loading GitHub activity: ${esc(err.message)}</span>`;
    }
  }

  window.renderGitHubEvent = renderGitHubEvent;
  window.renderGitHubActivity = renderGitHubActivity;
  window.renderEventFeed = renderGitHubActivity;
})();
