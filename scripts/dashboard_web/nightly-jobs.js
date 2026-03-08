(function () {
  const byId = (id) => document.getElementById(id);
  const esc = (value) =>
    String(value ?? "").replace(/[&<>"']/g, (m) => ({
      "&": "&amp;",
      "<": "&lt;",
      ">": "&gt;",
      '"': "&quot;",
      "'": "&#39;",
    })[m]);

  function parseTimestamp(value) {
    if (!value) return 0;
    if (typeof value === "number") return value > 1e12 ? value : value * 1000;
    const parsed = Date.parse(String(value));
    return Number.isFinite(parsed) ? parsed : 0;
  }

  function timeAgo(value) {
    const ts = parseTimestamp(value);
    if (!ts) return "n/a";
    const sec = Math.max(0, Math.floor((Date.now() - ts) / 1000));
    if (sec < 60) return `${sec}s ago`;
    if (sec < 3600) return `${Math.floor(sec / 60)}m ago`;
    if (sec < 86400) return `${Math.floor(sec / 3600)}h ago`;
    return `${Math.floor(sec / 86400)}d ago`;
  }

  function statusBadge(status) {
    const normalized = String(status || "unknown").toLowerCase();
    if (normalized === "ok") return '<span class="nightly-badge nightly-ok">OK</span>';
    if (normalized === "running") return '<span class="nightly-badge nightly-running">RUNNING</span>';
    if (normalized === "action_required") return '<span class="nightly-badge nightly-action">ACTION</span>';
    return '<span class="nightly-badge nightly-failed">FAILED</span>';
  }

  function renderHistory(history) {
    if (!history.length) return '<div class="nightly-empty">No run history yet.</div>';
    return history
      .slice(0, 5)
      .map((row) => {
        const pr = row.pr_url ? `<a href="${esc(row.pr_url)}" target="_blank" rel="noreferrer">PR</a>` : "";
        const name = row.job_name ? `<span class="nightly-job-name">${esc(row.job_name)}</span>` : "";
        return `<div class="nightly-history-row">
          <span>${statusBadge(row.status)}</span>
          <span class="nightly-history-meta">${name}</span>
          <span class="nightly-history-meta">${timeAgo(row.started_at)}</span>
          <span class="nightly-history-meta">${Number(row.processed_items || 0)} proc</span>
          <span class="nightly-history-link">${pr}</span>
        </div>`;
      })
      .join("");
  }

  function renderDefinitions(definitions) {
    if (!definitions || !definitions.length) return "";
    return `<div class="nightly-defs">
      <div class="nightly-history-title">Configured jobs</div>
      ${definitions.map((d) => `<div class="nightly-def-row">
        <span class="nightly-def-name">${esc(d.name)}</span>
        <span class="nightly-meta">${esc(d.schedule)}</span>
        <span class="nightly-meta">${esc(d.target_host)}</span>
        <span class="nightly-badge ${d.enabled ? 'nightly-ok' : 'nightly-failed'}">${d.enabled ? 'ON' : 'OFF'}</span>
      </div>`).join("")}
    </div>`;
  }

  function showCreateForm() {
    const root = byId("nightly-jobs-content");
    if (!root) return;
    const existing = root.querySelector(".nightly-create-form");
    if (existing) { existing.remove(); return; }
    const form = document.createElement("div");
    form.className = "nightly-create-form";
    form.innerHTML = `
      <div class="nightly-history-title">New Nightly Job</div>
      <input id="nj-name" placeholder="Job name (e.g. db-backup)" class="nightly-input" />
      <input id="nj-script" placeholder="Script path (e.g. scripts/backup.sh)" class="nightly-input" />
      <input id="nj-schedule" placeholder="Cron schedule (default: 0 3 * * *)" class="nightly-input" value="0 3 * * *" />
      <input id="nj-host" placeholder="Target host (default: local)" class="nightly-input" value="local" />
      <input id="nj-desc" placeholder="Description (optional)" class="nightly-input" />
      <div class="nightly-form-actions">
        <button class="nightly-btn nightly-btn-save" onclick="window._njCreate()">Create</button>
        <button class="nightly-btn nightly-btn-cancel" onclick="this.closest('.nightly-create-form').remove()">Cancel</button>
      </div>
    `;
    root.prepend(form);
  }

  window._njCreate = async function () {
    const name = (byId("nj-name")?.value || "").trim();
    const script_path = (byId("nj-script")?.value || "").trim();
    if (!name || !script_path) { alert("Name and script path are required"); return; }
    const body = {
      name,
      script_path,
      schedule: byId("nj-schedule")?.value || "0 3 * * *",
      target_host: byId("nj-host")?.value || "local",
      description: byId("nj-desc")?.value || "",
    };
    try {
      const res = await fetch("/api/nightly/jobs/create", { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify(body) });
      const data = await res.json();
      if (data.ok) {
        const form = document.querySelector(".nightly-create-form");
        if (form) form.remove();
        if (typeof refreshAll === "function") refreshAll();
      } else {
        alert(data.error || "Failed to create job");
      }
    } catch (err) {
      alert("Network error: " + err.message);
    }
  };

  window.renderNightlyJobs = function renderNightlyJobs(payload) {
    const root = byId("nightly-jobs-content");
    if (!root) return;
    if (!payload || payload.ok === false) {
      root.innerHTML = '<div class="nightly-empty">Nightly jobs unavailable.</div>';
      return;
    }
    const latest = payload.latest;
    const history = Array.isArray(payload.history) ? payload.history : [];
    const definitions = Array.isArray(payload.definitions) ? payload.definitions : [];
    const addBtn = '<button class="nightly-btn nightly-btn-add" onclick="window._njShowCreate()" title="Add job">+</button>';

    if (!latest) {
      root.innerHTML = `<div class="nightly-empty">No nightly runs recorded yet. ${addBtn}</div>${renderDefinitions(definitions)}`;
      return;
    }
    root.innerHTML = `
      <div class="nightly-latest">
        <div class="nightly-head">
          ${statusBadge(latest.status)}
          <span class="nightly-meta">${esc(latest.job_name || latest.host || "unknown")}</span>
          <span class="nightly-meta">${timeAgo(latest.started_at)}</span>
          ${addBtn}
        </div>
        <div class="nightly-summary">${esc(latest.summary || "No summary")}</div>
        <div class="nightly-metrics">
          <span><b>${Number(latest.processed_items || 0)}</b> processed</span>
          <span><b>${Number(latest.fixed_items || 0)}</b> fixed</span>
        </div>
      </div>
      <div class="nightly-history">
        <div class="nightly-history-title">Recent runs</div>
        ${renderHistory(history)}
      </div>
      ${renderDefinitions(definitions)}
    `;
  };

  window._njShowCreate = showCreateForm;
})();
