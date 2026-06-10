#!/bin/bash
###########################################
# N8N Upgrade Script
# Version: 1.2.0
# Author: D-Solutions Team
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
KEEP_BACKUPS=${KEEP_BACKUPS:-5}      # Number of pre_upgrade backups to retain
MIN_DISK_GB=${MIN_DISK_GB:-3}        # Minimum free disk (GB) required before pull
HEALTH_TIMEOUT=${HEALTH_TIMEOUT:-60} # Seconds to wait for n8n to become healthy

N8N_DIR="/opt/n8n"
DATA_DIR="$N8N_DIR/data"
BACKUP_DIR="$N8N_DIR/backups"
COMPOSE_FILE="$N8N_DIR/docker-compose.yml"
IMAGE="n8nio/n8n:latest"

# ----------------------------------------------------------------------------
# Argument parsing
# ----------------------------------------------------------------------------
CLEANUP_FIRST=false
FORCE=false
SKIP_BACKUP=false

usage() {
    cat <<USAGE
N8N Upgrade Script

Usage: sudo ./upgrade_n8n.sh [options]

Options:
  --cleanup-first   Reclaim disk before upgrading (prune images, rotate backups,
                    vacuum journald, apt clean/autoremove)
  --force           Skip the pre-flight disk-space guard and upgrade anyway
  --skip-backup     Do not create a pre-upgrade database backup
  --help            Show this help

Environment overrides:
  KEEP_BACKUPS   (default ${KEEP_BACKUPS})   How many pre_upgrade_*.sqlite to keep
  MIN_DISK_GB    (default ${MIN_DISK_GB})    Minimum free GB required before pull
  HEALTH_TIMEOUT (default ${HEALTH_TIMEOUT})  Seconds to wait for health check

Example:
  KEEP_BACKUPS=10 MIN_DISK_GB=5 sudo ./upgrade_n8n.sh --cleanup-first
USAGE
}

for arg in "$@"; do
    case "$arg" in
        --cleanup-first) CLEANUP_FIRST=true ;;
        --force)         FORCE=true ;;
        --skip-backup)   SKIP_BACKUP=true ;;
        --help|-h)       usage; exit 0 ;;
        *) log_error "Tham số không hợp lệ: $arg"; usage; exit 1 ;;
    esac
done

# ----------------------------------------------------------------------------
# Disk helpers (measured on the filesystem holding Docker data)
# ----------------------------------------------------------------------------
DOCKER_ROOT=$(docker info --format '{{.DockerRootDir}}' 2>/dev/null || echo "/var/lib/docker")
[ -d "$DOCKER_ROOT" ] || DOCKER_ROOT="/"

# Free space in whole GB on the Docker filesystem.
get_disk_free_gb() {
    df -BG "$DOCKER_ROOT" 2>/dev/null | awk 'NR==2 {gsub("G","",$4); print $4+0}'
}

# Human-readable "used/total (percent)" string for the Docker filesystem.
disk_report() {
    local label="$1"
    df -BG "$DOCKER_ROOT" 2>/dev/null | awk -v l="$label" \
        'NR==2 {printf "%s: %s/%s (%s đã dùng)", l, $3, $2, $5}'
}

# ----------------------------------------------------------------------------
# Pre-flight checks
# ----------------------------------------------------------------------------
# Check root
if [ "$EUID" -ne 0 ]; then
    log_error "Vui lòng chạy script với quyền root (sudo)"
    exit 1
fi

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    log_error "Docker chưa được cài đặt"
    exit 1
fi

# Check Docker daemon is running
if ! docker info &> /dev/null; then
    log_error "Docker daemon không chạy. Khởi động bằng: systemctl start docker"
    exit 1
fi

# Check if N8N is installed (graceful first-run guidance)
if [ ! -f "$COMPOSE_FILE" ]; then
    log_error "N8N chưa được cài đặt (không tìm thấy $COMPOSE_FILE)"
    log_info "Vui lòng chạy install_n8n.sh trước khi nâng cấp."
    exit 1
