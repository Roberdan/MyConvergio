use serde_json::Value;
use socket2::{SockRef, TcpKeepalive};
use std::collections::HashMap;
use std::net::IpAddr;
use std::time::Duration;
use tokio::net::TcpStream;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct MeshSocketTuning {
    pub nodelay: bool,
    pub keepalive_idle_secs: u64,
    pub keepalive_interval_secs: u64,
}

pub fn mesh_socket_tuning() -> MeshSocketTuning {
    MeshSocketTuning {
        nodelay: true,
        keepalive_idle_secs: 30,
        keepalive_interval_secs: 10,
    }
}

pub fn apply_socket_tuning(stream: &TcpStream) -> Result<(), String> {
    let tuning = mesh_socket_tuning();
    stream
        .set_nodelay(tuning.nodelay)
        .map_err(|e| format!("set TCP_NODELAY failed: {e}"))?;
    let keepalive = TcpKeepalive::new()
        .with_time(Duration::from_secs(tuning.keepalive_idle_secs))
        .with_interval(Duration::from_secs(tuning.keepalive_interval_secs));
    let socket = SockRef::from(stream);
    socket
        .set_tcp_keepalive(&keepalive)
        .map_err(|e| format!("set SO_KEEPALIVE failed: {e}"))
}

pub fn load_tailscale_peer_ips() -> HashMap<String, String> {
    const CANDIDATES: &[&str] = &[
        "tailscale",
        "/usr/local/bin/tailscale",
        "/opt/homebrew/bin/tailscale",
        "/Applications/Tailscale.app/Contents/MacOS/Tailscale",
    ];
    let output = match CANDIDATES.iter().find_map(|cmd| {
        std::process::Command::new(cmd).arg("status").arg("--json").output().ok().filter(|o| o.status.success())
    }) {
        Some(output) => output,
        None => return HashMap::new(),
    };
    let payload = match serde_json::from_slice::<Value>(&output.stdout) {
        Ok(payload) => payload,
        Err(_) => return HashMap::new(),
    };
    let mut lookup = HashMap::new();
    for peer in payload
        .get("Peer")
        .and_then(Value::as_object)
        .into_iter()
        .flat_map(|peers| peers.values())
    {
        let ip = peer
            .get("TailscaleIPs")
            .and_then(Value::as_array)
            .and_then(|ips| ips.first())
            .and_then(Value::as_str)
            .map(|v| v.to_string());
        let Some(ip) = ip else { continue };
        if let Some(name) = peer.get("HostName").and_then(Value::as_str) {
            lookup.insert(name.to_string(), ip.clone());
        }
        if let Some(name) = peer.get("DNSName").and_then(Value::as_str) {
            lookup.insert(name.trim_end_matches('.').to_string(), ip.clone());
        }
    }
    lookup
}

pub fn prefer_tailscale_peer_addr(peer: &str, lookup: &HashMap<String, String>) -> String {
    let Some((host, port)) = split_host_port(peer) else {
        return peer.to_string();
    };
    if host.parse::<IpAddr>().is_ok() {
        return peer.to_string();
    }
    match lookup.get(host).or_else(|| lookup.get(host.trim_end_matches('.'))) {
        Some(ip) => format!("{ip}:{port}"),
        None => peer.to_string(),
    }
}

fn split_host_port(addr: &str) -> Option<(&str, &str)> {
    let (host, port) = addr.rsplit_once(':')?;
    if host.is_empty() || port.is_empty() {
        return None;
    }
    Some((host, port))
}
