# 🚀 N8N Installation Scripts

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![N8N](https://img.shields.io/badge/N8N-Latest-orange.svg)](https://n8n.io)
[![Docker](https://img.shields.io/badge/Docker-Required-blue.svg)](https://www.docker.com)

One-click N8N installation scripts for Ubuntu with Docker, Caddy reverse proxy, automatic HTTPS, and comprehensive security optimizations.

## ✨ Features

### 🔧 Installation Script (`install_n8n.sh`)
- ✅ **One-command installation** - Complete setup in minutes
- ✅ **Automatic DNS validation** - Ensures domain is ready before setup
- ✅ **Docker & Docker Compose** - Latest versions auto-installed
- ✅ **Caddy reverse proxy** - Auto HTTPS with Let's Encrypt
- ✅ **Security optimizations** - Private network, no direct port exposure
- ✅ **Performance tuning** - Optimized database pool and task runners
- ✅ **Automatic backups** - Daily SQLite backups with retention policy

### 🔄 Upgrade Script (`upgrade_n8n.sh`)
- ✅ **One-command upgrade** - Latest N8N version with one line
- ✅ **Automatic backup** - Creates backup before any changes
- ✅ **Version comparison** - Shows current vs new version
- ✅ **Rollback support** - Easy rollback if issues occur
- ✅ **Zero-downtime** - Graceful container restart
- ✅ **Comprehensive logging** - Detailed logs for troubleshooting

### 🚀 Migration Script (`migrate_n8n.sh`)
- ✅ **VPS-to-VPS migration** - Move N8N between servers
- ✅ **Auto-detection** - Identifies source/destination automatically
- ✅ **Export with checksum** - SHA256 verification for data integrity
- ✅ **Automatic backup** - Backup before import
- ✅ **DNS validation** - Ensures new domain is ready
- ✅ **Zero-configuration** - Smart defaults for easy migration

## 🚀 Quick Start

### Installation

```bash
curl -sSL https://raw.githubusercontent.com/D-SOLUTIONS-TECHNOLOGY-MEDIA-CO-LTD/n8n-installation-script/main/install_n8n.sh > install_n8n.sh && chmod +x install_n8n.sh && sudo ./install_n8n.sh
```

**What you'll need:**
- Fresh Ubuntu 20.04+ VPS
- Domain name pointed to your VPS IP
- Root or sudo access

### Upgrade

```bash
curl -sSL https://raw.githubusercontent.com/D-SOLUTIONS-TECHNOLOGY-MEDIA-CO-LTD/n8n-installation-script/main/upgrade_n8n.sh > upgrade_n8n.sh && chmod +x upgrade_n8n.sh && sudo ./upgrade_n8n.sh
```

### Migration

```bash
curl -sSL https://raw.githubusercontent.com/D-SOLUTIONS-TECHNOLOGY-MEDIA-CO-LTD/n8n-installation-script/main/migrate_n8n.sh > migrate_n8n.sh && chmod +x migrate_n8n.sh && sudo ./migrate_n8n.sh
```

See [MIGRATION_GUIDE.md](MIGRATION_GUIDE.md) for detailed instructions.

## 📋 Requirements

- Ubuntu 20.04 LTS or newer
- Domain name with DNS A record pointing to VPS
- Minimum 1GB RAM (2GB+ recommended)
- 20GB+ disk space
- Root or sudo access

## 🔒 Security Features

- Private Docker network (no exposed ports)
- Caddy reverse proxy with automatic HTTPS
- SQLite database (no external DB needed)
- Daily automatic backups
- Secure webhook endpoints
- Rate limiting and DDoS protection via Caddy

## 📁 Project Structure

```
n8n-installation-script/
├── install_n8n.sh          # Main installation script
├── upgrade_n8n.sh          # Upgrade script
├── migrate_n8n.sh          # Migration script
├── README.md               # This file
├── MIGRATION_GUIDE.md      # Detailed migration guide
├── CHANGELOG.md            # Version history
├── CONTRIBUTING.md         # Contribution guidelines
├── LICENSE                 # MIT License
└── examples/
    ├── docker-compose.yml  # Example Docker Compose file
    └── Caddyfile           # Example Caddy configuration
```

## 🛠️ Manual Installation

If you prefer to review the script before running:

```bash
# Download script
wget https://raw.githubusercontent.com/D-SOLUTIONS-TECHNOLOGY-MEDIA-CO-LTD/n8n-installation-script/main/install_n8n.sh

# Review script
cat install_n8n.sh

# Make executable
chmod +x install_n8n.sh

# Run with sudo
sudo ./install_n8n.sh
```

## 📖 Detailed Documentation

### Installation Process

The installation script performs these steps:

1. **System Check** - Validates Ubuntu version and architecture
2. **DNS Validation** - Ensures domain points to server IP
3. **Docker Installation** - Installs Docker and Docker Compose
4. **Network Setup** - Creates isolated Docker network
5. **N8N Deployment** - Deploys N8N with optimized settings
6. **Caddy Setup** - Configures reverse proxy with auto HTTPS
7. **Backup Configuration** - Sets up daily automated backups
8. **Health Check** - Verifies all services are running

### Configuration Files

After installation, find configuration at:

```
/opt/n8n/
├── docker-compose.yml      # N8N container config
├── .env                    # Environment variables
├── data/                   # N8N data directory
│   └── database.sqlite     # SQLite database
├── caddy/
│   └── Caddyfile          # Caddy configuration
└── backups/               # Automatic backups
```

### Backup & Restore

**Manual Backup:**
```bash
sudo docker exec n8n n8n export:workflow --backup --output=/backup/
sudo cp /opt/n8n/data/database.sqlite /opt/n8n/backups/manual-backup-$(date +%Y%m%d).sqlite
```

**Restore from Backup:**
```bash
sudo docker-compose -f /opt/n8n/docker-compose.yml down
sudo cp /opt/n8n/backups/backup-YYYYMMDD.sqlite /opt/n8n/data/database.sqlite
sudo docker-compose -f /opt/n8n/docker-compose.yml up -d
```

## 🐛 Troubleshooting

### DNS Issues

```bash
# Check if domain resolves to your IP
dig +short your-domain.com

# Verify A record
nslookup your-domain.com
```

### Container Issues

```bash
# Check container status
sudo docker ps -a

# View N8N logs
sudo docker logs n8n

# View Caddy logs
sudo docker logs caddy

# Restart services
sudo docker-compose -f /opt/n8n/docker-compose.yml restart
```

### Permission Issues

```bash
# Fix data directory permissions
sudo chown -R 1000:1000 /opt/n8n/data

# Restart N8N
sudo docker-compose -f /opt/n8n/docker-compose.yml restart n8n
```

### HTTPS Not Working

```bash
# Check Caddy logs
sudo docker logs caddy

# Verify port 80 and 443 are open
sudo netstat -tulpn | grep -E ':80|:443'

# Test HTTPS manually
curl -I https://your-domain.com
```

## 🔄 Upgrade Process

The upgrade script:

1. Creates automatic backup
2. Pulls latest N8N image
3. Gracefully restarts container
4. Verifies new version
5. Provides rollback instructions if needed

```bash
# Check current version
sudo docker exec n8n n8n --version

# Upgrade to latest
sudo ./upgrade_n8n.sh

# Rollback if needed (shown in script output)
```

## 🚚 Migration Guide

See [MIGRATION_GUIDE.md](MIGRATION_GUIDE.md) for complete migration documentation.

**Quick Migration:**

```bash
# On source server - Export
sudo ./migrate_n8n.sh

# Transfer export file to new server
scp n8n-export-*.tar.gz user@new-server:/tmp/

# On destination server - Import
sudo ./migrate_n8n.sh
```

## 🤝 Contributing

Contributions are welcome! Please read [CONTRIBUTING.md](CONTRIBUTING.md) for details.

## 📝 Changelog

See [CHANGELOG.md](CHANGELOG.md) for version history.

## 📄 License

This project is licensed under the MIT License - see [LICENSE](LICENSE) file.

## 🙏 Credits

- Original script inspiration: [Bình MeCode](https://github.com/dangngocbinh/mecode-snippets)
- Maintained by: [D-Solutions Team](https://d-solutions.vn)
- N8N: [n8n.io](https://n8n.io)

## 📞 Support

- 🌐 Website: [d-solutions.vn](https://d-solutions.vn)
- 📧 Email: support@d-solutions.vn
- 💬 Issues: [GitHub Issues](https://github.com/D-SOLUTIONS-TECHNOLOGY-MEDIA-CO-LTD/n8n-installation-script/issues)

## ⭐ Show Your Support

If this project helped you, please give it a ⭐️!

---

**Made with ❤️ by D-Solutions Team**