fi

# Check if n8n container exists/running
if ! docker ps --format '{{.Names}}' | grep -q "^n8n$"; then
    log_error "N8N container không chạy. Vui lòng khởi động N8N trước"
    log_info "Chạy: cd $N8N_DIR && docker-compose up -d"
    exit 1
fi

echo "=========================================="
echo "   N8N Upgrade Script"
echo "   D-Solutions Technology Media Co., Ltd."
echo "=========================================="
echo ""

# ----------------------------------------------------------------------------
# Backup rotation: keep only the newest $KEEP_BACKUPS pre_upgrade backups
# ----------------------------------------------------------------------------
rotate_backups() {
    mkdir -p "$BACKUP_DIR"
    # Newest first; delete everything past the keep window.
    ls -t "$BACKUP_DIR"/pre_upgrade_*.sqlite 2>/dev/null \
        | tail -n +$((KEEP_BACKUPS + 1)) \
        | xargs -r rm -v
}

# ----------------------------------------------------------------------------
# Optional proactive cleanup (--cleanup-first)
# ----------------------------------------------------------------------------
if [ "$CLEANUP_FIRST" = true ]; then
    log_info "Dọn dẹp trước khi nâng cấp (--cleanup-first)..."
    log_info "$(disk_report 'Disk trước cleanup')"

    log_info "Xoá Docker images không sử dụng..."
    docker image prune -a -f || log_warn "Không thể prune images (bỏ qua)"

    log_info "Dọn backup cũ (giữ $KEEP_BACKUPS file mới nhất)..."
    rotate_backups

    if command -v journalctl &> /dev/null; then
        log_info "Thu gọn systemd journal (giữ 7 ngày)..."
        journalctl --vacuum-time=7d || log_warn "Không thể vacuum journal (bỏ qua)"
    fi

    if command -v apt-get &> /dev/null; then
        log_info "Dọn cache apt..."
        apt-get clean || true
        apt-get autoremove --purge -y || true
    fi

    log_info "$(disk_report 'Disk sau cleanup')"
    echo ""
fi

# ----------------------------------------------------------------------------
# Disk space report + pre-flight guard
# ----------------------------------------------------------------------------
FREE_BEFORE=$(get_disk_free_gb)
log_info "$(disk_report 'Disk trước upgrade')"

if [ "$FORCE" != true ]; then
    if [ "${FREE_BEFORE:-0}" -lt "$MIN_DISK_GB" ]; then
        log_error "Disk không đủ: cần ${MIN_DISK_GB}GB, còn ${FREE_BEFORE}GB"
        log_info "Gợi ý: chạy lại với --cleanup-first để tự động dọn dẹp"
        log_info "Hoặc bỏ qua kiểm tra (rủi ro) bằng --force"
        exit 1
    fi
fi

# ----------------------------------------------------------------------------
# Version + capture current image for rollback
# ----------------------------------------------------------------------------
log_info "Kiểm tra phiên bản hiện tại..."
CURRENT_VERSION=$(docker exec n8n n8n --version 2>/dev/null || echo "unknown")
log_info "Phiên bản hiện tại: $CURRENT_VERSION"

# Image ID currently backing the n8n container — used to roll back if the new
# image fails its health check. Survives `docker pull` because pull only moves
# the :latest tag; the old image stays resident by ID until pruned.
OLD_IMAGE_ID=$(docker inspect --format '{{.Image}}' n8n 2>/dev/null || echo "")
if [ -n "$OLD_IMAGE_ID" ]; then
    log_info "Image hiện tại (để rollback): ${OLD_IMAGE_ID:0:19}..."
fi

# ----------------------------------------------------------------------------
# Backup (with rotation)
# ----------------------------------------------------------------------------
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="$BACKUP_DIR/pre_upgrade_$TIMESTAMP.sqlite"

