#!/bin/bash
###########################################
# N8N Cleanup Script
# Version: 1.0.0
# Author: D-Solutions Team
#
# Reclaims disk independently of upgrades: prunes unused Docker images,
# rotates pre_upgrade/pre_migration backups, removes stale /tmp exports,
# vacuums the systemd journal, and cleans the apt cache.
#
# Safe to run any time; intended for weekly cron via --install-cron.
###########################################
set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# ----------------------------------------------------------------------------
# Configuration (overridable via environment variables)
# ----------------------------------------------------------------------------
KEEP_BACKUPS=${KEEP_BACKUPS:-5}      # Backups to retain per type (upgrade/migration)
JOURNAL_DAYS=${JOURNAL_DAYS:-7}      # Keep this many days of systemd journal
EXPORT_AGE_DAYS=${EXPORT_AGE_DAYS:-7} # Delete /tmp export archives older than this

N8N_DIR="/opt/n8n"
BACKUP_DIR="$N8N_DIR/backups"
CRON_PATH="/etc/cron.weekly/n8n-cleanup"

# ----------------------------------------------------------------------------
# Argument parsing
# ----------------------------------------------------------------------------
DRY_RUN=false
INSTALL_CRON=false

usage() {
    cat <<USAGE
N8N Cleanup Script

Usage: sudo ./cleanup_n8n.sh [options]

Options:
  --dry-run        Show what would be removed without deleting anything
  --install-cron   Install this script as ${CRON_PATH} (weekly)
  --help           Show this help

Environment overrides:
  KEEP_BACKUPS    (default ${KEEP_BACKUPS})   Backups kept per type (upgrade/migration)
  JOURNAL_DAYS    (default ${JOURNAL_DAYS})    Days of systemd journal to keep
  EXPORT_AGE_DAYS (default ${EXPORT_AGE_DAYS})  Age (days) above which /tmp exports are deleted

Example:
  KEEP_BACKUPS=10 sudo ./cleanup_n8n.sh
  sudo ./cleanup_n8n.sh --install-cron
USAGE
}

for arg in "$@"; do
    case "$arg" in
        --dry-run)      DRY_RUN=true ;;
        --install-cron) INSTALL_CRON=true ;;
        --help|-h)      usage; exit 0 ;;
        *) log_error "Tham số không hợp lệ: $arg"; usage; exit 1 ;;
    esac
done

# ----------------------------------------------------------------------------
# Root check
# ----------------------------------------------------------------------------
if [ "$EUID" -ne 0 ]; then
    log_error "Vui lòng chạy script với quyền root (sudo)"
    exit 1
fi

# ----------------------------------------------------------------------------
# --install-cron: copy self to /etc/cron.weekly and exit
# ----------------------------------------------------------------------------
if [ "$INSTALL_CRON" = true ]; then
    SCRIPT_PATH="$(readlink -f "$0")"
    log_info "Cài đặt cron weekly: $CRON_PATH"
    cp "$SCRIPT_PATH" "$CRON_PATH"
    chmod +x "$CRON_PATH"
    log_info "✓ Đã cài. Chạy tự động mỗi tuần (run-parts /etc/cron.weekly)."
    log_info "Gỡ bỏ: rm $CRON_PATH"
    exit 0
fi

# ----------------------------------------------------------------------------
# Disk helpers (measured on the filesystem holding Docker data)
# ----------------------------------------------------------------------------
DOCKER_ROOT="/var/lib/docker"
if command -v docker &> /dev/null && docker info &> /dev/null; then
    DOCKER_ROOT=$(docker info --format '{{.DockerRootDir}}' 2>/dev/null || echo "/var/lib/docker")
fi
[ -d "$DOCKER_ROOT" ] || DOCKER_ROOT="/"

get_disk_free_gb() {
    df -BG "$DOCKER_ROOT" 2>/dev/null | awk 'NR==2 {gsub("G","",$4); print $4+0}'
}

disk_report() {
    local label="$1"
    df -BG "$DOCKER_ROOT" 2>/dev/null | awk -v l="$label" \
        'NR==2 {printf "%s: %s/%s (%s đã dùng)", l, $3, $2, $5}'
}

# Rotate one backup type: keep newest $KEEP_BACKUPS, remove the rest.
# Uses find (sorted by mtime) instead of a shell glob so it behaves identically
# regardless of the invoking shell — a variable-expanded glob is NOT filename-
# expanded under zsh/dash, which would silently skip rotation. In dry-run, only
# lists what would be removed.
rotate_type() {
    local dir="$1"
    local prefix="$2"
    local label="$3"
    local victims
    # Newest first by modification time; drop the keep window, keep the rest as victims.
    victims=$(find "$dir" -maxdepth 1 -type f -name "${prefix}_*.sqlite" -printf '%T@\t%p\n' 2>/dev/null \
        | sort -rn | tail -n +$((KEEP_BACKUPS + 1)) | cut -f2-)
    if [ -z "$victims" ]; then
        log_info "$label: không có file cũ để xoá (giữ tối đa $KEEP_BACKUPS)"
        return
    fi
    if [ "$DRY_RUN" = true ]; then
        log_info "$label: sẽ xoá $(echo "$victims" | wc -l | tr -d ' ') file (dry-run):"
        echo "$victims" | sed 's/^/    /'
    else
        log_info "$label: xoá file cũ (giữ $KEEP_BACKUPS mới nhất)..."
        echo "$victims" | xargs -r rm -v | sed 's/^/    /'
    fi
}

