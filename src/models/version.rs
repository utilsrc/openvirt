use serde::{Serialize, Deserialize};

#[derive(Debug, Serialize, Deserialize)]
pub struct Version {
    pub version: String,
    pub release: String,
    pub repoid: String,
}
