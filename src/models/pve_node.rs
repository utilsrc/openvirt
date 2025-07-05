use serde::{Deserialize, Serialize};
use chrono::{DateTime, Utc};
use uuid::Uuid;

#[derive(Debug, Serialize, Deserialize, sqlx::FromRow)]
pub struct PveNode {
    pub id: Uuid,
    pub name: String,
    pub hostname: String,
    pub ip_address: String,
    pub port: i32,
    pub username: String,
    pub password_encrypted: String,
    pub api_token: Option<String>,
    pub status: String,
    pub location: Option<String>,
    pub max_cpu: i32,
    pub max_memory_gb: i32,
    pub max_storage_gb: i32,
    pub used_cpu: i32,
    pub used_memory_gb: i32,
    pub used_storage_gb: i32,
    pub created_at: DateTime<Utc>,
    pub last_heartbeat: Option<DateTime<Utc>>,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct PveNodeCreateRequest {
    pub name: String,
    pub hostname: String,
    pub ip_address: String,
    pub port: Option<i32>,
    pub username: String,
    pub password: String,
    pub location: Option<String>,
    pub max_cpu: i32,
    pub max_memory_gb: i32,
    pub max_storage_gb: i32,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct PveNodeStatus {
    pub cpu_usage: f64,
    pub memory_usage: f64,
    pub disk_usage: f64,
    pub uptime: i64,
    pub load_average: [f64; 3],
}
