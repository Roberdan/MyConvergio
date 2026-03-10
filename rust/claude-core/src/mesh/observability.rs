//! W3: Observability module — structured logging, metrics, rate limiting.
//! Provides tracing integration, system metrics collection, and connection guards.

use std::collections::{HashMap, VecDeque};
use std::net::IpAddr;
use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::Mutex;
use std::time::{Duration, Instant};

/// T3-02: System metrics — lightweight counters for the daemon
#[derive(Debug)]
pub struct MeshMetrics {
    pub frames_received: AtomicU64,
    pub frames_sent: AtomicU64,
    pub bytes_received: AtomicU64,
    pub bytes_sent: AtomicU64,
    pub auth_failures: AtomicU64,
    pub connections_accepted: AtomicU64,
    pub connections_rejected: AtomicU64,
    pub changes_applied: AtomicU64,
    pub changes_blocked: AtomicU64,
    pub start_time: Instant,
}

impl MeshMetrics {
    pub fn new() -> Self {
        Self {
            frames_received: AtomicU64::new(0),
            frames_sent: AtomicU64::new(0),
            bytes_received: AtomicU64::new(0),
            bytes_sent: AtomicU64::new(0),
            auth_failures: AtomicU64::new(0),
            connections_accepted: AtomicU64::new(0),
            connections_rejected: AtomicU64::new(0),
            changes_applied: AtomicU64::new(0),
            changes_blocked: AtomicU64::new(0),
            start_time: Instant::now(),
        }
    }

    pub fn snapshot(&self) -> serde_json::Value {
        serde_json::json!({
            "frames_received": self.frames_received.load(Ordering::Relaxed),
            "frames_sent": self.frames_sent.load(Ordering::Relaxed),
            "bytes_received": self.bytes_received.load(Ordering::Relaxed),
            "bytes_sent": self.bytes_sent.load(Ordering::Relaxed),
            "auth_failures": self.auth_failures.load(Ordering::Relaxed),
            "connections_accepted": self.connections_accepted.load(Ordering::Relaxed),
            "connections_rejected": self.connections_rejected.load(Ordering::Relaxed),
            "changes_applied": self.changes_applied.load(Ordering::Relaxed),
            "changes_blocked": self.changes_blocked.load(Ordering::Relaxed),
            "uptime_secs": self.start_time.elapsed().as_secs(),
        })
    }
}

impl Default for MeshMetrics {
    fn default() -> Self { Self::new() }
}

/// T3-05: Connection rate limiter — per-IP sliding window
pub struct RateLimiter {
    windows: Mutex<HashMap<IpAddr, Vec<Instant>>>,
    max_per_minute: usize,
    max_concurrent: usize,
    active: Mutex<HashMap<IpAddr, usize>>,
}

impl RateLimiter {
    pub fn new(max_per_minute: usize, max_concurrent: usize) -> Self {
        Self {
            windows: Mutex::new(HashMap::new()),
            max_per_minute,
            max_concurrent,
            active: Mutex::new(HashMap::new()),
        }
    }

    /// Check if a new connection from this IP is allowed
    pub fn check_and_record(&self, ip: IpAddr) -> Result<(), String> {
        // Check concurrent connections
        {
            let active = self.active.lock().unwrap();
            if let Some(&count) = active.get(&ip) {
                if count >= self.max_concurrent {
                    return Err(format!("max concurrent connections ({}) exceeded for {ip}", self.max_concurrent));
                }
            }
        }
        // Check rate limit (sliding window)
        {
            let mut windows = self.windows.lock().unwrap();
            let entry = windows.entry(ip).or_default();
            let cutoff = Instant::now() - Duration::from_secs(60);
            entry.retain(|t| *t > cutoff);
            if entry.len() >= self.max_per_minute {
                return Err(format!("rate limit ({}/min) exceeded for {ip}", self.max_per_minute));
            }
            entry.push(Instant::now());
        }
        // Record active
        {
            let mut active = self.active.lock().unwrap();
            *active.entry(ip).or_insert(0) += 1;
        }
        Ok(())
    }

    /// Release an active connection slot
    pub fn release(&self, ip: IpAddr) {
        let mut active = self.active.lock().unwrap();
        if let Some(count) = active.get_mut(&ip) {
            *count = count.saturating_sub(1);
            if *count == 0 {
                active.remove(&ip);
            }
        }
    }
}

/// T3-04: In-memory log buffer for aggregation API (O(1) push via VecDeque)
pub struct LogBuffer {
    entries: Mutex<VecDeque<LogEntry>>,
    capacity: usize,
}

