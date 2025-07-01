use actix_web::http::StatusCode;
use actix_web::web;
use actix_web::HttpResponse;
use crate::handlers;
use crate::middleware;

pub fn config(cfg: &mut web::ServiceConfig) {
    cfg.service(
        web::scope("/api")
            .route("/health", web::get().to(handlers::health_check))
            .route("/login", web::post().to(handlers::login))
            .route("/version", web::get().to(handlers::get_version))
            .route("/nodes", web::get().to(handlers::get_nodes))
            .service(
                web::scope("/protected")
                    .wrap(actix_web_httpauth::middleware::HttpAuthentication::bearer(
                        middleware::jwt_validator,
                    ))
            )
            // 404 处理
            .default_service(web::route().to(|| async {
                HttpResponse::NotFound()
                    .json(serde_json::json!({
                        "code": StatusCode::NOT_FOUND.as_u16(),
                        "message": "Resource not found"
                    }))
            }))
    );
}