if [ "$SKIP_BACKUP" = true ]; then
    log_warn "Bỏ qua backup (--skip-backup). Rollback sẽ không khôi phục database."
    BACKUP_FILE=""
else
    log_info "Tạo backup trước khi nâng cấp..."
    mkdir -p "$BACKUP_DIR"

    # Method 1: sqlite3 inside container (online, consistent backup)
    if docker exec n8n sh -c "command -v sqlite3" &> /dev/null; then
        log_info "Sử dụng sqlite3 trong container để backup..."
        docker exec n8n sh -c "sqlite3 /home/node/.n8n/database.sqlite \".backup '/backup/pre_upgrade_$TIMESTAMP.sqlite'\""
    else
        # Method 2: stop + copy + start (ensures file integrity)
        log_warn "sqlite3 không có trong container, sử dụng backup trực tiếp..."
        log_info "Dừng N8N tạm thời để đảm bảo tính toàn vẹn database..."
        docker stop n8n
        docker cp n8n:/home/node/.n8n/database.sqlite "$BACKUP_FILE"
        log_info "Khởi động lại N8N..."
        docker start n8n
        sleep 5
    fi

    if [ -f "$BACKUP_FILE" ]; then
        BACKUP_SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
        log_info "✓ Backup thành công: $BACKUP_FILE ($BACKUP_SIZE)"
    else
        log_error "✗ Backup thất bại"
        exit 1
    fi

    # Rotate AFTER a successful new backup so we never delete the just-made one.
    log_info "Dọn backup cũ (giữ $KEEP_BACKUPS file mới nhất)..."
    rotate_backups
fi

# ----------------------------------------------------------------------------
# Pull latest image (explicit failure handling — do NOT leave a half state)
# ----------------------------------------------------------------------------
log_info "Tải phiên bản mới nhất..."
if ! docker pull "$IMAGE"; then
    log_error "Pull thất bại (có thể do hết dung lượng disk)."
    log_info "Container cũ vẫn đang chạy bình thường — hệ thống KHÔNG bị gián đoạn."
    log_info "Dọn các layer tải dở..."
    docker image prune -f || true
    log_info "Để thử lại: giải phóng disk (vd: --cleanup-first) rồi chạy lại script."
    exit 1
fi

# ----------------------------------------------------------------------------
# Rollback helper — restore old image (and DB) if the new container is unhealthy
# ----------------------------------------------------------------------------
rollback() {
    log_warn "Bắt đầu rollback về phiên bản trước..."
    cd "$N8N_DIR"

    if [ -n "$OLD_IMAGE_ID" ]; then
        log_info "Khôi phục image cũ..."
        docker tag "$OLD_IMAGE_ID" "$IMAGE" || log_warn "Không thể retag image cũ"
        docker-compose stop n8n || true

        # Restore the pre-upgrade database (the new version may have migrated it).
        if [ -n "$BACKUP_FILE" ] && [ -f "$BACKUP_FILE" ]; then
            log_info "Khôi phục database từ backup..."
            cp "$BACKUP_FILE" "$DATA_DIR/database.sqlite"
            chown 1000:1000 "$DATA_DIR/database.sqlite" 2>/dev/null || true
        else
            log_warn "Không có backup để khôi phục database (đã --skip-backup)."
        fi

        docker-compose up -d --force-recreate n8n || true
        log_info "✓ Đã rollback về image cũ. Kiểm tra: docker logs n8n"
    else
        log_error "Không xác định được image cũ để rollback tự động."
    fi
}

# ----------------------------------------------------------------------------
# Recreate container with the new image
# ----------------------------------------------------------------------------
log_info "Dừng container hiện tại..."
cd "$N8N_DIR"
docker-compose stop n8n

log_info "Nâng cấp N8N container..."
docker-compose up -d --force-recreate n8n

