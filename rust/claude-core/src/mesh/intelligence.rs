//! W5: Distributed Intelligence — gossip, capabilities, scheduling, budget tracking.
//! SWIM-lite gossip for membership, capability registry for model discovery,
//! dynamic task scheduler, per-node budget tracking.

use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::sync::Arc;
use tokio::sync::RwLock;

/// T5-01: SWIM-lite gossip state — membership + failure detection
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct GossipMember {
    pub node_id: String,
    pub addr: String,
    pub incarnation: u64,
    pub state: MemberState,
    pub last_seen: u64,
    pub capabilities: Vec<String>,
    pub version: String,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum MemberState {
    Alive,
    Suspect,
    Dead,
}

/// T5-02: Capability entry — what models/tools a node supports
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct NodeCapability {
    pub model_name: String,
    pub provider: String,
    pub max_tokens: u32,
    pub cost_per_1k_tokens: f64,
    pub available: bool,
}

/// T5-04: Per-node budget tracker
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct NodeBudget {
    pub node_id: String,
    pub daily_limit_usd: f64,
    pub spent_today_usd: f64,
    pub monthly_limit_usd: f64,
    pub spent_month_usd: f64,
    pub last_reset: String,
}

/// T5-03: Task queue entry for distributed scheduling
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ScheduledTask {
    pub task_id: String,
    pub plan_id: i64,
    pub model_hint: String,
    pub effort: u8,
    pub assigned_node: Option<String>,
    pub status: TaskQueueStatus,
    pub created_at: u64,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum TaskQueueStatus {
    Queued,
    Assigned,
    Running,
    Done,
    Failed,
}

/// Central distributed intelligence state
pub struct IntelligenceHub {
    pub members: Arc<RwLock<HashMap<String, GossipMember>>>,
    pub capabilities: Arc<RwLock<HashMap<String, Vec<NodeCapability>>>>,
    pub budgets: Arc<RwLock<HashMap<String, NodeBudget>>>,
    pub task_queue: Arc<RwLock<Vec<ScheduledTask>>>,
}

impl IntelligenceHub {
    pub fn new() -> Self {
        Self {
            members: Arc::new(RwLock::new(HashMap::new())),
            capabilities: Arc::new(RwLock::new(HashMap::new())),
            budgets: Arc::new(RwLock::new(HashMap::new())),
            task_queue: Arc::new(RwLock::new(Vec::new())),
        }
    }

    /// T5-01: Register or update a member via gossip
    pub async fn update_member(&self, member: GossipMember) {
        let mut members = self.members.write().await;
        let node_id = member.node_id.clone();
        if let Some(existing) = members.get(&node_id) {
            if member.incarnation <= existing.incarnation && member.state != MemberState::Alive {
                return; // Stale update
            }
        }
        members.insert(node_id, member);
    }

    /// T5-01: Mark suspect nodes as dead after timeout
    pub async fn prune_dead_members(&self, timeout_secs: u64) {
        let now = crate::mesh::daemon::now_ts();
        let mut members = self.members.write().await;
        for member in members.values_mut() {
            let age = now.saturating_sub(member.last_seen);
            match member.state {
                MemberState::Alive if age > timeout_secs / 2 => {
                    member.state = MemberState::Suspect;
                }
                MemberState::Suspect if age > timeout_secs => {
                    member.state = MemberState::Dead;
                }
                _ => {}
            }
        }
    }

    /// T5-02: Register node capabilities
    pub async fn register_capabilities(&self, node_id: &str, caps: Vec<NodeCapability>) {
        self.capabilities.write().await.insert(node_id.to_string(), caps);
    }

    /// T5-03: Find best node for a task based on model hint + budget + availability
    pub async fn schedule_task(&self, task: &ScheduledTask) -> Option<String> {
        let members = self.members.read().await;
        let capabilities = self.capabilities.read().await;
        let budgets = self.budgets.read().await;

        let mut best: Option<(String, f64)> = None;

        for (node_id, member) in members.iter() {
            if member.state != MemberState::Alive {
                continue;
            }
            // Check capabilities
            if let Some(caps) = capabilities.get(node_id) {
                let has_model = caps.iter().any(|c| {
                    c.available && (c.model_name == task.model_hint || c.provider == task.model_hint)
                });
                if !has_model {
                    continue;
                }
                // Check budget
                if let Some(budget) = budgets.get(node_id) {
                    if budget.spent_today_usd >= budget.daily_limit_usd {
                        continue; // Over budget
                    }
                }
                // Score: prefer lowest cost, then least loaded
                let cost = caps.iter()
                    .filter(|c| c.model_name == task.model_hint)
                    .map(|c| c.cost_per_1k_tokens)
                    .min_by(|a, b| a.partial_cmp(b).unwrap_or(std::cmp::Ordering::Equal))
                    .unwrap_or(f64::MAX);
                if best.as_ref().is_none_or(|(_, best_cost)| cost < *best_cost) {
                    best = Some((node_id.clone(), cost));
                }
            }
        }
        best.map(|(node, _)| node)
    }

    /// T5-04: Record spend against a node's budget
    pub async fn record_spend(&self, node_id: &str, amount_usd: f64) {
        let mut budgets = self.budgets.write().await;
        if let Some(budget) = budgets.get_mut(node_id) {
            budget.spent_today_usd += amount_usd;
            budget.spent_month_usd += amount_usd;
        }
    }

    /// Snapshot for API/dashboard
    pub async fn snapshot(&self) -> serde_json::Value {
        let members = self.members.read().await;
        let caps = self.capabilities.read().await;
        let budgets = self.budgets.read().await;
        let queue = self.task_queue.read().await;
        serde_json::json!({
            "members": members.len(),
            "alive": members.values().filter(|m| m.state == MemberState::Alive).count(),
            "suspect": members.values().filter(|m| m.state == MemberState::Suspect).count(),
            "dead": members.values().filter(|m| m.state == MemberState::Dead).count(),
            "capabilities": caps.len(),
            "budgets": budgets.len(),
            "queue_size": queue.len(),
            "queue_running": queue.iter().filter(|t| t.status == TaskQueueStatus::Running).count(),
        })
    }

    /// T5-05: Version info for peer negotiation
    pub fn local_version_info() -> serde_json::Value {
        serde_json::json!({
            "version": env!("CARGO_PKG_VERSION"),
            "features": ["gossip", "capabilities", "scheduler", "budget", "anti-entropy", "auth"],
            "protocol_version": 2,
        })
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn test_member(id: &str, state: MemberState) -> GossipMember {
        GossipMember {
            node_id: id.into(), addr: format!("{id}:9420"),
            incarnation: 1, state, last_seen: crate::mesh::daemon::now_ts(),
            capabilities: vec!["claude".into()], version: "11.5.0".into(),
        }
    }

    #[tokio::test]
    async fn gossip_registers_and_prunes_members() {
        let hub = IntelligenceHub::new();
        hub.update_member(test_member("n1", MemberState::Alive)).await;
        hub.update_member(test_member("n2", MemberState::Alive)).await;
        assert_eq!(hub.members.read().await.len(), 2);
    }

    #[tokio::test]
    async fn scheduler_picks_cheapest_available_node() {
        let hub = IntelligenceHub::new();
        hub.update_member(test_member("expensive", MemberState::Alive)).await;
        hub.update_member(test_member("cheap", MemberState::Alive)).await;

        hub.register_capabilities("expensive", vec![NodeCapability {
            model_name: "gpt-5.3-codex".into(), provider: "openai".into(),
            max_tokens: 128000, cost_per_1k_tokens: 0.15, available: true,
        }]).await;
        hub.register_capabilities("cheap", vec![NodeCapability {
            model_name: "gpt-5.3-codex".into(), provider: "openai".into(),
            max_tokens: 128000, cost_per_1k_tokens: 0.03, available: true,
        }]).await;

        let task = ScheduledTask {
            task_id: "T1".into(), plan_id: 599, model_hint: "gpt-5.3-codex".into(),
            effort: 2, assigned_node: None, status: TaskQueueStatus::Queued,
            created_at: 0,
        };
        let best = hub.schedule_task(&task).await;
        assert_eq!(best.as_deref(), Some("cheap"));
    }

    #[tokio::test]
    async fn scheduler_skips_over_budget_nodes() {
        let hub = IntelligenceHub::new();
        hub.update_member(test_member("rich", MemberState::Alive)).await;
        hub.update_member(test_member("broke", MemberState::Alive)).await;

        for node in &["rich", "broke"] {
            hub.register_capabilities(node, vec![NodeCapability {
                model_name: "claude".into(), provider: "anthropic".into(),
                max_tokens: 200000, cost_per_1k_tokens: 0.01, available: true,
            }]).await;
        }

        hub.budgets.write().await.insert("broke".into(), NodeBudget {
            node_id: "broke".into(), daily_limit_usd: 10.0, spent_today_usd: 10.0,
            monthly_limit_usd: 300.0, spent_month_usd: 10.0, last_reset: "2026-03-10".into(),
        });
        hub.budgets.write().await.insert("rich".into(), NodeBudget {
            node_id: "rich".into(), daily_limit_usd: 100.0, spent_today_usd: 5.0,
            monthly_limit_usd: 3000.0, spent_month_usd: 50.0, last_reset: "2026-03-10".into(),
        });

        let task = ScheduledTask {
            task_id: "T2".into(), plan_id: 599, model_hint: "claude".into(),
            effort: 3, assigned_node: None, status: TaskQueueStatus::Queued,
            created_at: 0,
        };
        let best = hub.schedule_task(&task).await;
        assert_eq!(best.as_deref(), Some("rich"));
    }
}
