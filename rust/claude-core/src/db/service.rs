use super::{
    queries, ActivePlan, ExecutionTaskNode, ExecutionTree, ExecutionWaveNode, InProgressTask, PlanDb,
    StatusView, TaskStatus, UpdateTaskArgs, UpdateTaskResult, ValidateTaskArgs, ValidateTaskResult,
};
use rusqlite::params;
use std::io::{Error as IoError, ErrorKind};

impl PlanDb {
    pub fn status(&self, project_id: Option<&str>) -> rusqlite::Result<StatusView> {
        let active_plans = if let Some(project_id) = project_id {
            let mut stmt = self.conn.prepare(queries::SELECT_ACTIVE_PLANS_BY_PROJECT)?;
            let rows = stmt.query_map(params![project_id], map_active_plan)?;
            rows.collect::<rusqlite::Result<Vec<_>>>()?
        } else {
            let mut stmt = self.conn.prepare(queries::SELECT_ACTIVE_PLANS_ALL)?;
            let rows = stmt.query_map([], map_active_plan)?;
            rows.collect::<rusqlite::Result<Vec<_>>>()?
        };

        let in_progress_tasks = if let Some(project_id) = project_id {
            let mut stmt = self.conn.prepare(queries::SELECT_IN_PROGRESS_TASKS_BY_PROJECT)?;
            let rows = stmt.query_map(params![project_id], map_in_progress_task)?;
            rows.collect::<rusqlite::Result<Vec<_>>>()?
        } else {
            let mut stmt = self.conn.prepare(queries::SELECT_IN_PROGRESS_TASKS_ALL)?;
            let rows = stmt.query_map([], map_in_progress_task)?;
            rows.collect::<rusqlite::Result<Vec<_>>>()?
        };

        Ok(StatusView {
            active_plans,
            in_progress_tasks,
        })
    }

    pub fn update_task(
        &self,
        task_id: i64,
        status: TaskStatus,
        args: &UpdateTaskArgs,
    ) -> rusqlite::Result<UpdateTaskResult> {
        let old_status: String = self
            .conn
            .query_row(queries::SELECT_TASK_STATUS_BY_ID, params![task_id], |row| {
                row.get(0)
            })?;
        if old_status == "pending" && matches!(status, TaskStatus::Done | TaskStatus::Submitted) {
            return Err(invalid_input(
                "Cannot transition pending to done/submitted directly",
            ));
        }
        if old_status == "pending" && status == TaskStatus::InProgress {
            let plan_status: String = self.conn.query_row(
                queries::SELECT_PLAN_STATUS_BY_TASK_ID,
                params![task_id],
                |row| row.get(0),
            )?;
            if plan_status != "doing" {
                return Err(invalid_input("Cannot start task unless plan status is doing"));
            }
        }

        let notes = args.notes.clone().unwrap_or_default();
        let host = args.executor_host.clone();
        let tokens = args.tokens;
        let output_data = args.output_data.clone();
        match status {
            TaskStatus::InProgress => self.conn.execute(
                queries::UPDATE_TASK_IN_PROGRESS,
                params![task_id, host, notes, tokens, output_data],
            )?,
            TaskStatus::Submitted => self.conn.execute(
                queries::UPDATE_TASK_SUBMITTED,
                params![task_id, host, notes, tokens, output_data],
            )?,
            TaskStatus::Done => self.conn.execute(
                queries::UPDATE_TASK_DONE,
                params![task_id, host, notes, tokens, output_data],
            )?,
            _ => self.conn.execute(
                queries::UPDATE_TASK_GENERIC,
                params![task_id, status.as_str(), host, notes, tokens, output_data],
            )?,
        };
        Ok(UpdateTaskResult {
            old_status,
            new_status: status.as_str().to_string(),
        })
    }