echo "=========================================="
echo "   N8N Cleanup Script"
echo "   D-Solutions Technology Media Co., Ltd."
echo "=========================================="
[ "$DRY_RUN" = true ] && log_warn "Chế độ DRY-RUN: không xoá gì cả"
echo ""

FREE_BEFORE=$(get_disk_free_gb)
log_info "$(disk_report 'Disk trước cleanup')"
echo ""

# ----------------------------------------------------------------------------
# 1. Prune unused Docker images
# ----------------------------------------------------------------------------
if command -v docker &> /dev/null && docker info &> /dev/null; then
    if [ "$DRY_RUN" = true ]; then
        log_info "Docker images có thể thu hồi (dry-run):"
        docker system df 2>/dev/null | sed 's/^/    /' || true
    else
        log_info "Xoá Docker images không sử dụng..."
        docker image prune -a -f || log_warn "Không thể prune images (bỏ qua)"
    fi
else
    log_warn "Docker không khả dụng — bỏ qua bước prune images"
fi
echo ""

# ----------------------------------------------------------------------------
# 2. Rotate backups (upgrade + migration)
# ----------------------------------------------------------------------------
if [ -d "$BACKUP_DIR" ]; then
    rotate_type "$BACKUP_DIR" "pre_upgrade"   "Backup pre_upgrade"
    rotate_type "$BACKUP_DIR" "pre_migration" "Backup pre_migration"
else
    log_warn "Không tìm thấy $BACKUP_DIR — bỏ qua dọn backup"
fi
echo ""

# ----------------------------------------------------------------------------
# 3. Remove stale /tmp export archives
# ----------------------------------------------------------------------------
STALE_EXPORTS=$(find /tmp -maxdepth 1 -name 'n8n-export-*.tar.gz*' -mtime +"$EXPORT_AGE_DAYS" 2>/dev/null)
if [ -n "$STALE_EXPORTS" ]; then
    if [ "$DRY_RUN" = true ]; then
        log_info "File export /tmp cũ (>${EXPORT_AGE_DAYS} ngày) sẽ xoá (dry-run):"
        echo "$STALE_EXPORTS" | sed 's/^/    /'
    else
        log_info "Xoá file export /tmp cũ (>${EXPORT_AGE_DAYS} ngày)..."
        echo "$STALE_EXPORTS" | xargs -r rm -v | sed 's/^/    /'
    fi
else
    log_info "Không có file export /tmp cũ để xoá"
fi
echo ""

# ----------------------------------------------------------------------------
# 4. Vacuum systemd journal
# ----------------------------------------------------------------------------
if command -v journalctl &> /dev/null; then
    if [ "$DRY_RUN" = true ]; then
        log_info "Sẽ thu gọn journal về ${JOURNAL_DAYS} ngày (dry-run)"
    else
        log_info "Thu gọn systemd journal (giữ ${JOURNAL_DAYS} ngày)..."
        journalctl --vacuum-time="${JOURNAL_DAYS}d" || log_warn "Không thể vacuum journal (bỏ qua)"
    fi
fi
echo ""

# ----------------------------------------------------------------------------
# 5. Clean apt cache
# ----------------------------------------------------------------------------
if command -v apt-get &> /dev/null; then
    if [ "$DRY_RUN" = true ]; then
        log_info "Sẽ chạy apt clean + autoremove --purge (dry-run)"
    else
        log_info "Dọn cache apt..."
        apt-get clean || true
        apt-get autoremove --purge -y || true
    fi
fi
echo ""

# ----------------------------------------------------------------------------
# Disk report after + reclaimed
# ----------------------------------------------------------------------------
FREE_AFTER=$(get_disk_free_gb)
log_info "$(disk_report 'Disk sau cleanup')"
if [ "$DRY_RUN" != true ] && [ -n "$FREE_AFTER" ] && [ -n "$FREE_BEFORE" ]; then
    FREED=$((FREE_AFTER - FREE_BEFORE))
    log_info "Đã giải phóng: ${FREED}GB (${FREE_BEFORE}GB → ${FREE_AFTER}GB trống)"
fi

echo ""
echo "=========================================="
log_info "✅ Cleanup hoàn tất!"
echo "=========================================="
echo "Made with ❤️  by D-Solutions Team"
