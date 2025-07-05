use actix_web::{App, HttpServer, web};
use dotenv::dotenv;
use sqlx::migrate::MigrateError;

mod routes;
mod models;
mod handlers;
mod middleware;
mod utils;
mod database;

use database::{create_pool, DbPool};

async fn run_migrations(pool: &DbPool) {
    if let Err(e) = database::migrate(pool).await {
        panic!("Failed to run database migrations: {}", e);
    }
}

#[actix_web::main]
async fn main() -> std::io::Result<()> {
    dotenv().ok();

    let server_address = std::env::var("SERVER_ADDRESS")
        .expect("SERVER_ADDRESS must be set in .env file");

    println!("Server started, listening on: {}", server_address);

    let db_pool = create_pool().await.expect("Failed to create database pool");
    run_migrations(&db_pool).await;

    HttpServer::new(move || {
        App::new()
            .app_data(web::Data::new(db_pool.clone()))
            .configure(routes::config)
    })
    .bind(server_address)?
    .run()
    .await
}