    pub fn validate_task(&self, args: &ValidateTaskArgs) -> rusqlite::Result<ValidateTaskResult> {
        let (task_db_id, task_id, old_status, validated_at): (i64, String, String, Option<String>) =
            if let Ok(id) = args.identifier.parse::<i64>() {
                self.conn.query_row(
                    queries::SELECT_TASK_FOR_VALIDATION_BY_ID,
                    params![id],
                    |row| Ok((row.get(0)?, row.get(1)?, row.get(2)?, row.get(3)?)),
                )?
            } else {
                let plan_id = args
                    .plan_id
                    .ok_or_else(|| invalid_input("plan_id is required when validating by task_id"))?;
                self.conn.query_row(
                    queries::SELECT_TASK_FOR_VALIDATION_BY_TASK_ID_AND_PLAN,
                    params![args.identifier, plan_id],
                    |row| Ok((row.get(0)?, row.get(1)?, row.get(2)?, row.get(3)?)),
                )?
            };
        if old_status != "submitted" && old_status != "done" {
            return Err(invalid_input(
                "Only submitted or done tasks can be validated",
            ));
        }
        if old_status == "done" && validated_at.is_some() {
            return Ok(ValidateTaskResult {
                task_db_id,
                task_id,
                old_status: "done".to_string(),
                new_status: "done".to_string(),
                validated_by: args.validated_by.clone(),
            });
        }
        let approved = matches!(
            args.validated_by.as_str(),
            "thor" | "thor-quality-assurance-guardian" | "thor-per-wave"
        );
        let effective_validator = if approved {
            args.validated_by.as_str()
        } else if args.force {
            "forced-admin"
        } else {
            return Err(invalid_input("Only Thor validators can validate tasks"));
        };

        if old_status == "submitted" {
            self.conn.execute(
                queries::UPDATE_VALIDATE_SUBMITTED,
                params![task_db_id, effective_validator, args.report.clone()],
            )?;
        } else {
            self.conn.execute(
                queries::UPDATE_VALIDATE_DONE,
                params![task_db_id, effective_validator, args.report.clone()],
            )?;
        }
        Ok(ValidateTaskResult {
            task_db_id,
            task_id,
            old_status,
            new_status: "done".to_string(),
            validated_by: effective_validator.to_string(),
        })
    }

    pub fn execution_tree(&self, plan_id: i64) -> rusqlite::Result<ExecutionTree> {
        let (plan_id, plan_name, plan_status): (i64, String, String) =
            self.conn
                .query_row(queries::SELECT_PLAN_NODE, params![plan_id], |row| {
                    Ok((row.get(0)?, row.get(1)?, row.get(2)?))
                })?;
        let mut waves_stmt = self.conn.prepare(queries::SELECT_WAVE_NODES)?;
        let wave_rows = waves_stmt.query_map(params![plan_id], |row| {
            Ok((
                row.get::<_, i64>(0)?,
                row.get::<_, String>(1)?,
                row.get::<_, String>(2)?,
                row.get::<_, String>(3)?,
                row.get::<_, i64>(4)?,
                row.get::<_, i64>(5)?,
            ))
        })?;
        let mut waves = Vec::new();
        for wave_row in wave_rows {
            let (wave_db_id, wave_id, name, status, tasks_done, tasks_total) = wave_row?;
            let mut task_stmt = self.conn.prepare(queries::SELECT_TASK_NODES_BY_WAVE)?;
            let tasks = task_stmt
                .query_map(params![wave_db_id], |row| {
                    Ok(ExecutionTaskNode {
                        id: row.get(0)?,
                        task_id: row.get(1)?,
                        title: row.get(2)?,
                        status: row.get(3)?,
                    })
                })?
                .collect::<rusqlite::Result<Vec<_>>>()?;
            waves.push(ExecutionWaveNode {
                id: wave_db_id,
                wave_id,
                name,
                status,
                tasks_done,
                tasks_total,
                tasks,
            });
        }
        Ok(ExecutionTree {
            plan_id,
            plan_name,
            plan_status,
            waves,
        })
    }
}

fn map_active_plan(row: &rusqlite::Row<'_>) -> rusqlite::Result<ActivePlan> {
    Ok(ActivePlan {
        id: row.get(0)?,
        project_id: row.get(1)?,
        name: row.get(2)?,
        status: row.get(3)?,
        tasks_done: row.get(4)?,
        tasks_total: row.get(5)?,
    })
}

fn map_in_progress_task(row: &rusqlite::Row<'_>) -> rusqlite::Result<InProgressTask> {
    Ok(InProgressTask {
        id: row.get(0)?,
        project_id: row.get(1)?,
        task_id: row.get(2)?,
        title: row.get(3)?,
        wave_id: row.get(4)?,
    })
}

pub(crate) fn invalid_input(message: &str) -> rusqlite::Error {
    rusqlite::Error::ToSqlConversionFailure(Box::new(IoError::new(
        ErrorKind::InvalidInput,
        message.to_string(),
    )))
}
