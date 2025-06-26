use actix_web::{web, App, HttpServer};
use dotenv::dotenv;
use std::thread;

mod routes;
mod models;
mod handlers;
mod middleware;
mod utils;
mod http;

fn main() -> std::io::Result<()> {
    dotenv().ok();

    // 在新线程中运行actix-web服务
    thread::spawn(move || {
        actix_web::rt::System::new()
            .block_on(async {
                HttpServer::new(|| {
                    App::new()
                        .configure(routes::config)
                })
                .bind("127.0.0.1:8081")?
                .run()
                .await
            })
            .unwrap();
    });

    // 主线程保持运行
    loop {
        thread::park();
    }
}
