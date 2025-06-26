pub use pve::client::HttpClient;
use reqwest::blocking::Client as ReqwestClient;
use reqwest::header::{HeaderMap, AUTHORIZATION};
use reqwest::header::{HeaderName, HeaderValue};
use reqwest::Method;
use serde::de::DeserializeOwned;
use serde::Serialize;
use url::Url;

#[derive(Debug, thiserror::Error)]
pub enum Error {
    #[error("{0}")]
    UnderlyingError(#[from] reqwest::Error),

    #[error("JSON parse error: {0}")]
    JsonError(#[from] serde_json::Error),

    #[error("request failed with status {0}: {1:?}")]
    APIError(u16, Option<serde_json::Value>),
}

#[derive(Debug, Clone)]
pub struct Client {
    inner: ReqwestClient,
    base_url: Url,
}

#[derive(Debug, serde::Deserialize)]
pub struct Response<T> {
    pub data: T,
}

#[derive(Debug, Clone, Default, serde::Deserialize)]
pub struct ErrorResponse {
    #[serde(default)]
    pub errors: Option<serde_json::Value>,
}

impl Client {
    fn request<Q, B, R>(
        &self,
        method: Method,
        path: &str,
        query: Option<Q>,
        body: Option<B>,
    ) -> Result<R, Error>
    where
        Q: Serialize,
        B: Serialize,
        R: DeserializeOwned,
    {
        // Remove any leading slashes from path
        let path = path.trim_start_matches('/');
        let full_path = if path.starts_with("api2/json") {
            format!("/{}", path)
        } else {
            path.to_string()
        };
        let req = self
            .inner
            .request(method, self.base_url.join(&full_path).unwrap());

        let req = if let Some(query) = query {
            req.query(&query)
        } else {
            req
        };

        let req = if let Some(body) = body {
            req.json(&body)
        } else {
            req
        };

        let resp = req.send()?;
        let status = resp.status();

        // Clone response text for debugging
        let resp_text = resp.text()?;
        println!("Raw API response: {}", resp_text);

        if !status.is_success() {
            let error_resp = serde_json::from_str::<ErrorResponse>(&resp_text)?;
            return Err(Error::APIError(
                status.as_u16(),
                error_resp.errors,
            ));
        }

        let response = serde_json::from_str::<Response<R>>(&resp_text)?;
        Ok(response.data)
    }
}

impl HttpClient for Client {
    type Error = Error;

    fn get<Q, R>(&self, path: &str, query: &Q) -> Result<R, Self::Error>
    where
        Q: Serialize,
        R: DeserializeOwned,
    {
        self.request::<_, (), _>(Method::GET, path, Some(query), None)
    }

    fn post<B, R>(&self, path: &str, body: &B) -> Result<R, Self::Error>
    where
        B: Serialize,
        R: DeserializeOwned,
    {
        self.request::<(), _, _>(Method::POST, path, None, Some(body))
    }

    fn put<B, R>(&self, path: &str, body: &B) -> Result<R, Self::Error>
    where
        B: Serialize,
        R: DeserializeOwned,
    {
        self.request::<(), _, _>(Method::PUT, path, None, Some(body))
    }

    fn delete<B, R>(&self, path: &str, query: &B) -> Result<R, Self::Error>
    where
        B: Serialize,
        R: DeserializeOwned,
    {
        self.request::<_, (), _>(Method::DELETE, path, Some(query), None)
    }
}

#[derive(Debug, Clone)]
pub struct TokenAuthMethod {
    username: String,
    token_name: String,
    secret: String,
}

impl TokenAuthMethod {
    pub fn header(&self) -> (HeaderName, HeaderValue) {
        let value = format!(
            "PVEAPIToken={}!{}={}",
            self.username, self.token_name, self.secret,
        );

        (AUTHORIZATION, value.parse().unwrap())
    }
}

#[derive(Debug, Clone, Default)]
pub enum AuthMethod {
    /// No authentication
    #[default]
    None,

    /// Token-based authentication
    Token(TokenAuthMethod),
}

impl AuthMethod {
    pub fn token(username: String, token_name: String, secret: String) -> Self {
        Self::Token(TokenAuthMethod {
            username,
            token_name,
            secret,
        })
    }
}

#[derive(Debug, Clone, Default)]
pub struct ClientBuilder {
    base_url: Option<Url>,
    tls_insecure: bool,
    auth_method: AuthMethod,
}

#[derive(Debug, thiserror::Error)]
pub enum ClientBuilderError {
    #[error("invalid parameters")]
    InvalidParameters,

    #[error("{0}")]
    UnderlyingError(reqwest::Error),
}

impl From<reqwest::Error> for ClientBuilderError {
    fn from(error: reqwest::Error) -> Self {
        ClientBuilderError::UnderlyingError(error)
    }
}

impl ClientBuilder {
    pub fn with_base_url(mut self, url: Url) -> Self {
        self.base_url = Some(url);
        self
    }

    pub fn with_insecure_tls(mut self, enable: bool) -> Self {
        self.tls_insecure = enable;
        self
    }

    pub fn with_auth_method(mut self, auth_method: AuthMethod) -> Self {
        self.auth_method = auth_method;
        self
    }
  
    pub fn build(self) -> Result<Client, ClientBuilderError> {
        let builder = ReqwestClient::builder();

        let builder = if self.tls_insecure {
            builder.danger_accept_invalid_certs(true)
        } else {
            builder
        };

        let mut default_headers = HeaderMap::new();

        match self.auth_method {
            AuthMethod::None => {}
            AuthMethod::Token(t) => {
                let (header_name, header_value) = t.header();

                default_headers.insert(header_name, header_value);
            }
        };

        let builder = if !default_headers.is_empty() {
            builder.default_headers(default_headers)
        } else {
            builder
        };

        let inner = builder.build()?;
        let base_url = self.base_url.ok_or(ClientBuilderError::InvalidParameters)?;

        Ok(Client { inner, base_url })
    }
}
