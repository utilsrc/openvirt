use actix_web::{web, App, HttpServer};
use dotenv::dotenv;

mod routes;
mod models;
mod handlers;
mod middleware;
mod utils;

#[actix_web::main]
async fn main() -> std::io::Result<()> {
    dotenv().ok();

    HttpServer::new(|| {
        App::new()
            .configure(routes::config)
    })
    .bind("127.0.0.1:8081")?
    .run()
    .await
}
