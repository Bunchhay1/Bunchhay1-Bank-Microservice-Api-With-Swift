use serde::Deserialize;
use std::fs;

#[derive(Deserialize, Clone)]
pub struct Config {
    pub upstreams: Upstreams,
    pub auth: Auth,
    pub rate_limit: RateLimit,
}

#[derive(Deserialize, Clone)]
pub struct Upstreams {
    pub core_banking: String,
    pub notification: String,
    pub promotion: String,
    pub ai_service: String,
}

#[derive(Deserialize, Clone)]
pub struct Auth {
    pub jwt_secret: String,
}

#[derive(Deserialize, Clone)]
pub struct RateLimit {
    pub requests_per_second: u32,
}

pub fn load() -> Config {
    let content = fs::read_to_string("config.toml").expect("config.toml not found");
    toml::from_str(&content).expect("Invalid config.toml")
}
