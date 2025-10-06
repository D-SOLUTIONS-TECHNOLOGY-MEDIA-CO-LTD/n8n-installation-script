# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2025-10-06

### Added
- Initial release of N8N installation scripts
- `install_n8n.sh` - Complete installation script with:
  - Automatic DNS validation
  - Docker and Docker Compose installation
  - N8N deployment with optimized settings
  - Caddy reverse proxy with automatic HTTPS
  - Daily backup configuration
- `upgrade_n8n.sh` - Upgrade script with:
  - Automatic pre-upgrade backup
  - Version comparison
  - Rollback instructions
- `migrate_n8n.sh` - Migration script with:
  - VPS-to-VPS migration support
  - Export/Import with checksum verification
  - Automatic backup before import
- Complete documentation:
  - README.md with quick start guide
  - MIGRATION_GUIDE.md with detailed instructions
  - CONTRIBUTING.md with contribution guidelines
- Example configurations:
  - docker-compose.yml
  - Caddyfile

### Security
- Private Docker network configuration
- No direct port exposure for N8N
- Automatic HTTPS via Let's Encrypt
- Security headers in Caddy configuration

### Performance
- Optimized N8N environment variables
- SQLite database with auto-vacuum
- Efficient Docker Compose configuration

---

**Legend:**
- `Added` for new features
- `Changed` for changes in existing functionality
- `Deprecated` for soon-to-be removed features
- `Removed` for now removed features
- `Fixed` for any bug fixes
- `Security` for vulnerability fixes
