mod checks_support;
pub mod checks;

use serde::Deserialize;
use serde_json::{json, Value};

#[derive(Debug, Deserialize)]
pub struct HookPayload {
    #[serde(default, alias = "toolName")]
    pub tool_name: String,
    #[serde(default, alias = "toolArgs")]
    pub tool_args: HookToolArgs,
    #[serde(default, alias = "tool_input")]
    pub tool_input: HookToolInput,
}

#[derive(Debug, Default, Deserialize)]
pub struct HookToolArgs {
    #[serde(default)]
    pub command: String,
}

#[derive(Debug, Default, Deserialize)]
pub struct HookToolInput {
    #[serde(default)]
    pub command: String,
}

pub fn dispatch_pre_tool(
    input_json: &str,
    context: &checks::CheckContext,
) -> Result<Option<Value>, String> {
    let payload: HookPayload = serde_json::from_str(input_json).map_err(|err| err.to_string())?;
    let tool_name = payload.tool_name.to_ascii_lowercase();
    if tool_name.is_empty() || (tool_name != "bash" && tool_name != "shell") {
        return Ok(None);
    }
    let command = if !payload.tool_args.command.is_empty() {
        payload.tool_args.command
    } else {
        payload.tool_input.command
    };
    let hook_command = checks::HookCommand { tool_name, command };
    let mut state = checks::DispatchState::default();
    for check in checks::bash_checks() {
        match check(&hook_command, context, &mut state)? {
            checks::CheckOutcome::Continue => {}
            checks::CheckOutcome::Deny(reason) => {
                return Ok(Some(
                    json!({"permissionDecision":"deny","permissionDecisionReason": reason}),
                ))
            }
            checks::CheckOutcome::Block(message) => return Err(message),
        }
    }
    if let Some(token) = state.gh_token {
        return Ok(Some(json!({"result":"approve","env":{"GH_TOKEN": token}})));
    }
    Ok(None)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::hooks::checks::CheckContext;
    use std::fs;
    use std::time::{SystemTime, UNIX_EPOCH};

    fn payload_for(command: &str) -> String {
        json!({
            "toolName": "Bash",
            "toolArgs": { "command": command }
        })
        .to_string()
    }

    #[test]
    fn hooks_dispatch_allows_irrelevant_tool() {
        let context = CheckContext::for_tests();
        let output = dispatch_pre_tool(r#"{"toolName":"Read"}"#, &context).expect("dispatch");
        assert!(output.is_none());
    }

    #[test]
    fn hooks_dispatch_denies_main_branch_git_write() {
        let mut context = CheckContext::for_tests();
        context.current_branch = Some("main".to_string());
        let output = dispatch_pre_tool(&payload_for("git commit -m test"), &context).expect("dispatch");
        let reason = output
            .and_then(|value| value.get("permissionDecisionReason").cloned())
            .and_then(|value| value.as_str().map(str::to_owned))
            .expect("deny reason");
        assert!(reason.contains("forbidden"));
    }

    #[test]
    fn hooks_dispatch_returns_gh_token_env() {
        let home = unique_temp_dir().join("home");
        fs::create_dir_all(home.join(".claude/config")).expect("config dir");
        fs::write(
            home.join(".claude/config/gh-accounts.json"),
            r#"{"default_account":"robot","mappings":[]}"#,
        )
        .expect("write config");

        let mut context = CheckContext::for_tests();
        context.home_dir = home.clone();
        context.gh_tokens.insert("robot".to_string(), "secret".to_string());
        let output = dispatch_pre_tool(&payload_for("gh pr view 1 --json id"), &context).expect("dispatch");
        let token = output
            .and_then(|value| value.get("env").cloned())
            .and_then(|value| value.get("GH_TOKEN").cloned())
            .and_then(|value| value.as_str().map(str::to_owned))
            .expect("token");
        assert_eq!(token, "secret");
        let _ = fs::remove_dir_all(home.parent().expect("tmp parent"));
    }

    #[test]
    fn hooks_dispatch_blocks_stale_execution_preflight() {
        let base = unique_temp_dir();
        let preflight = base.join("execution-preflight");
        fs::create_dir_all(&preflight).expect("preflight dir");
        fs::write(
            preflight.join("plan-100025.json"),
            r#"{"generated_epoch":1799990000,"warnings":[]}"#,
        )
        .expect("snapshot");
        let mut context = CheckContext::for_tests();
        context.preflight_dir = preflight;
        context.now_epoch = 1_800_000_000;
        let output = dispatch_pre_tool(&payload_for("plan-db.sh start 100025"), &context)
            .expect("dispatch");
        let reason = output
            .and_then(|value| value.get("permissionDecisionReason").cloned())
            .and_then(|value| value.as_str().map(str::to_owned))
            .expect("deny reason");
        assert!(reason.contains("stale"));
        let _ = fs::remove_dir_all(base);
    }

    #[test]
    fn hooks_dispatch_reuses_single_sqlite_connection() {
        let base = unique_temp_dir();
        let db = base.join("dashboard.db");
        seed_dashboard_db(&db);
        let mut context = CheckContext::for_tests();
        context.db_path = db;
        dispatch_pre_tool(&payload_for("az containerapp create -n demo"), &context).expect("dispatch 1");
        dispatch_pre_tool(&payload_for("az containerapp update -n demo"), &context).expect("dispatch 2");
        assert_eq!(context.db_open_count(), 1);
        let _ = fs::remove_dir_all(base);
    }

    fn seed_dashboard_db(path: &std::path::Path) {
        let connection = rusqlite::Connection::open(path).expect("open db");
        connection
            .execute_batch(
                "CREATE TABLE plans (id INTEGER PRIMARY KEY, status TEXT NOT NULL);
                 CREATE TABLE tasks (
                   id INTEGER PRIMARY KEY,
                   plan_id INTEGER NOT NULL,
                   task_id TEXT NOT NULL,
                   title TEXT NOT NULL,
                   status TEXT NOT NULL
                 );
                 INSERT INTO plans(id,status) VALUES(1,'doing');
                 INSERT INTO tasks(id,plan_id,task_id,title,status) VALUES
                   (1,1,'T1','Azure deploy hardening','pending');",
            )
            .expect("seed");
    }

    fn unique_temp_dir() -> std::path::PathBuf {
        let suffix = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .expect("clock")
            .as_nanos();
        let path = std::env::temp_dir().join(format!("claude-core-hooks-{suffix}"));
        fs::create_dir_all(&path).expect("tmp dir");
        path
    }
}
