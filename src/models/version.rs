use serde::Serialize;
use pve::version::VersionClient;
use crate::http::HttpClient;

#[derive(Serialize)]
pub struct VersionInfo {
    pub version: String,
    pub release: String,
    pub repoid: String,
}

impl From<VersionClient<HttpClient>> for VersionInfo {
    fn from(client: VersionClient<HttpClient>) -> Self {
        VersionInfo {
            version: client.version().to_string(),
            release: client.release().to_string(),
            repoid: client.repoid().to_string(),
        }
    }
}
