use axum::{
    body::Body,
    extract::Request,
    http::StatusCode,
    response::{IntoResponse, Response},
};
use hyper::Uri;
use hyper_util::{client::legacy::Client, rt::TokioExecutor};

// Shared client — reuses TCP connections across requests (connection pooling)
#[derive(Clone)]
pub struct HttpClient(pub Client<hyper_util::client::legacy::connect::HttpConnector, Body>);

impl HttpClient {
    pub fn new() -> Self {
        Self(Client::builder(TokioExecutor::new()).build_http::<Body>())
    }
}

pub async fn forward(client: &HttpClient, mut req: Request, upstream: &str) -> Response {
    let path = req
        .uri()
        .path_and_query()
        .map(|p| p.as_str())
        .unwrap_or("/");

    let uri: Uri = format!("{}{}", upstream, path)
        .parse()
        .unwrap_or_else(|_| upstream.parse().unwrap());

    *req.uri_mut() = uri;

    match client.0.request(req).await {
        Ok(resp) => resp.into_response(),
        Err(e) => (StatusCode::BAD_GATEWAY, e.to_string()).into_response(),
    }
}
