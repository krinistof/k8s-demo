#[macro_use] extern crate rocket;
use rocket::info;
use uuid::Uuid;
use std::env;

#[get("/")]
fn index() -> Result<String, String> {
    let log_id = Uuid::new_v4();
    info!("Log id: {log_id}");
    let error_resp = Err(format!(r"Internal server error. Contact IT with log id: {log_id}"));
    let Ok(stage) = env::var("STAGE") else {
        return error_resp; 
    };
    let Ok(secret_message) = env::var("SECRET_MESSAGE") else {
        return error_resp; 
    };
    Ok(format!("Hello World! I am on {stage} stage. This is my secret: {secret_message}."))
}

#[launch]
fn rocket() -> _ {
    rocket::build().mount("/", routes![index])
}
