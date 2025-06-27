# OpenVirt - Self-Service VM Platform for Proxmox

[![Rust](https://img.shields.io/badge/Rust-1.75+-blue.svg)](https://www.rust-lang.org/)
[![Actix](https://img.shields.io/badge/Actix-4.0-green.svg)](https://actix.rs/)
[![License](https://img.shields.io/badge/License-MIT-orange.svg)](LICENSE)

OpenVirt is an open-source self-service virtual machine management platform built on top of Proxmox VE. It provides a simple REST API interface for users to manage their virtual machines without needing direct access to the Proxmox web interface.

## ✨ Key Features

- 🚀 Simple REST API for VM management
- 🔒 JWT-based authentication
- 🔄 Async architecture for high performance
- 🔧 Easy integration with existing Proxmox clusters
- 📦 Containerized deployment options

## 🚀 Quick Start

### Prerequisites
- Rust 1.75+
- Proxmox VE cluster
- API token with appropriate permissions

### Installation

1. Clone the repository:
```bash
git clone https://github.com/utilsrc/openvirt.git
cd openvirt
```

2. Configure environment variables:
```bash
cp .env_example .env
# Edit .env with your Proxmox credentials
```

3. Build and run:
```bash
cargo run
```

### Configuration

Required environment variables (set in `.env`):
```ini
PROXMOX_URL=https://your-proxmox-server:8006
PROXMOX_REALM=pam
PROXMOX_USERNAME=root
PROXMOX_TOKEN_NAME=test
PROXMOX_TOKEN_SECRET=your-token-secret
JWT_SECRET=your-jwt-secret
```

## API Documentation

The API will be available at `http://localhost:8081/api/`

Basic endpoints:
- `GET /api/version` - Get Proxmox version info
- `POST /api/login` - Authenticate and get JWT token
- `GET /api/health` - Health check endpoint

## 🤝 Contributing

Contributions are welcome! Please open an issue or submit a pull request.

## 📜 License

MIT © [Your Name]
