use rusqlite::{Connection, OpenFlags};
use std::cell::{Cell, RefCell};
use std::collections::BTreeMap;
use std::path::{Path, PathBuf};

#[derive(Debug)]
pub struct HookCommand {
    pub tool_name: String,
    pub command: String,
}

#[derive(Debug, Default)]
pub struct DispatchState {
    pub gh_token: Option<String>,
    pub notices: Vec<String>,
}

#[derive(Debug, PartialEq, Eq)]
pub enum CheckOutcome {
    Continue,
    Deny(String),
    Block(String),
}

#[derive(Debug)]
pub struct CheckContext {
    pub home_dir: PathBuf,
    pub cwd: PathBuf,
    pub repo_root: Option<PathBuf>,
    pub current_branch: Option<String>,
    pub allow_main_write: bool,
    pub gh_tokens: BTreeMap<String, String>,
    pub now_epoch: i64,
    pub db_path: PathBuf,
    pub preflight_dir: PathBuf,
    pub active_plan_id: Option<u64>,
    db_conn: RefCell<Option<Connection>>,
    db_open_count: Cell<usize>,
}

impl CheckContext {
    pub fn from_env(home: &str) -> Self {
        let home_dir = PathBuf::from(home);
        let cwd = std::env::current_dir().unwrap_or_else(|_| PathBuf::from("."));
        let branch = std::process::Command::new("git")
            .args(["rev-parse", "--abbrev-ref", "HEAD"])
            .output()
            .ok()
            .filter(|o| o.status.success())
            .and_then(|o| String::from_utf8(o.stdout).ok())
            .map(|s| s.trim().to_string());
        let now = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .map(|d| d.as_secs() as i64)
            .unwrap_or(0);
        Self {
            db_path: home_dir.join(".claude/data/dashboard.db"),
            preflight_dir: home_dir.join(".claude/data/execution-preflight"),
            home_dir,
            cwd,
            repo_root: None,
            current_branch: branch,
            allow_main_write: false,
            gh_tokens: BTreeMap::new(),
            now_epoch: now,
            active_plan_id: None,
            db_conn: RefCell::new(None),
            db_open_count: Cell::new(0),
        }
    }

    pub fn for_tests() -> Self {
        Self {
            home_dir: PathBuf::from("/tmp"),
            cwd: PathBuf::from("/tmp"),
            repo_root: None,
            current_branch: None,
            allow_main_write: false,
            gh_tokens: BTreeMap::new(),
            now_epoch: 1_800_000_000,
            db_path: PathBuf::from("/tmp/dashboard.db"),
            preflight_dir: PathBuf::from("/tmp"),
            active_plan_id: None,
            db_conn: RefCell::new(None),
            db_open_count: Cell::new(0),
        }
    }

    pub fn with_db<T, F>(&self, op: F) -> Result<Option<T>, String>
    where
        F: FnOnce(&Connection) -> rusqlite::Result<T>,
    {
        if !self.db_path.exists() {
            return Ok(None);
        }
        let mut slot = self.db_conn.borrow_mut();
        if slot.is_none() {
            let conn = Connection::open_with_flags(&self.db_path, OpenFlags::SQLITE_OPEN_READ_ONLY)
                .map_err(|err| err.to_string())?;
            self.db_open_count.set(self.db_open_count.get() + 1);
            *slot = Some(conn);
        }
        let result = op(slot.as_ref().expect("db connection")).map_err(|err| err.to_string())?;
        Ok(Some(result))
    }

    pub fn db_open_count(&self) -> usize {
        self.db_open_count.get()
    }
}

pub type CheckFn = fn(&HookCommand, &CheckContext, &mut DispatchState) -> Result<CheckOutcome, String>;

pub fn bash_checks() -> [CheckFn; 7] {
    [
        super::checks_support::check_gh_auto_token,
        check_worktree_guard,
        check_warn_bash_antipatterns,
        super::checks_support::check_prefer_ci_summary,
        super::checks_support::check_warn_infra_plan_drift,
        super::checks_support::check_enforce_execution_preflight,
        check_plan_db_validation_hints,
    ]
}

