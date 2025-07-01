use actix_web::{HttpResponse, Responder, web};
use bcrypt::verify;
use chrono::{Duration, Utc};
use serde_json::{Value, json};
use reqwest::Client as ReqwestClient;
use reqwest::header::AUTHORIZATION;
use crate::models::LoginRequest;
use crate::utils::create_jwt;

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

    let api_url = format!("{}/api2/json/version", url.trim_end_matches('/').trim_end_matches("/api2/json"));
    let auth_header = format!(
        "PVEAPIToken={}!{}={}",
        format!("{username}@{realm}"), token_name, token_secret
    );

    println!("Making request to: {}", api_url);
    println!("Using auth header: {}", auth_header);

    let client = ReqwestClient::builder()
        .danger_accept_invalid_certs(true)
        .build()
        .unwrap();

    match client.get(&api_url)
        .header(AUTHORIZATION, auth_header)
        .send()
        .await
    {
        Ok(resp) => {
            if resp.status().is_success() {
                match resp.json::<Value>().await {
                    Ok(version) => HttpResponse::Ok().json(version),
                    Err(e) => HttpResponse::InternalServerError().json(json!({"error": e.to_string()}))
                }
            } else {
                HttpResponse::InternalServerError().json(json!({"error": resp.status().to_string()}))
            }
        },
        Err(e) => HttpResponse::InternalServerError().json(json!({"error": e.to_string()}))
    }
}

pub async fn get_nodes() -> impl Responder {
    dotenv::dotenv().ok();
    let url = std::env::var("PROXMOX_URL").unwrap();
    let realm = std::env::var("PROXMOX_REALM").unwrap();
    let username = std::env::var("PROXMOX_USERNAME").unwrap();
    let token_name = std::env::var("PROXMOX_TOKEN_NAME").unwrap();
    let token_secret = std::env::var("PROXMOX_TOKEN_SECRET").unwrap();

    let api_url = format!("{}/api2/json/nodes", url.trim_end_matches('/').trim_end_matches("/api2/json"));
    let auth_header = format!(
        "PVEAPIToken={}!{}={}",
        format!("{username}@{realm}"), token_name, token_secret
    );

    println!("Making request to: {}", api_url);
    println!("Using auth header: {}", auth_header);

    let client = ReqwestClient::builder()
        .danger_accept_invalid_certs(true)
        .build()
        .unwrap();

    match client.get(&api_url)
        .header(AUTHORIZATION, auth_header)
        .send()
        .await
    {
        Ok(resp) => {
            if resp.status().is_success() {
                match resp.json::<Value>().await {
                    Ok(nodes) => {
                        println!("PVE nodes info: {:#?}", nodes);
                        HttpResponse::Ok().json(nodes)
                    },
                    Err(e) => HttpResponse::InternalServerError().json(json!({"error": e.to_string()}))
                }
            } else {
                HttpResponse::InternalServerError().json(json!({"error": resp.status().to_string()}))
            }
        },
        Err(e) => HttpResponse::InternalServerError().json(json!({"error": e.to_string()}))
    }
}