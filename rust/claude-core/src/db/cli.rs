use super::{PlanDb, TaskStatus, UpdateTaskArgs, ValidateTaskArgs};
use crate::db::crdt::CrdtChange;

impl PlanDb {
    pub fn run_subcommand(&self, args: &[String]) -> rusqlite::Result<String> {
        self.run_subcommand_with_input(args, None)
    }

    pub fn run_subcommand_with_input(
        &self,
        args: &[String],
        input: Option<&str>,
    ) -> rusqlite::Result<String> {
        let command = args
            .first()
            .ok_or_else(|| super::service::invalid_input("subcommand required"))?
            .as_str();
        match command {
            "status" => {
                let project_id = args.get(1).map(String::as_str);
                Ok(serde_json::to_string_pretty(&self.status(project_id)?).map_err(json_error)?)
            }
            "update-task" => {
                if args.len() < 3 {
                    return Err(super::service::invalid_input(
                        "usage: update-task <task_id> <status> [notes] [--tokens N] [--output-data JSON]",
                    ));
                }
                let task_id = parse_i64(&args[1], "task_id")?;
                let status = TaskStatus::from_str_opt(&args[2])
                    .ok_or_else(|| super::service::invalid_input("invalid task status"))?;
                let parsed = parse_update_task_args(&args[3..])?;
                let result = self.update_task(task_id, status, &parsed)?;
                Ok(format!(
                    "[OK] Task {task_id}: {} -> {}",
                    result.old_status, result.new_status
                ))
            }
            "validate-task" => {
                if args.len() < 2 {
                    return Err(super::service::invalid_input(
                        "usage: validate-task <task_db_id_or_task_id> [plan_id] [validated_by] [--force] [--report JSON]",
                    ));
                }
                let parsed = parse_validate_task_args(&args[1..])?;
                let result = self.validate_task(&parsed)?;
                Ok(format!(
                    "[OK] Task {}: {} -> {} (validated by {})",
                    result.task_id, result.old_status, result.new_status, result.validated_by
                ))
            }
            "execution-tree" => {
                let plan_id = args
                    .get(1)
                    .ok_or_else(|| super::service::invalid_input("usage: execution-tree <plan_id>"))
                    .and_then(|raw| parse_i64(raw, "plan_id"))?;
                Ok(serde_json::to_string_pretty(&self.execution_tree(plan_id)?).map_err(json_error)?)
            }
            "export-changes" => Ok(serde_json::to_string_pretty(&self.export_changes()?)
                .map_err(json_error)?),
            "apply-changes" => {
                let payload =
                    input.ok_or_else(|| super::service::invalid_input("apply-changes requires stdin JSON"))?;
                let changes = serde_json::from_str::<Vec<CrdtChange>>(payload)
                    .map_err(|_| super::service::invalid_input("invalid JSON for apply-changes"))?;
                let applied = self.apply_changes(&changes)?;
                Ok(format!("[OK] applied {applied} CRDT changes"))
            }
            "sync" => {
                let peer = args
                    .get(1)
                    .ok_or_else(|| super::service::invalid_input("usage: sync <peer>"))?;
                let summary = self.sync_with_peer(peer)?;
                Ok(format!(
                    "[OK] synced with {} (sent {}, received {}, applied {})",
                    summary.peer, summary.sent, summary.received, summary.applied
                ))
            }
            _ => Err(super::service::invalid_input("unsupported subcommand")),
        }
    }
}

fn parse_update_task_args(args: &[String]) -> rusqlite::Result<UpdateTaskArgs> {
    let mut parsed = UpdateTaskArgs::default();
    let mut i = 0usize;
    while i < args.len() {
        match args[i].as_str() {
            "--tokens" => {
                let raw =
                    args.get(i + 1).ok_or_else(|| super::service::invalid_input("missing --tokens value"))?;
                parsed.tokens = Some(parse_i64(raw, "tokens")?);
                i += 2;
            }
            "--output-data" => {
                let raw = args
                    .get(i + 1)
                    .ok_or_else(|| super::service::invalid_input("missing --output-data value"))?;
                serde_json::from_str::<serde_json::Value>(raw)
                    .map_err(|_| super::service::invalid_input("invalid JSON for --output-data"))?;
                parsed.output_data = Some(raw.clone());
                i += 2;
            }
            value => {
                if parsed.notes.is_none() {
                    parsed.notes = Some(value.to_string());
                }
                i += 1;
            }
        }
    }
    Ok(parsed)
}

fn parse_validate_task_args(args: &[String]) -> rusqlite::Result<ValidateTaskArgs> {
    let mut parsed = ValidateTaskArgs {
        identifier: args[0].clone(),
        validated_by: "thor".to_string(),
        ..ValidateTaskArgs::default()
    };
    if let Some(raw_plan_id) = args.get(1) {
        if !raw_plan_id.starts_with("--") {
            parsed.plan_id = Some(parse_i64(raw_plan_id, "plan_id")?);
        }
    }
    if let Some(raw_validated_by) = args.get(2) {
        if !raw_validated_by.starts_with("--") {
            parsed.validated_by = raw_validated_by.clone();
        }
    }
    let mut i = 1usize;
    while i < args.len() {
        match args[i].as_str() {
            "--force" => {
                parsed.force = true;
                i += 1;
            }
            "--report" => {
                let raw =
                    args.get(i + 1).ok_or_else(|| super::service::invalid_input("missing --report value"))?;
                parsed.report = Some(raw.clone());
                i += 2;
            }
            _ => i += 1,
        }
    }
    Ok(parsed)
}

fn parse_i64(raw: &str, label: &str) -> rusqlite::Result<i64> {
    raw.parse::<i64>()
        .map_err(|_| super::service::invalid_input(&format!("invalid {label}: {raw}")))
}

fn json_error(err: serde_json::Error) -> rusqlite::Error {
    rusqlite::Error::ToSqlConversionFailure(Box::new(err))
}
