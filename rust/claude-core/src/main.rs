use clap::{Parser, Subcommand};
use std::env;
use std::io::Read;
use std::path::PathBuf;

#[derive(Debug, Parser)]
#[command(name = "claude-core", version, about = "Core runtime for Claude utilities")]
struct Cli {
    #[arg(long, default_value_t = false)]
    version_json: bool,

    #[command(subcommand)]
    command: Option<Commands>,
}

#[derive(Debug, Subcommand)]
enum Commands {
    Db {
        #[arg(long)]
        db_path: Option<PathBuf>,
        #[arg(long)]
        crsqlite_path: Option<String>,
        #[arg(trailing_var_arg = true)]
        args: Vec<String>,
    },
    Hook {
        /// pre or post
        mode: String,
    },
    Serve {
        #[arg(long, default_value = "0.0.0.0:8420")]
        bind: String,
        #[arg(long)]
        static_dir: Option<PathBuf>,
    },
    Daemon {
        #[command(subcommand)]
        command: DaemonCommands,
    },
}

#[derive(Debug, Subcommand)]
enum DaemonCommands {
    Start {
        #[arg(long)]
        bind_ip: Option<String>,
        #[arg(long, default_value_t = 9420)]
        port: u16,
        #[arg(long, default_value = "peers.conf")]
        peers_conf: PathBuf,
        #[arg(long)]
        db_path: Option<PathBuf>,
        #[arg(long)]
        crsqlite_path: Option<String>,
    },
}

#[tokio::main]
async fn main() {
    let cli = Cli::parse();
    if cli.version_json {
        let payload = serde_json::json!({
            "binary": "claude-core",
            "version": env!("CARGO_PKG_VERSION")
        });
        println!("{payload}");
        return;
    }
    if let Some(command) = cli.command {
        match command {
            Commands::Db {
                db_path,
                crsqlite_path,
                args,
            } => {
                let path = db_path.unwrap_or_else(default_db_path);
                let db = match claude_core::db::PlanDb::open_path(&path, crsqlite_path) {
                    Ok(db) => db,
                    Err(err) => {
                        eprintln!("db open failed: {err}");
                        std::process::exit(2);
                    }
                };
                let command = args.first().map(String::as_str).unwrap_or_default();
                let mut stdin_payload = None;
                if command == "apply-changes" {
                    let mut buf = String::new();
                    if std::io::stdin().read_to_string(&mut buf).is_ok() {
                        stdin_payload = Some(buf);
                    }
                }
                match db.run_subcommand_with_input(&args, stdin_payload.as_deref()) {
                    Ok(output) => println!("{output}"),
                    Err(err) => {
                        eprintln!("{err}");
                        std::process::exit(2);
                    }
                }
            }
            Commands::Hook { mode } => {
                let mut input = String::new();
                if std::io::stdin().read_to_string(&mut input).is_err() || input.trim().is_empty() {
                    return;
                }
                let home = env::var("HOME").unwrap_or_else(|_| ".".to_string());
                let context = claude_core::hooks::checks::CheckContext::from_env(&home);
                if mode == "pre" {
                    match claude_core::hooks::dispatch_pre_tool(&input, &context) {
                        Ok(Some(result)) => println!("{result}"),
                        Ok(None) => {}
                        Err(err) => {
                            eprintln!("{err}");
                            std::process::exit(1);
                        }
                    }
                }
            }
            Commands::Serve { bind, static_dir } => {
                let dir = static_dir.unwrap_or_else(|| {
                    let home = env::var("HOME").unwrap_or_else(|_| ".".to_string());
                    claude_core::server::resolve_dashboard_static_dir(PathBuf::from(home).join(".claude"))
                });
                eprintln!("claude-core serve → {bind} (static: {dir:?})");
                if let Err(err) = claude_core::server::run(&bind, dir).await {
                    eprintln!("server failed: {err}");
                    std::process::exit(2);
                }
            }
            Commands::Daemon { command } => match command {
                DaemonCommands::Start {
                    bind_ip,
                    port,
                    peers_conf,
                    db_path,
                    crsqlite_path,
                } => {
                    let resolved_ip = bind_ip
                        .or_else(|| env::var("TAILSCALE_IP").ok())
                        .or_else(claude_core::mesh::daemon::detect_tailscale_ip)
                        .unwrap_or_else(|| "0.0.0.0".to_string());
                    let config = claude_core::mesh::daemon::DaemonConfig {
                        bind_ip: resolved_ip,
                        port,
                        peers_conf_path: peers_conf,
                        db_path: db_path.unwrap_or_else(default_db_path),
                        crsqlite_path,
                    };
                    if let Err(err) = claude_core::mesh::daemon::run_service(config).await {
                        eprintln!("daemon start failed: {err}");
                        std::process::exit(2);
                    }
                }
            },
        }
        return;
    }
    println!("claude-core scaffold ready");
}

fn default_db_path() -> PathBuf {
    let home = env::var("HOME").unwrap_or_else(|_| ".".to_string());
    PathBuf::from(home).join(".claude/data/dashboard.db")
}
