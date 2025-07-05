use actix_web::{web, HttpResponse, Responder};
use serde_json::json;
use bcrypt::{hash, DEFAULT_COST};
use chrono::{Duration, Utc};
use uuid::Uuid;
use sqlx::PgPool;
use log::{info, error};
use crate::models::user::{User, LoginRequest, EmailVerification, ResetPasswordRequest};
use crate::utils::create_jwt;

use serde::{Deserialize, Serialize};

#[derive(Debug, Serialize, Deserialize)]
pub struct RegisterRequest {
    pub username: String,
    pub email: Option<String>,
    pub phone: Option<String>,
    pub password: String,
}

pub async fn register(
    pool: web::Data<PgPool>,
    user_data: web::Json<RegisterRequest>,
) -> impl Responder {
    let hashed_password = match hash(&user_data.password, DEFAULT_COST) {
        Ok(hash) => hash,
        Err(_) => return HttpResponse::InternalServerError().json(json!({"error": "密码加密失败"}))
    };

    let user = User {
        id: Uuid::new_v4(),
        username: user_data.username.clone(),
        email: user_data.email.clone(),
        phone: user_data.phone.clone(),
        password_hash: hashed_password,
        salt: Uuid::new_v4().to_string(),
        real_name: None,
        status: "active".to_string(),
        phone_verified: false,
        email_verified: false,
        balance: 0.0,
        role: "user".to_string(),
        created_at: Utc::now(),
        updated_at: Utc::now(),
        last_login: None,
        login_count: 0,
        avatar_url: None,
        province: None,
        city: None,
        two_factor_enabled: false,
    };

    match sqlx::query_as::<_, User>(
        r#"
        INSERT INTO users (username, email, phone, password_hash, salt, status)
        VALUES ($1, $2, $3, $4, $5, $6)
        RETURNING *
        "#
    )
    .bind(&user.username)
    .bind(&user.email)
    .bind(&user.phone)
    .bind(&user.password_hash)
    .bind(&user.salt)
    .bind("active")
    .fetch_one(&**pool)
    .await
    {
        Ok(user) => HttpResponse::Ok().json(json!({
            "message": "注册成功",
            "user": {
                "id": user.id,
                "username": user.username,
                "email": user.email,
                "phone": user.phone
            }
        })),
        Err(e) => {
            error!("注册失败: {}", e);
            if e.to_string().contains("duplicate key") {
                HttpResponse::Conflict().json(json!({"error": "用户名/邮箱/手机号已存在"}))
            } else {
                HttpResponse::InternalServerError().json(json!({
                    "error": "注册失败",
                    "details": e.to_string()
                }))
            }
        }
    }
}

pub async fn login(
    pool: web::Data<PgPool>,
    login_data: web::Json<LoginRequest>,
) -> impl Responder {
    let user = match sqlx::query_as::<_, User>(
        "SELECT * FROM users WHERE username = $1 OR email = $1 OR phone = $1"
    )
    .bind(&login_data.username)
    .fetch_optional(&**pool)
    .await
    {
        Ok(Some(user)) => user,
        Ok(None) => return HttpResponse::Unauthorized().json(json!({"error": "用户名或密码错误"})),
        Err(_) => return HttpResponse::InternalServerError().json(json!({"error": "登录失败"}))
    };

    if !bcrypt::verify(&login_data.password, &user.password_hash).unwrap_or(false) {
        return HttpResponse::Unauthorized().json(json!({"error": "用户名或密码错误"}));
    }

    let jwt_secret = std::env::var("JWT_SECRET").unwrap_or_else(|_| "secret".to_string());
    let expiry = Utc::now() + Duration::days(7);
    
    match create_jwt(&user.username, &jwt_secret, expiry) {
        Ok(token) => {
            // 更新用户登录信息
            let _ = sqlx::query(
                "UPDATE users SET last_login = $1, login_count = login_count + 1 WHERE id = $2"
            )
            .bind(Utc::now())
            .bind(&user.id)
            .execute(&**pool)
            .await;

            HttpResponse::Ok().json(json!({
                "message": "登录成功",
                "token": token,
                "expires_at": expiry.to_rfc3339(),
                "user": {
                    "id": user.id,
                    "username": user.username,
                    "email": user.email,
                    "phone": user.phone
                }
            }))
        },
        Err(_) => HttpResponse::InternalServerError().json(json!({"error": "令牌生成失败"}))
    }
}

pub async fn logout(
    pool: web::Data<PgPool>,
    req: actix_web::HttpRequest,
) -> impl Responder {
    let auth_header = req.headers().get("Authorization");
    let token = match auth_header {
        Some(header) => {
            let header_str = header.to_str().unwrap_or("");
            if header_str.starts_with("Bearer ") {
                header_str[7..].to_string()
            } else {
                return HttpResponse::BadRequest().json(json!({"error": "无效的授权头"}));
            }
        }
        None => return HttpResponse::Unauthorized().json(json!({"error": "缺少授权令牌"})),
    };

    let jwt_secret = std::env::var("JWT_SECRET").unwrap_or_else(|_| "secret".to_string());
    let claims = match crate::utils::validate_jwt(&token, &jwt_secret) {
        Ok(claims) => claims,
        Err(_) => return HttpResponse::Unauthorized().json(json!({"error": "无效令牌"})),
    };

    // 将令牌加入黑名单
    match sqlx::query(
        r#"
        INSERT INTO user_sessions (user_id, token_hash, expires_at)
        VALUES ($1, $2, $3)
        "#
    )
    .bind(Uuid::parse_str(&claims.sub).ok())
    .bind(&token)
    .bind(Utc::now() + Duration::hours(1)) // 令牌失效时间比JWT过期时间稍长
    .execute(&**pool)
    .await
    {
        Ok(_) => HttpResponse::Ok().json(json!({"message": "登出成功"})),
        Err(_) => HttpResponse::InternalServerError().json(json!({"error": "登出失败"})),
    }
}

