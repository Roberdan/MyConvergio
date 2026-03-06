/* peer-crud.js — Peer CRUD modal form + delete + SSH check + discovery */

function showPeerForm(mode = "create", data = null) {
  const existing = document.getElementById("peer-form-overlay");
  if (existing) existing.remove();
  const overlay = document.createElement("div");
  overlay.id = "peer-form-overlay";
  overlay.className = "peer-overlay";
  const title =
    mode === "create" ? "Add Peer" : `Edit ${data?.peer_name || ""}`;
  const nameRO = mode === "edit" ? "readonly" : "";
  const d = data || {};
  overlay.innerHTML = `<div class="peer-modal">
    <h3>${title}</h3>
    <form id="peer-form" autocomplete="off">
      <label>Name<input name="peer_name" required pattern="^[a-zA-Z0-9_.-]+$" value="${d.peer_name || ""}" ${nameRO}></label>
      <label>SSH Alias<input name="ssh_alias" required value="${d.ssh_alias || ""}"></label>
      <label>User<input name="user" required value="${d.user || ""}"></label>
      <label>OS<select name="os"><option value="macos"${d.os === "macos" ? " selected" : ""}>macOS</option><option value="linux"${d.os === "linux" ? " selected" : ""}>Linux</option></select></label>
      <label>Tailscale IP<input name="tailscale_ip" pattern="^100\\.\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}$" value="${d.tailscale_ip || ""}"></label>
      <label>DNS Name<input name="dns_name" value="${d.dns_name || ""}"></label>
      <label>Role<select name="role"><option value="worker"${d.role === "worker" ? " selected" : ""}>Worker</option><option value="coordinator"${d.role === "coordinator" ? " selected" : ""}>Coordinator</option><option value="hybrid"${d.role === "hybrid" ? " selected" : ""}>Hybrid</option></select></label>
      <label>Status<select name="status"><option value="active"${d.status === "active" ? " selected" : ""}>Active</option><option value="inactive"${d.status === "inactive" ? " selected" : ""}>Inactive</option></select></label>
      <label>MAC Address<input name="mac_address" pattern="^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$" value="${d.mac_address || ""}"></label>
      <label>Engine<select name="default_engine"><option value="">—</option><option value="copilot"${d.default_engine === "copilot" ? " selected" : ""}>Copilot</option><option value="claude"${d.default_engine === "claude" ? " selected" : ""}>Claude</option><option value="opencode"${d.default_engine === "opencode" ? " selected" : ""}>OpenCode</option><option value="ollama"${d.default_engine === "ollama" ? " selected" : ""}>Ollama</option></select></label>
      <label>Model<input name="default_model" value="${d.default_model || ""}"></label>
      <div class="peer-form-actions">
        <button type="button" id="peer-ssh-btn" class="btn-secondary">Test SSH</button>
        <span id="peer-ssh-status"></span>
        <span class="spacer"></span>
        <button type="button" onclick="closePeerForm()">Cancel</button>
        <button type="submit" class="btn-primary">Save</button>
      </div>
    </form></div>`;
  document.body.appendChild(overlay);
  overlay.addEventListener("click", (e) => {
    if (e.target === overlay) closePeerForm();
  });
  document.getElementById("peer-form").addEventListener("submit", (e) => {
    e.preventDefault();
    savePeer(mode);
  });
  document
    .getElementById("peer-ssh-btn")
    .addEventListener("click", () => testSSH());
}

function closePeerForm() {
  const el = document.getElementById("peer-form-overlay");
  if (el) el.remove();
}

async function savePeer(mode) {
  const form = document.getElementById("peer-form");
  if (!form.checkValidity()) {
    form.reportValidity();
    return;
  }
  const fd = new FormData(form);
  const body = Object.fromEntries(fd.entries());
  const url =
    mode === "create"
      ? "/api/peers"
      : `/api/peers/${encodeURIComponent(body.peer_name)}`;
  const method = mode === "create" ? "POST" : "PUT";
  try {
    const res = await fetch(url, {
      method,
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(body),
    });
    const json = await res.json();
    if (json.error) {
      alert(json.error);
      return;
    }
    closePeerForm();
    if (typeof refreshMesh === "function") refreshMesh();
  } catch (e) {
    alert("Save failed: " + e.message);
  }
}

async function testSSH() {
  const form = document.getElementById("peer-form");
  const fd = new FormData(form);
  const st = document.getElementById("peer-ssh-status");
  st.textContent = "⏳ Testing...";
  try {
    const res = await fetch("/api/peers/ssh-check", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        ssh_alias: fd.get("ssh_alias"),
        tailscale_ip: fd.get("tailscale_ip"),
        user: fd.get("user"),
      }),
    });
    const json = await res.json();
    st.textContent = json.ok
      ? `✅ ${json.latency_ms}ms`
      : `❌ ${json.error || "Failed"}`;
    st.className = json.ok ? "ssh-ok" : "ssh-fail";
  } catch (e) {
    st.textContent = "❌ Error";
    st.className = "ssh-fail";
  }
}

