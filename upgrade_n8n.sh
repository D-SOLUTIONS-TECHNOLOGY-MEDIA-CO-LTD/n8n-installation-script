#!/bin/bash
###########################################
# N8N Upgrade Script
# Version: 1.1.0
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

# Check if N8N is installed
if [ ! -f "/opt/n8n/docker-compose.yml" ]; then
    log_error "N8N chưa được cài đặt. Vui lòng chạy install_n8n.sh trước"
    exit 1
fi

# Check if n8n container is running
if ! docker ps --format '{{.Names}}' | grep -q "^n8n$"; then
    log_error "N8N container không chạy. Vui lòng khởi động N8N trước"
    log_info "Chạy: cd /opt/n8n && docker-compose up -d"
    exit 1
fi

echo "=========================================="
echo "   N8N Upgrade Script"
echo "   D-Solutions Technology Media Co., Ltd."
echo "=========================================="
echo ""

# Get current version
log_info "Kiểm tra phiên bản hiện tại..."
CURRENT_VERSION=$(docker exec n8n n8n --version 2>/dev/null || echo "unknown")
log_info "Phiên bản hiện tại: $CURRENT_VERSION"

# Backup before upgrade
BACKUP_DIR="/opt/n8n/backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="$BACKUP_DIR/pre_upgrade_$TIMESTAMP.sqlite"

log_info "Tạo backup trước khi nâng cấp..."

# Create backup directory if not exists
mkdir -p "$BACKUP_DIR"

# Method 1: Try using sqlite3 inside container (if available)
if docker exec n8n sh -c "command -v sqlite3" &> /dev/null; then
    log_info "Sử dụng sqlite3 trong container để backup..."
    docker exec n8n sh -c "sqlite3 /home/node/.n8n/database.sqlite \".backup '/backup/pre_upgrade_$TIMESTAMP.sqlite'\""
else
    # Method 2: Use docker cp to backup (fallback method)
    log_warn "sqlite3 không có trong container, sử dụng phương pháp backup trực tiếp..."
    
    # Stop n8n to ensure database integrity
    log_info "Dừng N8N tạm thời để đảm bảo tính toàn vẹn database..."
    docker stop n8n
    
    # Copy database file from container
    docker cp n8n:/home/node/.n8n/database.sqlite "$BACKUP_FILE"
    
    # Start n8n again
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

# Pull latest image
log_info "Tải phiên bản mới nhất..."
docker pull n8nio/n8n:latest

# Stop current container
log_info "Dừng container hiện tại..."
cd /opt/n8n
docker-compose stop n8n

# Recreate container with new image
log_info "Nâng cấp N8N container..."
docker-compose up -d --force-recreate n8n

# Wait for service to be ready
log_info "Đang chờ N8N khởi động..."
RETRY_COUNT=0
MAX_RETRIES=30

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if docker ps --format '{{.Names}}' | grep -q "^n8n$"; then
        if docker exec n8n n8n --version &> /dev/null; then
            log_info "✓ N8N đã sẵn sàng"
            break
        fi
    fi
    
    RETRY_COUNT=$((RETRY_COUNT + 1))
    echo -n "."
    sleep 2
done
echo ""

# Verify upgrade
if docker ps --format '{{.Names}}' | grep -q "^n8n$"; then
    NEW_VERSION=$(docker exec n8n n8n --version 2>/dev/null || echo "unknown")
    
    # Check if version changed
    if [ "$CURRENT_VERSION" != "$NEW_VERSION" ]; then
        log_info "✓ N8N đã được nâng cấp thành công"
    else
        log_warn "Phiên bản không thay đổi (có thể đã ở phiên bản mới nhất)"
    fi
    
    log_info "Phiên bản mới: $NEW_VERSION"
    
    # Health check
    log_info "Kiểm tra trạng thái N8N..."
    sleep 5
    
    if docker exec n8n n8n --version &> /dev/null; then
        log_info "✓ N8N hoạt động bình thường"
    else
        log_warn "N8N có thể cần thêm thời gian để khởi động hoàn toàn"
    fi
    
else
    log_error "✗ Có lỗi xảy ra khi nâng cấp"
    log_error "Kiểm tra logs: docker logs n8n"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🔄 HƯỚNG DẪN ROLLBACK:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "1. Dừng container:"
    echo "   docker-compose -f /opt/n8n/docker-compose.yml down"
    echo ""
    echo "2. Khôi phục database:"
    echo "   docker-compose -f /opt/n8n/docker-compose.yml up -d"
    echo "   docker cp $BACKUP_FILE n8n:/home/node/.n8n/database.sqlite"
    echo "   docker restart n8n"
    echo ""
    echo "3. Hoặc rollback về image cũ trong docker-compose.yml"
    echo ""
    exit 1
fi

echo ""
echo "=========================================="
log_info "✅ Nâng cấp hoàn tất!"
echo "=========================================="
echo ""
echo "📊 Thông tin phiên bản:"
echo "   - Phiên bản cũ: $CURRENT_VERSION"
echo "   - Phiên bản mới: $NEW_VERSION"
echo ""
echo "💾 Backup file:"
echo "   - $BACKUP_FILE"
if [ -f "$BACKUP_FILE" ]; then
    echo "   - Kích thước: $(du -h "$BACKUP_FILE" | cut -f1)"
fi
echo ""
echo "🔗 Truy cập N8N:"
echo "   - Kiểm tra docker-compose.yml để xem port và domain"
echo ""
echo "📝 Lưu ý:"
echo "   - Backup được lưu tại: $BACKUP_DIR"
echo "   - Nên giữ backup ít nhất 7 ngày"
echo "   - Kiểm tra workflows hoạt động bình thường"
echo ""
echo "Made with ❤️  by D-Solutions Team"
echo "=========================================="