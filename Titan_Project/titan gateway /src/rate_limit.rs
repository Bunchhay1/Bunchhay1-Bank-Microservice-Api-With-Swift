use axum::{
    extract::{ConnectInfo, Request, State},
    http::StatusCode,
    middleware::Next,
    response::{IntoResponse, Response},
};
use governor::{DefaultKeyedRateLimiter, Quota, RateLimiter};
use nonzero_ext::nonzero;
use std::{net::SocketAddr, sync::Arc};

pub type SharedLimiter = Arc<DefaultKeyedRateLimiter<std::net::IpAddr>>;

pub fn new_limiter(rps: u32) -> SharedLimiter {
    let quota = Quota::per_second(
        std::num::NonZeroU32::new(rps).unwrap_or(nonzero!(10u32)),
    );
    Arc::new(RateLimiter::keyed(quota))
}

pub async fn rate_limit_middleware(
    State(limiter): State<SharedLimiter>,
    ConnectInfo(addr): ConnectInfo<SocketAddr>,
    req: Request,
    next: Next,
) -> Response {
    match limiter.check_key(&addr.ip()) {
        Ok(_) => next.run(req).await,
        Err(_) => (StatusCode::TOO_MANY_REQUESTS, "Rate limit exceeded — IP blocked").into_response(),
    }
}
