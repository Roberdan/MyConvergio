use super::state::ServerState;
use axum::extract::ws::{Message, WebSocket, WebSocketUpgrade};
use axum::extract::State;
use axum::response::{IntoResponse, Response};
use serde_json::{json, Value};
use tokio::select;
use tokio::sync::broadcast;

pub async fn ws_dashboard(
    ws: WebSocketUpgrade,
    State(state): State<ServerState>,
) -> Response {
    ws.on_upgrade(move |socket| {
        handle_ws(socket, state.ws_tx.subscribe(), json!({"type": "refresh"}))
    })
    .into_response()
}

pub async fn ws_brain(
    ws: WebSocketUpgrade,
    State(state): State<ServerState>,
) -> Response {
    ws.on_upgrade(move |socket| {
        handle_ws(
            socket,
            state.ws_tx.subscribe(),
            json!({"kind": "heartbeat_snapshot", "payload": {"nodes": {}}}),
        )
    })
    .into_response()
}

async fn handle_ws(
    mut socket: WebSocket,
    mut rx: broadcast::Receiver<Value>,
    init_message: Value,
) {
    if socket
        .send(Message::Text(init_message.to_string()))
        .await
        .is_err()
    {
        return;
    }

    loop {
        select! {
            inbound = socket.recv() => {
                match inbound {
                    Some(Ok(Message::Close(_))) | None | Some(Err(_)) => break,
                    Some(Ok(Message::Ping(payload))) => {
                        if socket.send(Message::Pong(payload)).await.is_err() {
                            break;
                        }
                    }
                    _ => {}
                }
            }
            outbound = rx.recv() => {
                match outbound {
                    Ok(event) => {
                        if socket.send(Message::Text(event.to_string())).await.is_err() {
                            break;
                        }
                    }
                    Err(broadcast::error::RecvError::Lagged(_)) => continue,
                    Err(broadcast::error::RecvError::Closed) => break,
                }
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::super::state::ServerState;
    use serde_json::json;
    use std::path::PathBuf;

    #[test]
    fn ws_channel_accepts_realtime_messages() {
        let state = ServerState::new(PathBuf::from("/tmp/test.db"));
        let mut rx = state.ws_tx.subscribe();
        state
            .ws_tx
            .send(json!({"type":"notification","message":"ok"}))
            .expect("publish");
        let msg = rx.try_recv().expect("recv");
        assert_eq!(msg["type"], "notification");
    }
}
