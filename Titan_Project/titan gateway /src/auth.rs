use axum::{
    extract::{Request, State},
    http::StatusCode,
    middleware::Next,
    response::{IntoResponse, Response},
};
use jsonwebtoken::{decode, DecodingKey, Validation};
use serde::{Deserialize, Serialize};

#[derive(Deserialize, Serialize)]
struct Claims {
    sub: String,
    exp: usize,
}

pub async fn jwt_middleware(
    State(secret): State<String>,
    req: Request,
    next: Next,
) -> Response {
    let token = req
        .headers()
        .get("Authorization")
        .and_then(|v| v.to_str().ok())
        .and_then(|v| v.strip_prefix("Bearer "));

    match token {
        Some(t) => {
            let key = DecodingKey::from_secret(secret.as_bytes());
            match decode::<Claims>(t, &key, &Validation::default()) {
                Ok(_) => next.run(req).await,
                Err(_) => (StatusCode::UNAUTHORIZED, "Invalid token").into_response(),
            }
        }
        None => (StatusCode::UNAUTHORIZED, "Missing Authorization header").into_response(),
    }
}