pub async fn refresh(
    pool: web::Data<PgPool>,
    req: actix_web::HttpRequest,
) -> impl Responder {
    let auth_header = req.headers().get("Authorization");
    let token = match auth_header {
        Some(header) => {
            let header_str = header.to_str().unwrap_or("");
            if header_str.starts_with("Bearer ") {
                header_str[7..].to_string()
            } else {
                return HttpResponse::BadRequest().json(json!({"error": "无效的授权头"}));
            }
        }
        None => return HttpResponse::Unauthorized().json(json!({"error": "缺少授权令牌"})),
    };

    let jwt_secret = std::env::var("JWT_SECRET").unwrap_or_else(|_| "secret".to_string());
    let claims = match crate::utils::validate_jwt(&token, &jwt_secret) {
        Ok(claims) => claims,
        Err(_) => return HttpResponse::Unauthorized().json(json!({"error": "无效令牌"})),
    };

    // 将旧令牌加入黑名单
    let _ = sqlx::query(
        r#"
        INSERT INTO user_sessions (user_id, token_hash, expires_at)
        VALUES ($1, $2, $3)
        "#
    )
    .bind(Uuid::parse_str(&claims.sub).ok())
    .bind(&token)
    .bind(Utc::now() + Duration::hours(1))
    .execute(&**pool)
    .await;

    // 生成新令牌
    let expiry = Utc::now() + Duration::days(7);
    match create_jwt(&claims.sub, &jwt_secret, expiry) {
        Ok(new_token) => HttpResponse::Ok().json(json!({
            "message": "令牌刷新成功",
            "token": new_token,
            "expires_at": expiry.to_rfc3339()
        })),
        Err(_) => HttpResponse::InternalServerError().json(json!({"error": "令牌生成失败"}))
    }
}

pub async fn verify(
    pool: web::Data<PgPool>,
    verification_data: web::Json<EmailVerification>,
) -> impl Responder {
    // 查询验证码记录
    let record = match sqlx::query_as::<_, EmailVerification>(
        "SELECT * FROM email_verifications 
        WHERE email = $1 AND code = $2 AND purpose = $3 AND used = false AND expires_at > NOW()"
    )
    .bind(&verification_data.email)
    .bind(&verification_data.code)
    .bind(&verification_data.purpose)
    .fetch_optional(&**pool)
    .await
    {
        Ok(Some(record)) => record,
        Ok(None) => return HttpResponse::BadRequest().json(json!({"error": "无效验证码"})),
        Err(_) => return HttpResponse::InternalServerError().json(json!({"error": "验证失败"}))
    };

    // 标记验证码为已使用
    let _ = sqlx::query(
        "UPDATE email_verifications SET used = true WHERE id = $1"
    )
    .bind(&record.id)
    .execute(&**pool)
    .await;

    // 根据验证目的更新用户状态
    match verification_data.purpose.as_str() {
        "register" => {
            let _ = sqlx::query(
                "UPDATE users SET email_verified = true WHERE email = $1"
            )
            .bind(&verification_data.email)
            .execute(&**pool)
            .await;
        }
        "reset_password" => {
            // 重置密码流程会在下一步处理
        }
        _ => {}
    }

    HttpResponse::Ok().json(json!({
        "message": "验证成功",
        "email": verification_data.email,
        "purpose": verification_data.purpose
    }))
}

pub async fn reset_password(
    pool: web::Data<PgPool>,
    reset_data: web::Json<ResetPasswordRequest>,
) -> impl Responder {
    // 验证验证码
    let _ = match sqlx::query_as::<_, EmailVerification>(
        "SELECT * FROM email_verifications 
        WHERE email = $1 AND code = $2 AND purpose = 'reset_password' AND used = false AND expires_at > NOW()"
    )
    .bind(&reset_data.email)
    .bind(&reset_data.code)
    .fetch_optional(&**pool)
    .await
    {
        Ok(Some(_)) => (),
        _ => return HttpResponse::BadRequest().json(json!({"error": "无效验证码"}))
    };

    // 标记验证码为已使用
    let _ = sqlx::query(
        "UPDATE email_verifications SET used = true 
        WHERE email = $1 AND code = $2 AND purpose = 'reset_password'"
    )
    .bind(&reset_data.email)
    .bind(&reset_data.code)
    .execute(&**pool)
    .await;

    // 加密新密码
    let hashed_password = match hash(&reset_data.new_password, DEFAULT_COST) {
        Ok(hash) => hash,
        Err(_) => return HttpResponse::InternalServerError().json(json!({"error": "密码加密失败"}))
    };

    // 更新用户密码
    match sqlx::query(
        "UPDATE users SET password_hash = $1 WHERE email = $2"
    )
    .bind(&hashed_password)
    .bind(&reset_data.email)
    .execute(&**pool)
    .await
    {
        Ok(_) => HttpResponse::Ok().json(json!({"message": "密码重置成功"})),
        Err(_) => HttpResponse::InternalServerError().json(json!({"error": "密码重置失败"}))
    }
}
