use serde_json::{Map, Value};

pub mod cache;
pub use cache::DigestCache;

pub fn as_json(value: Value) -> String {
    compact_value(value).to_string()
}

fn compact_value(value: Value) -> Value {
    match value {
        Value::Object(object) => Value::Object(compact_object(object)),
        Value::Array(items) => Value::Array(
            items
                .into_iter()
                .map(|item| match item {
                    Value::Object(object) => Value::Object(compact_object(object)),
                    other => other,
                })
                .collect(),
        ),
        other => other,
    }
}

fn compact_object(object: Map<String, Value>) -> Map<String, Value> {
    object
        .into_iter()
        .filter(|(_, value)| !is_compact_default(value))
        .collect()
}

fn is_compact_default(value: &Value) -> bool {
    match value {
        Value::Null => true,
        Value::Bool(false) => true,
        Value::Number(number) => {
            number.as_u64() == Some(0) || number.as_i64() == Some(0) || number.as_f64() == Some(0.0)
        }
        Value::Array(items) => items.is_empty(),
        Value::Object(object) => object.is_empty(),
        _ => false,
    }
}

#[cfg(test)]
mod tests {
    use super::{as_json, DigestCache};
    use serde_json::json;
    use std::thread::sleep;
    use std::time::Duration;

    #[test]
    fn as_json_strips_compact_defaults() {
        let value = json!({
            "status": "ok",
            "keep_false_str": "false",
            "keep_zero_str": "0",
            "drop_null": null,
            "drop_zero": 0,
            "drop_false": false,
            "drop_empty_array": [],
            "drop_empty_object": {}
        });

        let actual: serde_json::Value = serde_json::from_str(&as_json(value)).expect("valid json");
        let expected = json!({
            "status": "ok",
            "keep_false_str": "false",
            "keep_zero_str": "0"
        });
        assert_eq!(actual, expected);
    }

    #[test]
    fn cache_respects_ttl() {
        let mut cache = DigestCache::new();
        cache.set("k", json!({"value": 1}));
        assert_eq!(cache.get("k", Duration::from_secs(1)), Some(json!({"value": 1})));

        sleep(Duration::from_millis(20));
        assert_eq!(cache.get("k", Duration::from_millis(5)), None);
    }
}
