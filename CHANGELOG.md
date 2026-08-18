# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.2.1] - 2026-08-18

### Changed
- `install_n8n.sh` and `upgrade_n8n.sh` now use Docker Compose v2 (`docker
  compose`) instead of the legacy v1 `docker-compose` (Python 1.29.2), which
  crashes with `KeyError: 'ContainerConfig'` on recent Docker Engine when
  recreating containers. Both scripts prefer the `docker compose` plugin and
  resolve a `COMPOSE_CMD` (install falls back to fetching the v2 standalone
  binary; upgrade aborts with guidance if only v1 is present).

### Fixed
- Daily backup cron (`/etc/cron.daily/n8n-backup`) created by `install_n8n.sh`
  called `docker exec n8n sqlite3 ...`, but the `n8nio/n8n` image ships no
  `sqlite3` CLI — so the backup failed silently from first install and produced
  no database backups. The cron now runs `sqlite3` on the host (installed as a
  dependency) against the mounted DB file (`/opt/n8n/data/database.sqlite`) via
  the `.backup` online-backup API (consistent snapshot even while n8n writes),
  and fails loudly with a non-zero exit + stderr message instead of silently
  when `sqlite3` or the DB is missing or the backup comes out empty.

### Removed
- Third-party attribution links/comments from `install_n8n.sh` and `README.md`.

## [1.2.0] - 2026-06-10

### Added
- `cleanup_n8n.sh` — standalone disk-reclaim script, runnable any time:
  - Prunes unused Docker images
  - Rotates both `pre_upgrade_*` and `pre_migration_*` backups (keeps newest
    `KEEP_BACKUPS`), using `find` so rotation is shell-agnostic
  - Removes stale `/tmp/n8n-export-*` archives (`EXPORT_AGE_DAYS`)
  - Vacuums the systemd journal (`JOURNAL_DAYS`) and cleans the apt cache
  - `--dry-run` preview, `--install-cron` (weekly), `--help`
  - Covers the `migrate_n8n.sh` backup accumulation without modifying that script
- `upgrade_n8n.sh` disk-safety and self-healing overhaul:
  - Pre-flight disk-space guard (`MIN_DISK_GB`, default 3GB) — aborts before
    pulling when free space is too low, preventing partial-layer corruption
  - Automatic backup rotation — keeps newest `KEEP_BACKUPS` (default 5)
    `pre_upgrade_*.sqlite` files, deletes the rest
  - Post-upgrade image prune (`docker image prune -a -f --filter until=24h`) —
    reclaims orphaned images from prior upgrades without touching the just-pulled one
  - Explicit `docker pull` failure handling — old container keeps running, partial
    layers cleaned, clear retry guidance (no half-upgraded state)
  - In-container `/healthz` health-check loop (`HEALTH_TIMEOUT`, default 60s) —
    probes from inside the container since port 5678 is not published to the host
  - Full auto-rollback on health-check failure — re-tags the previous image and
    restores the pre-upgrade database backup
  - Disk usage report before/after with reclaimed space
  - New flags: `--cleanup-first`, `--force`, `--skip-backup`, `--help`
  - Env overrides: `KEEP_BACKUPS`, `MIN_DISK_GB`, `HEALTH_TIMEOUT`

### Fixed
- VPS running out of disk after repeated upgrades caused by accumulated orphan
  Docker images and never-rotated backups

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
