(function () {
  const state = { latest: null, history: [], definitions: [], page: 1, perPage: 50, total: 0, unavailable: false };
  const byId = (id) => document.getElementById(id);
  const esc = (v) => String(v ?? "").replace(/[&<>"']/g, (m) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[m]);
  const parseTs = (v) => !v ? 0 : typeof v === "number" ? (v > 1e12 ? v : v * 1000) : (Date.parse(String(v)) || 0);
  const num = (v) => Number(v || 0);
  function formatDuration(sec) {
    let s = Number.isFinite(Number(sec)) ? Math.max(0, Math.round(Number(sec))) : NaN;
    if (!Number.isFinite(s)) s = Math.max(0, Math.round((parseTs(state.latest?.finished_at) - parseTs(state.latest?.started_at)) / 1000));
    const h = Math.floor(s / 3600), m = Math.floor((s % 3600) / 60), r = s % 60;
    return h ? `${h}h ${m}m` : m ? `${m}m ${r}s` : `${r}s`;
  }
  function formatTimestamp(val) {
    const ts = parseTs(val);
    return ts ? new Date(ts).toLocaleString("en-GB", { timeZone: "Europe/Rome", day: "2-digit", month: "2-digit", year: "numeric", hour: "2-digit", minute: "2-digit", second: "2-digit", hour12: false, timeZoneName: "short" }) : "n/a";
  }
  function timeAgo(val) {
    const ts = parseTs(val);
    if (!ts) return "n/a";
    const sec = Math.max(0, Math.floor((Date.now() - ts) / 1000));
    return sec < 60 ? `${sec}s ago` : sec < 3600 ? `${Math.floor(sec / 60)}m ago` : sec < 86400 ? `${Math.floor(sec / 3600)}h ago` : `${Math.floor(sec / 86400)}d ago`;
  }
  function statusBadge(status) {
    const s = String(status || "failed").toLowerCase();
    const kind = s === "ok" || s === "success" || s === "completed" ? ["nightly-ok", "OK"] : s === "running" ? ["nightly-running", "RUNNING"] : s === "action_required" || s === "action" ? ["nightly-action", "ACTION"] : ["nightly-failed", "FAILED"];
    return `<span class="nightly-badge ${kind[0]}">${kind[1]}</span>`;
  }
  const pill = (label, cls, extra = "") => `<span class="nightly-badge ${cls}" style="${extra}">${esc(label)}</span>`;
  const toast = (title, msg, type) => window.showToast ? window.showToast(title, msg || "", null, type) : alert(`${title}${msg ? `: ${msg}` : ""}`);
  async function api(url, method = "GET", body) {
    const res = await fetch(url, { method, headers: body ? { "Content-Type": "application/json" } : undefined, body: body ? JSON.stringify(body) : undefined });
    const data = await res.json().catch(() => ({}));
    if (!res.ok || data.ok === false) throw new Error(data.error || `${method} ${url} failed`);
    return data;
  }
  async function refreshWidget() {
    const data = await api(`/api/nightly/jobs?page=1&per_page=${state.perPage || 50}`);
    window.renderNightlyJobs(data);
  }
  async function loadMore() {
    const data = await api(`/api/nightly/jobs?page=${state.page + 1}&per_page=${state.perPage || 50}`);
    state.page = num(data.page) || state.page + 1;
    state.total = num(data.total) || state.total;
    state.perPage = num(data.per_page) || state.perPage;
    state.history = state.history.concat((data.history || []).filter((row) => !state.history.some((seen) => String(seen.id) === String(row.id))));
    draw();
  }
  function parseReport(raw) {
    if (!raw) return {};
    if (typeof raw === "object") return raw;
    try { return JSON.parse(raw); } catch { return {}; }
  }
  function collect(report, key, fallback) {
    const bucket = report[key] || report[`${key}_issues`] || report[`${key}_summary`] || {};
    const items = [bucket.issues, bucket.items, report[`${key}_top_issues`], report[`${key}_titles`], report[`${key}_issue_titles`]].find(Array.isArray) || (Array.isArray(bucket) ? bucket : []);
    return {
      count: Number(report[`${key}_count`] ?? bucket.count ?? fallback ?? items.length ?? 0),
      titles: items.map((item) => typeof item === "string" ? item : item?.title || item?.issue_title || item?.name).filter(Boolean).slice(0, 3),
    };
  }
  function createForm() {
    return `<div class="nightly-create-form">
      <div class="nightly-history-title">New Nightly Job</div>
      <input id="nj-name" class="nightly-input" placeholder="Job name" />
      <input id="nj-script" class="nightly-input" placeholder="Script path" />
      <input id="nj-schedule" class="nightly-input" value="0 3 * * *" placeholder="Cron schedule" />
      <input id="nj-host" class="nightly-input" value="local" placeholder="Target host" />
      <input id="nj-desc" class="nightly-input" placeholder="Description" />
      <div class="nightly-form-actions"><button class="nightly-btn nightly-btn-save" data-action="create">Create</button><button class="nightly-btn nightly-btn-cancel" data-action="cancel-create">Cancel</button></div>
    </div>`;
  }
  function latestSection() {
    if (!state.latest) return `<div class="nightly-empty">No nightly runs recorded yet.</div>`;
    const latest = state.latest, report = parseReport(latest.report_json), sentry = collect(report, "sentry", latest.sentry_unresolved), github = collect(report, "github", latest.github_open_issues);
    const deploy = report.deploy_status || report.deploy?.status || report.deployment?.status || "";
    const actionRow = `
      <div style="display:flex;gap:6px;flex-wrap:wrap;margin-top:8px">
        <button class="nightly-btn" data-action="retry" data-id="${esc(latest.id)}">Retry</button>
        <button class="nightly-btn" data-action="logs" data-id="${esc(latest.id)}">View Logs</button>
        ${latest.pr_url ? `<button class="nightly-btn" data-action="open-pr" data-url="${esc(latest.pr_url)}">View PR</button>` : ""}
      </div>`;
    return `<details open style="margin-top:10px"><summary style="cursor:pointer;color:var(--text);font-weight:600">Latest Run</summary>
      <div class="nightly-latest" style="margin-top:8px">
        <div class="nightly-summary">${esc(latest.summary || "No summary available.")}</div>
        <div class="nightly-metrics">
          <span title="${formatTimestamp(latest.started_at)}">Started ${formatTimestamp(latest.started_at)}</span>
          <span title="${formatTimestamp(latest.finished_at)}">Finished ${formatTimestamp(latest.finished_at)}</span>
          <span>${formatDuration(latest.duration_sec)}</span>
          <span>${esc(latest.host || "unknown host")}</span>
          ${pill(latest.trigger_source || "scheduled", "nightly-running", "border-color:color-mix(in srgb,var(--cyan) 40%,transparent)")}
        </div>
        <div style="display:grid;gap:6px">
          <div>${pill(`Sentry: ${sentry.count}`, sentry.count ? "nightly-action" : "nightly-ok")}${sentry.titles.length ? `<ul class="nightly-issues">${sentry.titles.map((t) => `<li>${esc(t)}</li>`).join("")}</ul>` : ""}</div>
          <div>${pill(`GitHub: ${github.count}`, github.count ? "nightly-action" : "nightly-ok")}${github.titles.length ? `<ul class="nightly-issues">${github.titles.map((t) => `<li>${esc(t)}</li>`).join("")}</ul>` : ""}</div>
          ${deploy ? `<div>${pill(`Deploy: ${deploy}`, String(deploy).toLowerCase().includes("ok") || String(deploy).toLowerCase().includes("success") ? "nightly-ok" : "nightly-action")}</div>` : ""}
        </div>
        ${latest.parent_run_id ? `<div class="nightly-meta">Retry of: <span style="color:var(--cyan)">${esc(latest.parent_run_id)}</span></div>` : ""}
        ${String(latest.status).toLowerCase() === "failed" && latest.error_detail ? `<pre style="margin:0;padding:8px;border-radius:6px;background:color-mix(in srgb,var(--red) 10%,transparent);border:1px solid color-mix(in srgb,var(--red) 40%,transparent);color:var(--red);font:11px/1.4 ui-monospace,SFMono-Regular,Menlo,monospace;white-space:pre-wrap">${esc(latest.error_detail)}</pre>` : ""}
        ${actionRow}
      </div>
    </details>`;
  }
  function historySection() {
    if (!state.history.length) return `<div class="nightly-history"><div class="nightly-empty">No run history yet.</div></div>`;
    return `<div class="nightly-history">
      <div class="nightly-history-title">History</div>
      <div style="overflow:auto">
        <table style="width:100%;border-collapse:collapse;font-size:10px">
          <thead><tr style="text-align:left;color:var(--text-dim)"><th>Status</th><th>Job</th><th>Host</th><th>Started</th><th>Duration</th><th>Items</th><th>Trigger</th><th>PR</th><th>Actions</th></tr></thead>
          <tbody>${state.history.map((row) => `<tr data-row-id="${esc(row.id)}" style="cursor:pointer;border-top:1px solid color-mix(in srgb,var(--blue) 20%,transparent);background:${String(row.status).toLowerCase() === "failed" ? "color-mix(in srgb,var(--red) 8%,transparent)" : "transparent"}">
            <td>${statusBadge(row.status)}</td><td>${esc(row.job_name || "nightly-job")}</td><td>${esc(row.host || "-")}</td><td title="${formatTimestamp(row.started_at)}">${timeAgo(row.started_at)}</td>
            <td>${formatDuration(row.duration_sec ?? Math.round((parseTs(row.finished_at) - parseTs(row.started_at)) / 1000))}</td><td title="processed / fixed">${num(row.processed_items)} / ${num(row.fixed_items)}</td>
            <td>${esc(row.trigger_source || "-")}</td><td>${row.pr_url ? `<a href="${esc(row.pr_url)}" target="_blank" rel="noreferrer" style="color:var(--cyan)" data-action="open-pr" data-url="${esc(row.pr_url)}">PR</a>` : "-"}</td>
            <td><button class="nightly-btn" data-action="retry" data-id="${esc(row.id)}">Retry</button></td></tr>`).join("")}</tbody>
        </table>
      </div>
      ${state.total > state.history.length ? `<div style="margin-top:8px"><button class="nightly-btn" data-action="load-more">Load more</button></div>` : ""}
    </div>`;
  }
  function definitionsSection() {
    const rows = state.definitions.length ? state.definitions.map((d) => `<div class="nightly-def-row" style="justify-content:space-between;gap:10px">
      <div style="display:grid;gap:2px"><span class="nightly-def-name">${esc(d.name || d.id)}</span><span class="nightly-meta">${esc(d.schedule || "-")} • ${esc(d.target_host || "-")}</span></div>
      <button class="nightly-btn ${d.enabled ? "nightly-btn-save" : "nightly-btn-cancel"}" data-action="toggle-def" data-id="${esc(d.id)}">${d.enabled ? "ON" : "OFF"}</button></div>`).join("") : `<div class="nightly-empty">No job definitions configured.</div>`;
    return `<div class="nightly-defs"><div style="display:flex;align-items:center;justify-content:space-between"><div class="nightly-history-title">Job Definitions</div><button class="nightly-btn nightly-btn-add" data-action="show-create" title="Add job">+</button></div>${rows}</div>`;
  }
  function draw() {
    const root = byId("nightly-jobs-content");
    if (!root) return;
    const autoFixDef = state.definitions.find((d) => String(d.id || "").toLowerCase() === "mirrorbuddy" || String(d.name || "").toLowerCase().includes("mirrorbuddy") || String(d.script_path || "").toLowerCase().includes("mirrorbuddy"));
    root.innerHTML = state.unavailable ? `<div class="nightly-empty">Nightly jobs unavailable.</div>` : `
      <div class="nightly-head" style="justify-content:space-between;align-items:flex-start">
        <div class="nightly-head">
          ${statusBadge(state.latest?.status)}
          <span class="nightly-meta" title="${formatTimestamp(state.latest?.finished_at || state.latest?.started_at)}">Last run: ${timeAgo(state.latest?.finished_at || state.latest?.started_at)}</span>
          <span class="nightly-meta">Duration: ${formatDuration(state.latest?.duration_sec)}</span>
          ${state.latest?.host ? pill(state.latest.host, "nightly-running", "color:var(--text)") : ""}
          <button class="nightly-badge ${autoFixDef?.run_fixes ? "nightly-ok" : "nightly-failed"}" data-action="toggle-fixes">Auto-fix: ${autoFixDef?.run_fixes ? "ON" : "OFF"}</button>
        </div>
        <div style="display:flex;gap:6px;flex-wrap:wrap"><button class="nightly-btn" data-action="run-now">Run Now</button><button class="nightly-btn" data-action="refresh">Refresh</button></div>
      </div>
      ${latestSection()}${historySection()}${definitionsSection()}`;
    if (!root.dataset.bound) {
      root.dataset.bound = "1";
      root.addEventListener("click", async (event) => {
        const action = event.target.closest("[data-action]"), row = action ? null : event.target.closest("[data-row-id]");
        if (row && window._njShowDetail) return void window._njShowDetail(row.dataset.rowId, row);
        if (!action) return;
        event.preventDefault();
        const id = action.dataset.id;
        try {
          if (action.dataset.action === "refresh") await refreshWidget();
          if (action.dataset.action === "load-more") await loadMore();
          if (action.dataset.action === "run-now") { await api("/api/nightly/jobs/trigger", "POST", { project_id: "mirrorbuddy" }); toast("Nightly run triggered", "", "success"); await refreshWidget(); }
          if (action.dataset.action === "toggle-fixes") { const def = state.definitions.find((d) => String(d.id || "").toLowerCase() === "mirrorbuddy" || String(d.name || "").toLowerCase().includes("mirrorbuddy") || String(d.script_path || "").toLowerCase().includes("mirrorbuddy")); await api("/api/nightly/config/mirrorbuddy", "PUT", { run_fixes: def?.run_fixes ? 0 : 1 }); await refreshWidget(); }
          if (action.dataset.action === "retry") { await api(`/api/nightly/jobs/${encodeURIComponent(id)}/retry`, "POST"); toast("Retry queued", `Run ${id}`, "success"); await refreshWidget(); }
          if (action.dataset.action === "logs" && window._njShowLogs) window._njShowLogs(id);
          if (action.dataset.action === "open-pr") window.open(action.dataset.url, "_blank", "noopener");
          if (action.dataset.action === "parent" && window._njShowDetail) window._njShowDetail(id, Array.from(root.querySelectorAll("[data-row-id]")).find((el) => el.dataset.rowId === id) || null);
          if (action.dataset.action === "toggle-def") { await api(`/api/nightly/jobs/definitions/${encodeURIComponent(id)}/toggle`, "POST"); await refreshWidget(); }
          if (action.dataset.action === "show-create") window._njShowCreate();
          if (action.dataset.action === "cancel-create") root.querySelector(".nightly-create-form")?.remove();
          if (action.dataset.action === "create") await window._njCreate();
        } catch (err) {
          toast("Nightly jobs error", err.message, "error");
        }
      });
    }
  }
  window._njCreate = async function () {
    const name = byId("nj-name")?.value.trim(), script_path = byId("nj-script")?.value.trim();
    if (!name || !script_path) return toast("Missing fields", "Name and script path are required", "error");
    await api("/api/nightly/jobs/create", "POST", { name, script_path, schedule: byId("nj-schedule")?.value || "0 3 * * *", target_host: byId("nj-host")?.value || "local", description: byId("nj-desc")?.value || "" });
    byId("nightly-jobs-content")?.querySelector(".nightly-create-form")?.remove();
    toast("Nightly job created", name, "success");
    await refreshWidget();
  };
  window._njShowCreate = function () {
    const root = byId("nightly-jobs-content");
    if (!root) return;
    const form = root.querySelector(".nightly-create-form");
    if (form) form.remove(); else root.insertAdjacentHTML("afterbegin", createForm());
  };
  window.renderNightlyJobs = function renderNightlyJobs(payload) {
    state.unavailable = !payload || payload.ok === false;
    state.latest = payload?.latest || null;
    state.history = Array.isArray(payload?.history) ? payload.history : [];
    state.definitions = Array.isArray(payload?.definitions) ? payload.definitions : [];
    state.page = num(payload?.page) || 1;
    state.perPage = num(payload?.per_page) || 50;
    state.total = num(payload?.total) || state.history.length;
    draw();
  };
})();
