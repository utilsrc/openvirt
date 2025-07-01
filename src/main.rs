use actix_web::{App, HttpServer};
use dotenv::dotenv;

mod routes;
mod models;
mod handlers;
mod middleware;
mod utils;

#[actix_web::main]
async fn main() -> std::io::Result<()> {
    dotenv().ok();

    let server_address = std::env::var("SERVER_ADDRESS")
        .expect("SERVER_ADDRESS must be set in .env file");

    println!("Server started, listening on: {}", server_address);

    HttpServer::new(|| {
        App::new()
            .configure(routes::config)
    })
    .bind(server_address)?
    .run()
    .await
}
