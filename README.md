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
- ✅ **Disk-space guard** - Pre-flight check aborts before a doomed pull
- ✅ **Automatic backup + rotation** - Backs up, keeps newest N, deletes old
- ✅ **Image cleanup** - Prunes orphaned images from prior upgrades (≥24h)
- ✅ **Version comparison** - Shows current vs new version
- ✅ **Auto-rollback** - Restores previous image + database if health check fails
- ✅ **Health verification** - Waits for n8n `/healthz` before declaring success
- ✅ **Disk report** - Shows space used/reclaimed before and after

### 🚀 Migration Script (`migrate_n8n.sh`)
- ✅ **VPS-to-VPS migration** - Move N8N between servers
- ✅ **Auto-detection** - Identifies source/destination automatically
- ✅ **Export with checksum** - SHA256 verification for data integrity
- ✅ **Automatic backup** - Backup before import
- ✅ **DNS validation** - Ensures new domain is ready
- ✅ **Zero-configuration** - Smart defaults for easy migration

### 🧹 Cleanup Script (`cleanup_n8n.sh`)
- ✅ **Standalone disk reclaim** - Run any time, independent of upgrades
- ✅ **Prunes unused Docker images** - Removes orphaned images from past upgrades
- ✅ **Rotates backups** - Keeps newest N of both `pre_upgrade` and `pre_migration`
- ✅ **Clears stale exports** - Removes old `/tmp/n8n-export-*` archives
- ✅ **Journal + apt cleanup** - Vacuums systemd journal, cleans apt cache
- ✅ **Weekly cron** - One-flag install via `--install-cron`
- ✅ **Dry-run mode** - Preview deletions with `--dry-run`

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

**Options & overrides:**

```bash
sudo ./upgrade_n8n.sh --cleanup-first   # reclaim disk before upgrading
sudo ./upgrade_n8n.sh --force           # skip the disk-space guard
sudo ./upgrade_n8n.sh --skip-backup     # upgrade without a pre-upgrade backup
sudo ./upgrade_n8n.sh --help            # full usage

# Tune via environment variables:
KEEP_BACKUPS=10 MIN_DISK_GB=5 HEALTH_TIMEOUT=90 sudo ./upgrade_n8n.sh
```

| Variable | Default | Purpose |
|----------|---------|---------|
| `KEEP_BACKUPS` | `5` | Number of `pre_upgrade_*.sqlite` backups to retain |
| `MIN_DISK_GB` | `3` | Minimum free disk (GB) required before pulling |
| `HEALTH_TIMEOUT` | `60` | Seconds to wait for n8n to become healthy |

### Migration

```bash
curl -sSL https://raw.githubusercontent.com/D-SOLUTIONS-TECHNOLOGY-MEDIA-CO-LTD/n8n-installation-script/main/migrate_n8n.sh > migrate_n8n.sh && chmod +x migrate_n8n.sh && sudo ./migrate_n8n.sh
```

See [MIGRATION_GUIDE.md](MIGRATION_GUIDE.md) for detailed instructions.

### Cleanup

Reclaim disk independently of upgrades (useful when a VPS is filling up):

```bash
curl -sSL https://raw.githubusercontent.com/D-SOLUTIONS-TECHNOLOGY-MEDIA-CO-LTD/n8n-installation-script/main/cleanup_n8n.sh > cleanup_n8n.sh && chmod +x cleanup_n8n.sh && sudo ./cleanup_n8n.sh
```

```bash
sudo ./cleanup_n8n.sh --dry-run        # preview what would be removed
sudo ./cleanup_n8n.sh --install-cron   # install as weekly cron (/etc/cron.weekly/n8n-cleanup)
sudo ./cleanup_n8n.sh --help           # full usage

# Tune via environment variables:
KEEP_BACKUPS=10 JOURNAL_DAYS=14 sudo ./cleanup_n8n.sh
```

It prunes unused Docker images, rotates `pre_upgrade`/`pre_migration` backups
(keeps newest `KEEP_BACKUPS`), removes stale `/tmp/n8n-export-*` archives,
vacuums the systemd journal, and cleans the apt cache.

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
├── cleanup_n8n.sh          # Disk cleanup script
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

1. Runs pre-flight checks (root, Docker daemon, n8n installed & running)
2. Optionally reclaims disk first (`--cleanup-first`)
3. Guards against low disk space before pulling
4. Creates a database backup and rotates old ones (keeps newest `KEEP_BACKUPS`)
5. Pulls the latest N8N image (fails cleanly without leaving a half state)
6. Recreates the container with the new image
7. Waits for `/healthz` to pass; **auto-rolls back image + database if it fails**
8. Prunes orphaned images (≥24h old) and reports disk reclaimed

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
