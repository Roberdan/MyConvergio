//! W6: Sandbox & Night Mode — Docker containerization for guest nodes,
//! idle-time scheduling for overnight batch processing.

use serde::{Deserialize, Serialize};
use std::collections::HashMap;

/// T6-01: Docker sandbox configuration for guest nodes
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SandboxConfig {
    pub image: String,
    pub cpu_limit: f64,
    pub memory_limit_mb: u64,
    pub network: SandboxNetwork,
    pub volumes: Vec<VolumeMount>,
    pub env_vars: HashMap<String, String>,
    pub timeout_secs: u64,
}

#[derive(Debug, Clone, Copy, Serialize, Deserialize)]
pub enum SandboxNetwork {
    None,
    TailscaleOnly,
    Host,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct VolumeMount {
    pub host_path: String,
    pub container_path: String,
    pub read_only: bool,
}

impl Default for SandboxConfig {
    fn default() -> Self {
        Self {
            image: "convergio-mesh:latest".into(),
            cpu_limit: 2.0,
            memory_limit_mb: 4096,
            network: SandboxNetwork::TailscaleOnly,
            volumes: vec![VolumeMount {
                host_path: "~/.claude/data".into(),
                container_path: "/data".into(),
                read_only: false,
            }],
            env_vars: HashMap::new(),
            timeout_secs: 3600,
        }
    }
}

impl SandboxConfig {
    /// Generate Docker run command with security hardening
    pub fn to_docker_args(&self) -> Vec<String> {
        let mut args = vec![
            "run".into(), "--rm".into(),
            "--security-opt=no-new-privileges".into(),
            "--cap-drop=ALL".into(),
            "--pids-limit=256".into(),
            format!("--cpus={}", self.cpu_limit),
            format!("--memory={}m", self.memory_limit_mb),
        ];
        match self.network {
            SandboxNetwork::None => args.push("--network=none".into()),
            SandboxNetwork::TailscaleOnly => args.push("--network=host".into()),
            SandboxNetwork::Host => args.push("--network=host".into()),
        }
        for vol in &self.volumes {
            let ro = if vol.read_only { ":ro" } else { "" };
            args.push(format!("-v{}:{}{}",vol.host_path, vol.container_path, ro));
        }
        for (k, v) in &self.env_vars {
            args.push(format!("-e{}={}", k, v));
        }
        args.push(self.image.clone());
        args
    }
}

/// T6-02: Night mode scheduler — run tasks during idle hours
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct NightModeConfig {
    pub enabled: bool,
    pub start_hour: u8,
    pub end_hour: u8,
    pub timezone: String,
    pub max_concurrent_tasks: usize,
    pub allowed_models: Vec<String>,
}

impl Default for NightModeConfig {
    fn default() -> Self {
        Self {
            enabled: true,
            start_hour: 22,
            end_hour: 6,
            timezone: "CET".into(),
            max_concurrent_tasks: 5,
            allowed_models: vec![
                "claude-haiku-4.5".into(),
                "gpt-5-mini".into(),
                "ollama-llama3".into(),
            ],
        }
    }
}

impl NightModeConfig {
    /// Check if current time is within night mode window
    pub fn is_active_at_hour(&self, hour: u8) -> bool {
        if !self.enabled { return false; }
        if self.start_hour > self.end_hour {
            // Crosses midnight (e.g. 22-06)
            hour >= self.start_hour || hour < self.end_hour
        } else {
            hour >= self.start_hour && hour < self.end_hour
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn sandbox_generates_hardened_docker_args() {
        let cfg = SandboxConfig::default();
        let args = cfg.to_docker_args();
        assert!(args.contains(&"--security-opt=no-new-privileges".into()));
        assert!(args.contains(&"--cap-drop=ALL".into()));
        assert!(args.contains(&"--pids-limit=256".into()));
        assert!(args.contains(&"--cpus=2".into()));
    }

    #[test]
    fn night_mode_crosses_midnight() {
        let cfg = NightModeConfig::default(); // 22-06
        assert!(cfg.is_active_at_hour(23));
        assert!(cfg.is_active_at_hour(3));
        assert!(!cfg.is_active_at_hour(12));
        assert!(!cfg.is_active_at_hour(8));
    }

    #[test]
    fn night_mode_disabled() {
        let mut cfg = NightModeConfig::default();
        cfg.enabled = false;
        assert!(!cfg.is_active_at_hour(23));
    }
}
