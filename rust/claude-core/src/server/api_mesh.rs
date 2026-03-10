use super::state::{query_rows, ApiError, ServerState};
use axum::extract::{Query, State};
use axum::routing::{get, post};
use axum::{Json, Router};
use serde_json::{json, Value};
use std::collections::HashMap;

pub fn router() -> Router<ServerState> {
    Router::new()
        .route("/api/mesh", get(api_mesh))
        .route("/api/mesh/sync-status", get(api_mesh_sync_status))
        .route("/api/mesh/init", post(api_mesh_init))
        .route("/api/mesh/action", get(handle_mesh_action))
}

fn parse_peers_conf(content: &str) -> HashMap<String, HashMap<String, String>> {
    let mut peers: HashMap<String, HashMap<String, String>> = HashMap::new();
    let mut current = String::new();
    for raw in content.lines() {
        let line = raw.split('#').next().unwrap_or("").trim();
        if line.is_empty() { continue; }
        if line.starts_with('[') && line.ends_with(']') {
            current = line.trim_start_matches('[').trim_end_matches(']').to_string();
            // Skip [mesh] section — it's config, not a peer node
            if current == "mesh" { current.clear(); continue; }
            peers.insert(current.clone(), HashMap::new());
            continue;
        }
        if current.is_empty() { continue; }
        if let Some((k, v)) = line.split_once('=') {
            if let Some(fields) = peers.get_mut(&current) {
                fields.insert(k.trim().to_string(), v.trim().to_string());
            }
        }
    }
    peers
}

fn detect_local_identity() -> (String, String) {
    let hostname = std::process::Command::new("hostname").arg("-s")
        .output().ok()
        .and_then(|o| String::from_utf8(o.stdout).ok())
        .map(|s| s.trim().to_lowercase())
        .unwrap_or_default();
    let ts_ip = std::process::Command::new("tailscale").args(["ip", "-4"])
        .output().ok()
        .and_then(|o| String::from_utf8(o.stdout).ok())
        .map(|s| s.trim().to_owned())
        .unwrap_or_default();
    (hostname, ts_ip)
}

fn is_local_peer(hostname: &str, ts_ip: &str, fields: &HashMap<String, String>) -> bool {
    // Match by Tailscale IP (most reliable)
    if !ts_ip.is_empty() {
        if let Some(peer_ip) = fields.get("tailscale_ip") {
            if peer_ip == ts_ip { return true; }
        }
    }
    // Match by hostname substring in dns_name or ssh_alias
    if !hostname.is_empty() {
        for key in &["dns_name", "ssh_alias"] {
            if let Some(val) = fields.get(*key) {
                let val_l = val.to_lowercase();
                if val_l.contains(hostname) || hostname.contains(&val_l) { return true; }
            }
        }
    }
    false
}

