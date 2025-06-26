use actix_web::{HttpResponse, Responder, web};
use bcrypt::verify;
use chrono::{Duration, Utc};
use serde_json::Value;
use url::Url;
use crate::models::LoginRequest;
use crate::utils::create_jwt;
use crate::http::{AuthMethod, ClientBuilder, HttpClient};

pub async fn health_check() -> impl Responder {
    HttpResponse::Ok().json("OK")
}

pub async fn login(login_data: web::Json<LoginRequest>) -> impl Responder {
    // TODO: 实际验证用户逻辑
    let is_valid = verify(&login_data.password, "hashed_password_from_db").unwrap_or(false);
    
    if !is_valid {
        return HttpResponse::Unauthorized().json("Invalid credentials");
    }

    let secret = std::env::var("JWT_SECRET").expect("JWT_SECRET must be set");
    let expiry = Utc::now() + Duration::hours(24);
    let token = create_jwt(&login_data.username, &secret, expiry).unwrap();

    HttpResponse::Ok().json(token)
}

pub async fn get_version() -> impl Responder {
    dotenv::dotenv().ok();
    let url = std::env::var("PROXMOX_URL").unwrap();
    let realm = std::env::var("PROXMOX_REALM").unwrap();
    let username = std::env::var("PROXMOX_USERNAME").unwrap();
    let token_name = std::env::var("PROXMOX_TOKEN_NAME").unwrap();
    let token_secret = std::env::var("PROXMOX_TOKEN_SECRET").unwrap();

    let auth = AuthMethod::token(format!("{username}@{realm}"), token_name, token_secret);

    let http_client = ClientBuilder::default()
        .with_base_url(Url::parse(&url).unwrap())
        .with_insecure_tls(true)
        .with_auth_method(auth)
        .build()
        .unwrap();

    let version: Value = http_client.get("api2/json/version", &()).unwrap();
    HttpResponse::Ok().json(version)
}
