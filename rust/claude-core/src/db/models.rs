use serde::Serialize;

#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
pub struct ActivePlan {
    pub id: i64,
    pub project_id: String,
    pub name: String,
    pub status: String,
    pub tasks_done: i64,
    pub tasks_total: i64,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
pub struct InProgressTask {
    pub id: i64,
    pub project_id: String,
    pub task_id: String,
    pub title: String,
    pub wave_id: String,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
pub struct StatusView {
    pub active_plans: Vec<ActivePlan>,
    pub in_progress_tasks: Vec<InProgressTask>,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum TaskStatus {
    Pending,
    InProgress,
    Submitted,
    Done,
    Blocked,
    Skipped,
    Cancelled,
}

impl TaskStatus {
    pub fn as_str(self) -> &'static str {
        match self {
            Self::Pending => "pending",
            Self::InProgress => "in_progress",
            Self::Submitted => "submitted",
            Self::Done => "done",
            Self::Blocked => "blocked",
            Self::Skipped => "skipped",
            Self::Cancelled => "cancelled",
        }
    }

    pub fn from_str(value: &str) -> Option<Self> {
        match value {
            "pending" => Some(Self::Pending),
            "in_progress" => Some(Self::InProgress),
            "submitted" => Some(Self::Submitted),
            "done" => Some(Self::Done),
            "blocked" => Some(Self::Blocked),
            "skipped" => Some(Self::Skipped),
            "cancelled" => Some(Self::Cancelled),
            _ => None,
        }
    }
}

#[derive(Debug, Clone, Default)]
pub struct UpdateTaskArgs {
    pub notes: Option<String>,
    pub tokens: Option<i64>,
    pub output_data: Option<String>,
    pub executor_host: Option<String>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
pub struct UpdateTaskResult {
    pub old_status: String,
    pub new_status: String,
}

#[derive(Debug, Clone, Default)]
pub struct ValidateTaskArgs {
    pub identifier: String,
    pub plan_id: Option<i64>,
    pub validated_by: String,
    pub force: bool,
    pub report: Option<String>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
pub struct ValidateTaskResult {
    pub task_db_id: i64,
    pub task_id: String,
    pub old_status: String,
    pub new_status: String,
    pub validated_by: String,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
pub struct ExecutionTaskNode {
    pub id: i64,
    pub task_id: String,
    pub title: String,
    pub status: String,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
pub struct ExecutionWaveNode {
    pub id: i64,
    pub wave_id: String,
    pub name: String,
    pub status: String,
    pub tasks_done: i64,
    pub tasks_total: i64,
    pub tasks: Vec<ExecutionTaskNode>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
pub struct ExecutionTree {
    pub plan_id: i64,
    pub plan_name: String,
    pub plan_status: String,
    pub waves: Vec<ExecutionWaveNode>,
}