async fn api_mesh(State(state): State<ServerState>) -> Result<Json<Value>, ApiError> {
    let db = state.open_db()?;
    let rows = query_rows(
        db.connection(),
        "SELECT peer_name, last_seen, load_json, capabilities FROM peer_heartbeats WHERE peer_name IS NOT NULL AND peer_name != ''",
        [],
    )?;
    // Load peers.conf for static enrichment
    let conf_path = state.db_path.parent()
        .and_then(|d| d.parent())
        .map(|base| base.join("config/peers.conf"))
        .unwrap_or_default();
    let conf = std::fs::read_to_string(&conf_path).unwrap_or_default();
    let peer_conf = parse_peers_conf(&conf);
    let (local_host, local_ts_ip) = detect_local_identity();

    // Build lookup: peer_name -> heartbeat row
    let mut hb_map: HashMap<String, Value> = HashMap::new();
    for row in rows {
        if let Some(name) = row.get("peer_name").and_then(Value::as_str) {
            if !name.is_empty() { hb_map.insert(name.to_owned(), row); }
        }
    }

    let now = std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH)
        .map(|d| d.as_secs_f64()).unwrap_or(0.0);

    // Merge: peers.conf (authority) + heartbeat DB (dynamic)
    let mut peers: Vec<Value> = Vec::new();
    for (name, fields) in &peer_conf {
        let status = fields.get("status").map(|s| s.as_str()).unwrap_or("active");
        if status == "inactive" { continue; }

        let mut obj = serde_json::Map::new();
        obj.insert("peer_name".into(), json!(name));
        obj.insert("os".into(), json!(fields.get("os").cloned().unwrap_or_else(|| "unknown".into())));
        obj.insert("role".into(), json!(fields.get("role").cloned().unwrap_or_else(|| "worker".into())));
        obj.insert("capabilities".into(), json!(fields.get("capabilities").cloned().unwrap_or_default()));
        if let Some(ip) = fields.get("tailscale_ip") { obj.insert("tailscale_ip".into(), json!(ip)); }
        if let Some(dns) = fields.get("dns_name") { obj.insert("dns_name".into(), json!(dns)); }
        if let Some(alias) = fields.get("ssh_alias") { obj.insert("ssh_alias".into(), json!(alias)); }
        if let Some(mac) = fields.get("mac_address") { obj.insert("mac_address".into(), json!(mac)); }

        let is_local = is_local_peer(&local_host, &local_ts_ip, fields);
        obj.insert("is_local".into(), json!(is_local));

        // Merge heartbeat dynamic data
        if let Some(hb) = hb_map.remove(name) {
            let seen = hb.get("last_seen").and_then(Value::as_f64).unwrap_or(0.0);
            obj.insert("last_seen".into(), json!(seen));
            obj.insert("is_online".into(), json!(now - seen < 3600.0));
            if let Some(load_str) = hb.get("load_json").and_then(Value::as_str) {
                if let Ok(load) = serde_json::from_str::<Value>(load_str) {
                    if let Some(load_obj) = load.as_object() {
                        for (k, v) in load_obj { obj.insert(k.clone(), v.clone()); }
                    }
                }
            }
            // DB capabilities override if richer
            if let Some(db_caps) = hb.get("capabilities").and_then(Value::as_str) {
                if !db_caps.is_empty() { obj.insert("capabilities".into(), json!(db_caps)); }
            }
        } else {
            obj.insert("is_online".into(), json!(false));
            obj.insert("last_seen".into(), json!(0));
        }
        if !obj.contains_key("cpu") { obj.insert("cpu".into(), json!(0)); }
        if !obj.contains_key("active_tasks") { obj.insert("active_tasks".into(), json!(0)); }

        let mut hostname_aliases: Vec<String> = Vec::new();
        if let Some(alias) = fields.get("ssh_alias") { hostname_aliases.push(alias.clone()); }
        if let Some(dns) = fields.get("dns_name") { hostname_aliases.push(dns.clone()); }
        obj.insert("hostname_aliases".into(), json!(hostname_aliases));

        peers.push(Value::Object(obj));
    }

    // Include any heartbeat-only peers not in peers.conf (shouldn't happen, but safe)
    for (name, mut hb) in hb_map {
        let seen = hb.get("last_seen").and_then(Value::as_f64).unwrap_or(0.0);
        let obj = hb.as_object_mut().unwrap();
        if !obj.contains_key("is_online") { obj.insert("is_online".into(), json!(now - seen < 3600.0)); }
        if !obj.contains_key("is_local") { obj.insert("is_local".into(), json!(name.to_lowercase().contains(&local_host))); }
        if !obj.contains_key("os") { obj.insert("os".into(), json!("unknown")); }
        if !obj.contains_key("cpu") { obj.insert("cpu".into(), json!(0)); }
        if !obj.contains_key("active_tasks") { obj.insert("active_tasks".into(), json!(0)); }
        if !obj.contains_key("role") {
            let role = if name.contains("m3max") || name.contains("local") { "coordinator" } else { "worker" };
            obj.insert("role".into(), json!(role));
        }
        if let Some(load_str) = obj.remove("load_json").and_then(|v| v.as_str().map(str::to_owned)) {
            if let Ok(load) = serde_json::from_str::<Value>(&load_str) {
                if let Some(load_obj) = load.as_object() {
                    for (k, v) in load_obj { obj.insert(k.clone(), v.clone()); }
                }
            }
        }
        peers.push(hb);
    }

    Ok(Json(Value::Array(peers)))
}

