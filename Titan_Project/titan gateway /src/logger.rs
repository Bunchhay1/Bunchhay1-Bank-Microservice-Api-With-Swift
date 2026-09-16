use axum::{
    extract::{ConnectInfo, Request, State},
    middleware::Next,
    response::Response,
};
use chrono::Utc;
use std::{net::SocketAddr, sync::Arc};
use tokio::{fs::OpenOptions, io::AsyncWriteExt, sync::Mutex};

pub type SharedLog = Arc<Mutex<tokio::fs::File>>;

pub async fn open_log() -> SharedLog {
    let file = OpenOptions::new()
        .create(true)
        .append(true)
        .open("gateway.log")
        .await
        .expect("Cannot open gateway.log");
    Arc::new(Mutex::new(file))
}

pub async fn log_middleware(
    State(log): State<SharedLog>,
    ConnectInfo(addr): ConnectInfo<SocketAddr>,
    req: Request,
    next: Next,
) -> Response {
    let method = req.method().clone();
    let path = req.uri().path().to_string();
    let start = std::time::Instant::now();

    let resp = next.run(req).await;

    let line = format!(
        "{} {} {} {} {}ms\n",
        Utc::now().format("%Y-%m-%dT%H:%M:%S"),
        addr.ip(),
        method,
        path,
        start.elapsed().as_millis()
    );

    let mut file = log.lock().await;
    let _ = file.write_all(line.as_bytes()).await;

    resp
}
