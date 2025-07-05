use sqlx::postgres::PgPoolOptions;
use sqlx::{Pool, Postgres, migrate::MigrateError};
use std::env;
use std::time::Duration;

pub type DbPool = Pool<Postgres>;

pub async fn create_pool() -> Result<DbPool, sqlx::Error> {
    let database_url = env::var("DATABASE_URL")
        .expect("DATABASE_URL must be set in .env file");

    PgPoolOptions::new()
        .max_connections(5)
        .acquire_timeout(Duration::from_secs(3))
        .connect(&database_url)
        .await
}

pub async fn migrate(pool: &DbPool) -> Result<(), MigrateError> {
    sqlx::migrate!("./migrations")
        .set_ignore_missing(true)
        .run(pool)
        .await
}
