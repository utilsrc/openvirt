use actix_web::{dev::ServiceRequest, Error};
use actix_web_httpauth::extractors::bearer::BearerAuth;

use crate::utils::validate_jwt;

pub async fn jwt_validator(
    req: ServiceRequest,
    credentials: BearerAuth,
) -> Result<ServiceRequest, (Error, ServiceRequest)> {
    let secret = std::env::var("JWT_SECRET").expect("JWT_SECRET must be set");
    match validate_jwt(credentials.token(), &secret) {
        Ok(_) => Ok(req),
        Err(e) => Err((actix_web::error::ErrorUnauthorized(e.to_string()), req))
    }
}
