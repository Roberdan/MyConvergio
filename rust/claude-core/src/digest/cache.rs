use serde_json::Value;
use std::collections::HashMap;
use std::time::{Duration, Instant};

#[derive(Debug, Clone)]
struct CacheEntry {
    value: Value,
    created_at: Instant,
}

#[derive(Debug, Default)]
pub struct DigestCache {
    entries: HashMap<String, CacheEntry>,
}

impl DigestCache {
    pub fn new() -> Self {
        Self::default()
    }

    pub fn set<K: Into<String>>(&mut self, key: K, value: Value) {
        self.entries.insert(
            key.into(),
            CacheEntry {
                value,
                created_at: Instant::now(),
            },
        );
    }

    pub fn get(&mut self, key: &str, ttl: Duration) -> Option<Value> {
        let entry = self.entries.get(key)?;
        if entry.created_at.elapsed() < ttl {
            return Some(entry.value.clone());
        }
        self.entries.remove(key);
        None
    }

    pub fn clear(&mut self, key: &str) -> bool {
        self.entries.remove(key).is_some()
    }

    pub fn flush(&mut self) {
        self.entries.clear();
    }
}
