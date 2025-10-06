#!/bin/bash

###########################################
# N8N Upgrade Script
# Version: 1.0.0
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

# Check if N8N is installed
if [ ! -f "/opt/n8n/docker-compose.yml" ]; then
    log_error "N8N chưa được cài đặt. Vui lòng chạy install_n8n.sh trước"
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
docker exec n8n sh -c "sqlite3 /home/node/.n8n/database.sqlite \".backup '/backup/pre_upgrade_$TIMESTAMP.sqlite'\""
log_info "✓ Backup lưu tại: $BACKUP_FILE"

# Pull latest image
log_info "Tải phiên bản mới nhất..."
docker pull n8nio/n8n:latest

# Recreate container
log_info "Nâng cấp N8N container..."
cd /opt/n8n
docker-compose up -d --force-recreate n8n

# Wait for service
log_info "Đang chờ N8N khởi động..."
sleep 15

# Check if running
if docker ps | grep -q "n8n"; then
    NEW_VERSION=$(docker exec n8n n8n --version 2>/dev/null || echo "unknown")
    log_info "✓ N8N đã được nâng cấp thành công"
    log_info "Phiên bản mới: $NEW_VERSION"
else
    log_error "✗ Có lỗi xảy ra khi nâng cấp"
    log_error "Kiểm tra logs: docker logs n8n"
    echo ""
    echo "Để rollback, chạy:"
    echo "  docker-compose -f /opt/n8n/docker-compose.yml down"
    echo "  docker cp $BACKUP_FILE n8n:/home/node/.n8n/database.sqlite"
    echo "  docker-compose -f /opt/n8n/docker-compose.yml up -d"
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
echo ""
echo "Made with ❤️  by D-Solutions Team"
echo "=========================================="