async fn api_mesh_sync_status(State(state): State<ServerState>) -> Result<Json<Value>, ApiError> {
    let db = state.open_db()?;
    let pending = query_rows(
        db.connection(),
        "SELECT status, COUNT(*) AS count FROM mesh_events GROUP BY status",
        [],
    )
    .unwrap_or_default();
    let latencies = query_rows(
        db.connection(),
        "SELECT COALESCE(last_latency_ms,0) AS latency_ms FROM mesh_sync_stats WHERE last_latency_ms IS NOT NULL",
        [],
    )
    .unwrap_or_default();
    let mut samples: Vec<i64> = latencies
        .iter()
        .filter_map(|row| row.get("latency_ms").and_then(Value::as_i64))
        .collect();
    samples.sort_unstable();
    let percentile = |p: f64| -> i64 {
        if samples.is_empty() {
            return 0;
        }
        let idx = ((samples.len() - 1) as f64 * p).round() as usize;
        samples[idx]
    };
    Ok(Json(json!({
        "ok": true,
        "events": pending,
        "latency": {
            "db_sync_p50_ms": percentile(0.50),
            "db_sync_p99_ms": percentile(0.99),
            "targets": {"lan_p50_lt_ms": 10, "wan_p99_lt_ms": 100}
        }
    })))
}

async fn api_mesh_init() -> Json<Value> {
    Json(json!({"status": "ok", "daemons_restarted": [], "hosts_needing_normalization": 0}))
}

async fn handle_mesh_action(Query(qs): Query<HashMap<String, String>>) -> Json<Value> {
    let action = qs.get("action").cloned().unwrap_or_default();
    let peer = qs.get("peer").cloned().unwrap_or_default();
    if action.is_empty() || peer.is_empty() {
        return Json(json!({"error": "missing action or peer", "output": ""}));
    }
    match action.as_str() {
        "add-node" => {
            let ip = qs.get("ip").cloned().unwrap_or_default();
            let os = qs.get("os").cloned().unwrap_or("linux".into());
            let role = qs.get("role").cloned().unwrap_or("worker".into());
            let caps = qs.get("caps").cloned().unwrap_or("claude,copilot".into());
            let ssh = qs.get("ssh").cloned().unwrap_or_default();
            if ip.is_empty() {
                return Json(json!({"error": "Tailscale IP is required"}));
            }
            // Append to peers.conf
            let conf_path = std::env::var("HOME").unwrap_or_default() + "/.claude/config/peers.conf";
            let entry = format!(
                "\n[{peer}]\nssh_alias={ssh}\nos={os}\ntailscale_ip={ip}\ncapabilities={caps}\nrole={role}\nstatus=active\n"
            );
            match std::fs::OpenOptions::new().append(true).open(&conf_path) {
                Ok(mut f) => {
                    use std::io::Write;
                    let _ = f.write_all(entry.as_bytes());
                    Json(json!({"ok": true, "output": format!("Added {peer} ({ip}) to peers.conf")}))
                }
                Err(e) => Json(json!({"error": format!("Failed to write peers.conf: {e}")})),
            }
        }
        "remove-node" => {
            let conf_path = std::env::var("HOME").unwrap_or_default() + "/.claude/config/peers.conf";
            match std::fs::read_to_string(&conf_path) {
                Ok(content) => {
                    let mut result = String::new();
                    let mut skip_section = false;
                    for line in content.lines() {
                        let trimmed = line.trim();
                        if trimmed.starts_with('[') && trimmed.ends_with(']') {
                            let section = &trimmed[1..trimmed.len() - 1];
                            skip_section = section == peer;
                            if skip_section { continue; }
                        }
                        if skip_section && !trimmed.starts_with('[') { continue; }
                        skip_section = false;
                        result.push_str(line);
                        result.push('\n');
                    }
                    match std::fs::write(&conf_path, &result) {
                        Ok(_) => Json(json!({"ok": true, "output": format!("Removed {peer} from peers.conf")})),
                        Err(e) => Json(json!({"error": format!("Failed to write: {e}")})),
                    }
                }
                Err(e) => Json(json!({"error": format!("Failed to read peers.conf: {e}")})),
            }
        }
        _ => Json(json!({"output": format!("{action} -> {peer}"), "exit_code": 0})),
    }
}