function showDeleteDialog(peerName) {
  const existing = document.getElementById("peer-form-overlay");
  if (existing) existing.remove();
  const overlay = document.createElement("div");
  overlay.id = "peer-form-overlay";
  overlay.className = "peer-overlay";
  overlay.innerHTML = `<div class="peer-modal peer-modal-sm">
    <h3>Delete ${peerName}</h3>
    <div class="delete-options">
      <label><input type="radio" name="delmode" value="soft" checked> Soft (set inactive)</label>
      <label><input type="radio" name="delmode" value="hard"> Hard (remove entirely)</label>
    </div>
    <div id="hard-confirm" style="display:none">
      <p>Type <b>ELIMINA</b> to confirm:</p>
      <input id="confirm-input" autocomplete="off">
    </div>
    <div class="peer-form-actions">
      <button type="button" onclick="closePeerForm()">Cancel</button>
      <button type="button" id="do-delete-btn" class="btn-danger">Delete</button>
    </div></div>`;
  document.body.appendChild(overlay);
  overlay.addEventListener("click", (e) => {
    if (e.target === overlay) closePeerForm();
  });
  overlay.querySelectorAll("input[name=delmode]").forEach((r) =>
    r.addEventListener("change", () => {
      document.getElementById("hard-confirm").style.display =
        r.value === "hard" && r.checked ? "" : "none";
    }),
  );
  document
    .getElementById("do-delete-btn")
    .addEventListener("click", () => deletePeer(peerName));
}

async function deletePeer(name) {
  const mode =
    document.querySelector("input[name=delmode]:checked")?.value || "soft";
  if (mode === "hard") {
    const v = document.getElementById("confirm-input")?.value;
    if (v !== "ELIMINA") {
      alert("Type ELIMINA to confirm hard delete");
      return;
    }
  }
  try {
    const res = await fetch(
      `/api/peers/${encodeURIComponent(name)}?mode=${mode}`,
      { method: "DELETE" },
    );
    const json = await res.json();
    if (json.error) {
      alert(json.error);
      return;
    }
    closePeerForm();
    if (typeof refreshMesh === "function") refreshMesh();
  } catch (e) {
    alert("Delete failed: " + e.message);
  }
}

async function showDiscoverOverlay() {
  const existing = document.getElementById("peer-form-overlay");
  if (existing) existing.remove();
  const overlay = document.createElement("div");
  overlay.id = "peer-form-overlay";
  overlay.className = "peer-overlay";
  overlay.innerHTML = `<div class="peer-modal"><h3>Discover Peers</h3><p>Scanning Tailscale network...</p></div>`;
  document.body.appendChild(overlay);
  overlay.addEventListener("click", (e) => {
    if (e.target === overlay) closePeerForm();
  });
  try {
    const res = await fetch("/api/peers/discover");
    const json = await res.json();
    const list = json.discovered || [];
    if (!list.length) {
      overlay.querySelector(".peer-modal").innerHTML =
        '<h3>Discover Peers</h3><p>No new peers found.</p><button onclick="closePeerForm()">Close</button>';
      return;
    }
    let html = '<h3>Discover Peers</h3><div class="discover-list">';
    const esc = (s) =>
      s
        .replace(/&/g, "&amp;")
        .replace(/</g, "&lt;")
        .replace(/>/g, "&gt;")
        .replace(/"/g, "&quot;");
    list.forEach((p, i) => {
      html += `<label class="discover-item"><input type="checkbox" data-idx="${i}" checked>
        <b>${esc(p.hostname)}</b> — ${esc(p.tailscale_ip)} (${esc(p.os)})</label>`;
    });
    html +=
      '</div><div class="peer-form-actions"><button onclick="closePeerForm()">Cancel</button>';
    html +=
      '<button class="btn-primary" id="add-discovered-btn">Add Selected</button></div>';
    overlay.querySelector(".peer-modal").innerHTML = html;
    overlay
      .querySelector("#add-discovered-btn")
      .addEventListener("click", async () => {
        const checks = overlay.querySelectorAll("input[type=checkbox]:checked");
        const errors = [];
        for (const cb of checks) {
          const p = list[cb.dataset.idx];
          try {
            const r = await fetch("/api/peers", {
              method: "POST",
              headers: { "Content-Type": "application/json" },
              body: JSON.stringify({
                peer_name: p.hostname,
                ssh_alias: p.dns_name || p.tailscale_ip,
                user: "roberdan",
                os: p.os,
                role: "worker",
                tailscale_ip: p.tailscale_ip,
                dns_name: p.dns_name,
                status: "active",
              }),
            });
            const j = await r.json();
            if (j.error) errors.push(`${p.hostname}: ${j.error}`);
          } catch (err) {
            errors.push(`${p.hostname}: ${err.message}`);
          }
        }
        if (errors.length) alert("Some peers failed:\n" + errors.join("\n"));
        closePeerForm();
        if (typeof refreshMesh === "function") refreshMesh();
      });
  } catch (e) {
    overlay.querySelector(".peer-modal").innerHTML =
      `<h3>Error</h3><p>${e.message}</p><button onclick="closePeerForm()">Close</button>`;
  }
}
