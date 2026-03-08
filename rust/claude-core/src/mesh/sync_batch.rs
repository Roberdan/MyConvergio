use std::time::{SystemTime, UNIX_EPOCH};

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct SyncBatchWindow {
    window_ms: u64,
    since_ms: Option<u64>,
    last_checkpoint: i64,
}

impl SyncBatchWindow {
    pub fn new(window_ms: u64) -> Self { Self { window_ms, since_ms: None, last_checkpoint: 0 } }
    pub fn observe_change(&mut self, checkpoint: i64) {
        self.observe_change_at(current_time_ms(), checkpoint);
    }
    pub fn observe_change_at(&mut self, now_ms_value: u64, checkpoint: i64) {
        self.last_checkpoint = checkpoint;
        if self.since_ms.is_none() { self.since_ms = Some(now_ms_value); }
    }
    pub fn should_flush(&self, now_ms_value: u64) -> bool {
        self.since_ms.map(|since| now_ms_value.saturating_sub(since) >= self.window_ms).unwrap_or(false)
    }
    pub fn clear(&mut self) { self.since_ms = None; }
    pub fn take_checkpoint(&self) -> i64 { self.last_checkpoint }
}

pub fn current_time_ms() -> u64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|d| d.as_millis() as u64)
        .unwrap_or(0)
}
