mod auth;
mod config;
mod logger;
mod proxy;
mod rate_limit;

use axum::{
    extract::{Request, State},
    middleware,
    response::Response,
    routing::any,
    Router,
};
use proxy::HttpClient;
use std::{net::SocketAddr, sync::Arc};
use tower_http::trace::TraceLayer;

#[derive(Clone)]
struct AppState {
    cfg: Arc<config::Config>,
    client: HttpClient,
}

async fn core_handler(State(s): State<AppState>, req: Request) -> Response {
    proxy::forward(&s.client, req, &s.cfg.upstreams.core_banking).await
}

async fn notification_handler(State(s): State<AppState>, req: Request) -> Response {
    proxy::forward(&s.client, req, &s.cfg.upstreams.notification).await
}

async fn ai_handler(State(s): State<AppState>, req: Request) -> Response {
    proxy::forward(&s.client, req, &s.cfg.upstreams.ai_service).await
}

#[tokio::main]
async fn main() {
    tracing_subscriber::fmt::init();

    let cfg = Arc::new(config::load());
    let jwt_secret = cfg.auth.jwt_secret.clone();
    let limiter = rate_limit::new_limiter(cfg.rate_limit.requests_per_second);
    let log = logger::open_log().await;
    let state = AppState { cfg, client: HttpClient::new() };

    let app = Router::new()
        .route("/api/transactions/*path", any(core_handler))
        .route("/api/notifications/*path", any(notification_handler))
        .route("/api/ai/*path", any(ai_handler))
        .route_layer(middleware::from_fn_with_state(jwt_secret, auth::jwt_middleware))
        .route_layer(middleware::from_fn_with_state(limiter, rate_limit::rate_limit_middleware))
        .route_layer(middleware::from_fn_with_state(log, logger::log_middleware))
        .layer(TraceLayer::new_for_http())
        .with_state(state)
        .into_make_service_with_connect_info::<SocketAddr>();

    let listener = tokio::net::TcpListener::bind("0.0.0.0:3000").await.unwrap();
    tracing::info!("titan-gateway listening on :3000");
    axum::serve(listener, app).await.unwrap();
}