#[derive(Clone, serde::Serialize)]
pub struct LogEntry {
    pub ts: u64,
    pub level: String,
    pub target: String,
    pub message: String,
    pub node: String,
}

impl LogBuffer {
    pub fn new(capacity: usize) -> Self {
        Self { entries: Mutex::new(VecDeque::with_capacity(capacity)), capacity }
    }

    pub fn push(&self, entry: LogEntry) {
        if self.capacity == 0 { return; }
        let mut entries = self.entries.lock().unwrap();
        if entries.len() >= self.capacity {
            entries.pop_front(); // O(1) vs Vec::remove(0) O(n)
        }
        entries.push_back(entry);
    }

    pub fn recent(&self, limit: usize) -> Vec<LogEntry> {
        let entries = self.entries.lock().unwrap();
        let skip = entries.len().saturating_sub(limit);
        entries.iter().skip(skip).cloned().collect()
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::sync::Arc;

    #[test]
    fn metrics_snapshot_returns_all_counters() {
        let m = MeshMetrics::new();
        m.frames_received.fetch_add(42, Ordering::Relaxed);
        m.auth_failures.fetch_add(3, Ordering::Relaxed);
        let snap = m.snapshot();
        assert_eq!(snap["frames_received"], 42);
        assert_eq!(snap["auth_failures"], 3);
    }

    #[test]
    fn rate_limiter_blocks_excess_connections() {
        let rl = RateLimiter::new(2, 5);
        let ip: IpAddr = "100.98.147.10".parse().unwrap();
        assert!(rl.check_and_record(ip).is_ok());
        assert!(rl.check_and_record(ip).is_ok());
        assert!(rl.check_and_record(ip).is_err()); // 3rd = over limit
    }

    #[test]
    fn rate_limiter_blocks_concurrent() {
        let rl = RateLimiter::new(100, 2);
        let ip: IpAddr = "100.1.2.3".parse().unwrap();
        assert!(rl.check_and_record(ip).is_ok());
        assert!(rl.check_and_record(ip).is_ok());
        assert!(rl.check_and_record(ip).is_err()); // 3rd concurrent
        rl.release(ip);
        assert!(rl.check_and_record(ip).is_ok()); // slot freed
    }

    #[test]
    fn log_buffer_evicts_oldest() {
        let buf = LogBuffer::new(3);
        for i in 0..5 {
            buf.push(LogEntry {
                ts: i, level: "INFO".into(), target: "test".into(),
                message: format!("msg-{i}"), node: "n1".into(),
            });
        }
        let recent = buf.recent(10);
        assert_eq!(recent.len(), 3);
        assert_eq!(recent[0].message, "msg-2"); // oldest surviving
    }

    // === W7: Resilience tests ===

    #[test]
    fn metrics_concurrent_increments() {
        let m = Arc::new(MeshMetrics::new());
        let handles: Vec<_> = (0..10).map(|_| {
            let m = Arc::clone(&m);
            std::thread::spawn(move || {
                for _ in 0..100 {
                    m.frames_received.fetch_add(1, Ordering::Relaxed);
                    m.bytes_received.fetch_add(64, Ordering::Relaxed);
                }
            })
        }).collect();
        for h in handles { h.join().unwrap(); }
        let snap = m.snapshot();
        assert_eq!(snap["frames_received"], 1000);
        assert_eq!(snap["bytes_received"], 64000);
    }

    #[test]
    fn rate_limiter_different_ips_independent() {
        let rl = RateLimiter::new(1, 10);
        let ip1: IpAddr = "10.0.0.1".parse().unwrap();
        let ip2: IpAddr = "10.0.0.2".parse().unwrap();
        assert!(rl.check_and_record(ip1).is_ok());
        assert!(rl.check_and_record(ip1).is_err()); // ip1 at limit
        assert!(rl.check_and_record(ip2).is_ok()); // ip2 independent
    }

    #[test]
    fn log_buffer_zero_capacity() {
        let buf = LogBuffer::new(0);
        buf.push(LogEntry {
            ts: 1, level: "ERROR".into(), target: "test".into(),
            message: "msg".into(), node: "n".into(),
        });
        assert_eq!(buf.recent(10).len(), 0);
    }

    #[test]
    fn log_buffer_recent_limit() {
        let buf = LogBuffer::new(100);
        for i in 0..50 {
            buf.push(LogEntry {
                ts: i, level: "INFO".into(), target: "t".into(),
                message: format!("m{i}"), node: "n".into(),
            });
        }
        assert_eq!(buf.recent(5).len(), 5);
        assert_eq!(buf.recent(5).last().unwrap().message, "m49");
    }
}
