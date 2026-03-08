use super::merge_plan_status;
use ssh2::Session;
use std::fs;
use std::io::Read;
use std::net::TcpStream;
use std::path::Path;
use std::time::{Duration, SystemTime, UNIX_EPOCH};

pub struct SshClient {
    session: Session,
}

impl SshClient {
    pub fn connect(dest: &str, timeout: Duration) -> Result<Self, String> {
        let (user, host_port) = if let Some((u, rest)) = dest.split_once('@') {
            (u.to_string(), rest.to_string())
        } else {
            ("".to_string(), dest.to_string())
        };
        let addr = if host_port.contains(':') { host_port } else { format!("{host_port}:22") };
        let tcp = TcpStream::connect(addr).map_err(|e| e.to_string())?;
        let _ = tcp.set_read_timeout(Some(timeout));
        let _ = tcp.set_write_timeout(Some(timeout));
        let mut session = Session::new().map_err(|e| e.to_string())?;
        session.set_tcp_stream(tcp);
        session.handshake().map_err(|e| e.to_string())?;
        let auth_user = if user.is_empty() {
            std::env::var("USER").unwrap_or_else(|_| "root".to_string())
        } else {
            user
        };
        session.userauth_agent(&auth_user).map_err(|e| e.to_string())?;
        if !session.authenticated() {
            return Err("ssh authentication failed".to_string());
        }
        Ok(Self { session })
    }

    pub fn exec(&self, command: &str) -> Result<(i32, String, String), String> {
        let mut channel = self.session.channel_session().map_err(|e| e.to_string())?;
        channel.exec(command).map_err(|e| e.to_string())?;
        let mut out = String::new();
        let mut err = String::new();
        channel.read_to_string(&mut out).map_err(|e| e.to_string())?;
        channel.stderr().read_to_string(&mut err).map_err(|e| e.to_string())?;
        channel.wait_close().map_err(|e| e.to_string())?;
        Ok((channel.exit_status().map_err(|e| e.to_string())?, out, err))
    }

    pub fn scp_download(&self, remote: &Path, local: &Path) -> Result<(), String> {
        let (mut remote_file, _) = self.session.scp_recv(remote).map_err(|e| e.to_string())?;
        let mut local_file = fs::File::create(local).map_err(|e| e.to_string())?;
        std::io::copy(&mut remote_file, &mut local_file)
            .map(|_| ())
            .map_err(|e| e.to_string())
    }

    pub fn scp_upload(&self, local: &Path, remote: &Path, mode: i32) -> Result<(), String> {
        let mut local_file = fs::File::open(local).map_err(|e| e.to_string())?;
        let metadata = local_file.metadata().map_err(|e| e.to_string())?;
        let mut remote_file = self
            .session
            .scp_send(remote, mode, metadata.len(), None)
            .map_err(|e| e.to_string())?;
        std::io::copy(&mut local_file, &mut remote_file)
            .map(|_| ())
            .map_err(|e| e.to_string())
    }
}

pub fn pull_db_from_peer(ssh_dest: &str, plan_ids: &[i64], local_db: &Path) -> Result<String, String> {
    let client = SshClient::connect(ssh_dest, Duration::from_secs(10))?;
    let _ = client.exec("sqlite3 ~/.claude/data/dashboard.db 'PRAGMA wal_checkpoint(TRUNCATE);'");
    let tmp = std::env::temp_dir().join(format!(
        "mesh-handoff-{}.db",
        SystemTime::now().duration_since(UNIX_EPOCH).map_err(|e| e.to_string())?.as_millis()
    ));
    client.scp_download(Path::new(".claude/data/dashboard.db"), &tmp)?;
    for plan_id in plan_ids {
        let _ = merge_plan_status(*plan_id, local_db, &tmp)?;
    }
    let _ = fs::remove_file(tmp);
    Ok(format!("{} plan(s) synced from {ssh_dest}", plan_ids.len()))
}
