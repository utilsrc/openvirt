use actix_web::web;
use crate::handlers;
use crate::middleware;

pub fn config(cfg: &mut web::ServiceConfig) {
    cfg.service(
        web::scope("/api")
            .route("/health", web::get().to(handlers::health_check))
            .route("/login", web::post().to(handlers::login))
            .route("/version", web::get().to(handlers::get_version))
            .route("/client_version", web::get().to(handlers::get_client_version))
            .service(
                web::scope("/protected")
                    .wrap(actix_web_httpauth::middleware::HttpAuthentication::bearer(
                        middleware::jwt_validator,
                    ))
            )
    );
}
