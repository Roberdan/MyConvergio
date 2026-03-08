(function () {
  const NEW_PROJECT_VALUE = "__new_project__";
  const state = { projects: [], rootId: "repo-selector-root", getActiveState: () => null, updateActiveState: () => null };
  const byId = (id) => document.getElementById(id);
  const esc = (v) =>
    String(v ?? "").replace(/[&<>"']/g, (m) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[m]);

  const jsonFetch = async (url, opts = {}) => {
    const res = await fetch(url, opts);
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    return res.json();
  };

  function ensureRoot() {
    const root = byId(state.rootId);
    if (!root || root.dataset.ready === "1") return root;
    root.className = "repo-selector-wrap";
    root.innerHTML = `
      <label class="repo-selector-label" for="chat-project-select">Project</label>
      <select id="chat-project-select" class="chat-select repo-selector-select" aria-label="Project selector"></select>
      <button id="chat-project-new" class="widget-action-btn repo-selector-btn" type="button">New Project</button>
      <dialog id="chat-new-project-modal" class="repo-modal">
        <form id="chat-new-project-form" method="dialog" class="repo-modal-form">
          <h4>Create New Project</h4>
          <label>Name<input id="repo-name" name="name" required maxlength="100" /></label>
          <label>Visibility
            <select id="repo-visibility" name="visibility">
              <option value="private">private</option><option value="public">public</option>
            </select>
          </label>
          <label>Template<input id="repo-template" name="template" placeholder="owner/template-repo" /></label>
          <div class="repo-modal-actions">
            <button id="repo-create-confirm" class="widget-action-btn" type="submit">Create</button>
            <button id="repo-create-cancel" class="widget-action-btn" type="button">Cancel</button>
          </div>
          <div id="repo-create-status" class="repo-create-status"></div>
        </form>
      </dialog>`;
    root.dataset.ready = "1";
    bindEvents();
    return root;
  }

  function projectById(projectId) {
    return state.projects.find((p) => String(p.id) === String(projectId)) || null;
  }

  function renderProjects(selectedId = "") {
    const sel = byId("chat-project-select");
    if (!sel) return;
    const options = ['<option value="">project:auto</option>']
      .concat(state.projects.map((p) => `<option value="${esc(p.id)}">${esc(p.name || p.path || p.id)}</option>`))
      .concat(`<option value="${NEW_PROJECT_VALUE}">+ New Project</option>`);
    sel.innerHTML = options.join("");
    sel.value = selectedId && projectById(selectedId) ? String(selectedId) : "";
  }

  async function loadProjects() {
    const payload = await jsonFetch("/api/projects");
    state.projects = Array.isArray(payload) ? payload : [];
    const selectedId = state.getActiveState?.()?.project_id || "";
    renderProjects(selectedId);
  }

  function setStatus(message) {
    const el = byId("repo-create-status");
    if (el) el.textContent = message;
  }

  function openModal() {
    const modal = byId("chat-new-project-modal");
    if (!modal) return;
    setStatus("");
    if (typeof modal.showModal === "function") modal.showModal();
    else modal.setAttribute("open", "open");
  }

  function closeModal() {
    const modal = byId("chat-new-project-modal");
    if (!modal) return;
    if (typeof modal.close === "function") modal.close();
    else modal.removeAttribute("open");
  }

  function selectProject(projectId) {
    if (projectId === NEW_PROJECT_VALUE) {
      openModal();
      return;
    }
    const project = projectById(projectId);
    state.updateActiveState?.({ project_id: project ? String(project.id) : "", project_name: project?.name || "" });
  }

  async function createRepo(formData) {
    const name = String(formData.get("name") || "").trim();
    const visibility = String(formData.get("visibility") || "private").toLowerCase();
    const template = String(formData.get("template") || "").trim();
    if (!name) throw new Error("missing repository name");
    const payload = {
      name,
      private: visibility !== "public",
      template: template || null,
      description: "Created from Convergio dashboard chat CAPTURE flow",
    };
    const created = await jsonFetch("/api/github/repo/create", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(payload),
    });
    if (!created.ok) throw new Error(created.error || "repository creation failed");
    const repo = created.repo || {};
    const nameWithOwner = String(repo.nameWithOwner || name);
    const existing = state.projects.find((p) => String(p.name) === nameWithOwner);
    if (!existing) state.projects.unshift({ id: `repo:${nameWithOwner}`, name: nameWithOwner, path: repo.url || "" });
    renderProjects(`repo:${nameWithOwner}`);
    state.updateActiveState?.({ project_id: `repo:${nameWithOwner}`, project_name: nameWithOwner });
    closeModal();
    return created;
  }

  function captureMetadata(tabState) {
    if (!tabState || tabState.phase !== "CAPTURE") return {};
    return { project_id: tabState.project_id || "", project_name: tabState.project_name || "" };
  }

  function syncFromState(tabState) {
    const root = ensureRoot();
    if (!root) return;
    root.hidden = !tabState || tabState.phase !== "CAPTURE";
    renderProjects(tabState?.project_id || "");
  }

  function hide() {
    const root = ensureRoot();
    if (root) root.hidden = true;
  }

  function bindEvents() {
    byId("chat-project-select")?.addEventListener("change", (event) => selectProject(String(event.target.value || "")));
    byId("chat-project-new")?.addEventListener("click", openModal);
    byId("repo-create-cancel")?.addEventListener("click", closeModal);
    byId("chat-new-project-form")?.addEventListener("submit", async (event) => {
      event.preventDefault();
      setStatus("creating...");
      try {
        await createRepo(new FormData(event.target));
      } catch (err) {
        setStatus(String(err?.message || "create failed"));
      }
    });
  }

  async function init(opts = {}) {
    state.rootId = opts.rootId || state.rootId;
    state.getActiveState = opts.getActiveState || state.getActiveState;
    state.updateActiveState = opts.updateActiveState || state.updateActiveState;
    ensureRoot();
    try {
      await loadProjects();
    } catch {
      state.projects = [];
      renderProjects("");
    }
    syncFromState(state.getActiveState?.());
  }

  window.repoSelector = { init, hide, syncFromState, selectProject, createRepo, captureMetadata };
})();