pub fn check_worktree_guard(
    command: &HookCommand,
    context: &CheckContext,
    _state: &mut DispatchState,
) -> Result<CheckOutcome, String> {
    if command.command.contains("git worktree add") {
        if let Some(path) = super::checks_support::extract_worktree_add_path(&command.command) {
            let resolved = normalize_path(&context.cwd, &path);
            let repo_root = context.repo_root.clone().unwrap_or_else(|| context.cwd.clone());
            if resolved.starts_with(repo_root) {
                return Ok(CheckOutcome::Deny(
                    "WORKTREE GUARD: Path is INSIDE the repo. Use a SIBLING path instead."
                        .to_string(),
                ));
            }
        }
    }
    if command.command.contains("git worktree remove") {
        return Ok(CheckOutcome::Deny(
            "Use worktree-cleanup.sh instead of direct git worktree remove.".to_string(),
        ));
    }
    if contains_any(&command.command, &["git checkout -b", "git switch -c"])
        || (command.command.contains("git branch ")
            && !contains_any(
                &command.command,
                &[
                    "git branch -d",
                    "git branch -D",
                    "git branch --list",
                    "git branch --show",
                    "git branch --merged",
                    "git branch --no-merged",
                    "git branch --contains",
                ],
            ))
    {
        return Ok(CheckOutcome::Deny("BLOCKED: Never create bare branches. Use worktree-create.sh or wave-worktree.sh create instead. See worktree-discipline.md § No Bare Branches.".to_string()));
    }
    if contains_any(
        &command.command,
        &[
            "git commit",
            "git push",
            "git add",
            "git checkout",
            "git merge",
            "git rebase",
            "git reset",
            "git stash",
        ],
    ) && !context.allow_main_write
        && matches!(context.current_branch.as_deref(), Some("main" | "master"))
    {
        return Ok(CheckOutcome::Deny(
            "BLOCKED: Git write on main/master is forbidden. Work in a worktree.".to_string(),
        ));
    }
    Ok(CheckOutcome::Continue)
}

pub fn check_warn_bash_antipatterns(
    command: &HookCommand,
    _context: &CheckContext,
    state: &mut DispatchState,
) -> Result<CheckOutcome, String> {
    if command.command.contains("sqlite3")
        && command.command.contains("!=")
        && command.command.contains('"')
    {
        return Ok(CheckOutcome::Block("BLOCKED: '!=' inside double-quoted sqlite3 command will break in zsh (! expansion).".to_string()));
    }
    if command.command.contains(" find ") || command.command.starts_with("find ") {
        state
            .notices
            .push("ANTIPATTERN: Use Glob tool instead of bash".to_string());
    }
    if command.command.contains(" grep ")
        || command.command.starts_with("grep ")
        || command.command.starts_with("rg ")
    {
        state
            .notices
            .push("ANTIPATTERN: Use Grep tool instead of bash".to_string());
    }
    Ok(CheckOutcome::Continue)
}

pub fn check_plan_db_validation_hints(
    command: &HookCommand,
    _context: &CheckContext,
    state: &mut DispatchState,
) -> Result<CheckOutcome, String> {
    if command.command.contains("plan-db.sh update-task")
        && contains_any(&command.command, &[" done", " submitted"])
    {
        state.notices.push("Hint: plan-db.sh enforces done/submitted transitions. Use plan-db-safe.sh update-task <id> done ...".to_string());
    }
    if command.command.contains("plan-db.sh start") {
        state.notices.push(
            "Hint: plan-db.sh start already enforces planner gates via cmd_check_readiness."
                .to_string(),
        );
    }
    if command.command.contains("plan-db.sh complete") {
        state.notices.push(
            "Hint: plan-db.sh complete already enforces Thor completion gates.".to_string(),
        );
    }
    Ok(CheckOutcome::Continue)
}

fn contains_any(command: &str, values: &[&str]) -> bool {
    values.iter().any(|value| command.contains(value))
}

fn normalize_path(base: &Path, candidate: &str) -> PathBuf {
    let joined = if Path::new(candidate).is_absolute() {
        PathBuf::from(candidate)
    } else {
        base.join(candidate)
    };
    joined.canonicalize().unwrap_or(joined)
}