# ----------------------------------------------------------------------------
# Health check loop — n8n's port 5678 is NOT published to the host, so probe
# /healthz from INSIDE the container (wget ships in the n8n image).
# ----------------------------------------------------------------------------
log_info "Đang chờ N8N khởi động và healthy (tối đa ${HEALTH_TIMEOUT}s)..."
HEALTHY=false
ATTEMPTS=$((HEALTH_TIMEOUT / 2))
for ((i = 1; i <= ATTEMPTS; i++)); do
    if docker ps --format '{{.Names}}' | grep -q "^n8n$"; then
        if docker exec n8n wget --spider -q http://localhost:5678/healthz &> /dev/null; then
            HEALTHY=true
            break
        fi
    fi
    echo -n "."
    sleep 2
done
echo ""

if [ "$HEALTHY" != true ]; then
    log_error "✗ N8N không trở nên healthy trong ${HEALTH_TIMEOUT}s"
    log_error "Logs gần đây:"
    docker logs --tail 30 n8n 2>&1 || true
    rollback
    exit 1
fi

log_info "✓ N8N healthy"

# ----------------------------------------------------------------------------
# Verify version
# ----------------------------------------------------------------------------
NEW_VERSION=$(docker exec n8n n8n --version 2>/dev/null || echo "unknown")
if [ "$CURRENT_VERSION" != "$NEW_VERSION" ]; then
    log_info "✓ N8N đã được nâng cấp thành công"
else
    log_warn "Phiên bản không thay đổi (có thể đã ở phiên bản mới nhất)"
fi
log_info "Phiên bản mới: $NEW_VERSION"

# ----------------------------------------------------------------------------
# Post-upgrade cleanup — prune unused images, but only those at least 24h old so
# the image we just pulled is never removed.
# ----------------------------------------------------------------------------
log_info "Dọn Docker images cũ (chỉ image ≥ 24h)..."
docker image prune -a -f --filter "until=24h" || log_warn "Không thể prune images (bỏ qua)"

# ----------------------------------------------------------------------------
# Disk space report (before/after + reclaimed)
# ----------------------------------------------------------------------------
FREE_AFTER=$(get_disk_free_gb)
log_info "$(disk_report 'Disk sau upgrade')"
if [ -n "$FREE_AFTER" ] && [ -n "$FREE_BEFORE" ]; then
    FREED=$((FREE_AFTER - FREE_BEFORE))
    log_info "Thay đổi disk trống: ${FREE_BEFORE}GB → ${FREE_AFTER}GB (${FREED}GB)"
fi

# ----------------------------------------------------------------------------
# Summary
# ----------------------------------------------------------------------------
echo ""
echo "=========================================="
log_info "✅ Nâng cấp hoàn tất!"
echo "=========================================="
echo ""
echo "📊 Thông tin phiên bản:"
echo "   - Phiên bản cũ: $CURRENT_VERSION"
echo "   - Phiên bản mới: $NEW_VERSION"
echo ""
if [ -n "$BACKUP_FILE" ]; then
    echo "💾 Backup file:"
    echo "   - $BACKUP_FILE"
    [ -f "$BACKUP_FILE" ] && echo "   - Kích thước: $(du -h "$BACKUP_FILE" | cut -f1)"
    echo "   - Giữ lại tối đa: $KEEP_BACKUPS backup mới nhất"
    echo ""
fi
echo "🔗 Truy cập N8N:"
echo "   - Kiểm tra docker-compose.yml để xem port và domain"
echo ""
echo "📝 Lưu ý:"
echo "   - Backup được lưu tại: $BACKUP_DIR"
echo "   - Kiểm tra workflows hoạt động bình thường"
echo "   - Dọn disk thủ công bất kỳ lúc nào: sudo ./upgrade_n8n.sh --cleanup-first"
echo ""
echo "Made with ❤️  by D-Solutions Team"
echo "=========================================="
