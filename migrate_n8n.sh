#!/bin/bash

###########################################
# N8N Migration Script
# Version: 1.0.0
# Author: D-Solutions Team
###########################################

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

echo "=========================================="
echo "   N8N Migration Script"
echo "   D-Solutions Technology Media Co., Ltd."
echo "=========================================="
echo ""

# Detect mode
if [ -f "/opt/n8n/docker-compose.yml" ] && docker ps | grep -q "n8n"; then
    MODE="export"
    log_info "Phát hiện: Server NGUỒN (có N8N đang chạy)"
elif [ -f "/tmp/n8n-export-"*.tar.gz ] || ls /tmp/n8n-export-*.tar.gz &> /dev/null; then
    MODE="import"
    log_info "Phát hiện: Server ĐÍCH (có file export)"
else
    log_error "Không phát hiện được môi trường phù hợp"
    echo ""
    echo "Hướng dẫn:"
    echo "  - Server NGUỒN: Chạy script để export data"
    echo "  - Server ĐÍCH: Copy file export vào /tmp/ rồi chạy script"
    exit 1
fi

if [ "$MODE" == "export" ]; then
    # EXPORT MODE
    log_info "Bắt đầu xuất dữ liệu từ server hiện tại..."
    
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    EXPORT_DIR="/tmp/n8n-export-$TIMESTAMP"
    EXPORT_FILE="/tmp/n8n-export-$TIMESTAMP.tar.gz"
    
    mkdir -p $EXPORT_DIR
    
    # Export database
    log_info "Đang xuất database..."
    docker exec n8n sh -c "sqlite3 /home/node/.n8n/database.sqlite \".backup '/tmp/database.sqlite'\""
    docker cp n8n:/tmp/database.sqlite $EXPORT_DIR/
    
    # Export credentials encryption key
    log_info "Đang xuất encryption key..."
    docker exec n8n sh -c "cat /home/node/.n8n/config" > $EXPORT_DIR/config || true
    
    # Create metadata
    cat > $EXPORT_DIR/metadata.txt << EOF
Export Date: $(date)
N8N Version: $(docker exec n8n n8n --version)
Server IP: $(curl -s ifconfig.me)
Export By: $(whoami)
EOF
    
    # Create archive
    log_info "Đang nén file..."
    cd /tmp
    tar -czf $EXPORT_FILE n8n-export-$TIMESTAMP/
    
    # Checksum
    CHECKSUM=$(sha256sum $EXPORT_FILE | awk '{print $1}')
    echo $CHECKSUM > ${EXPORT_FILE}.sha256
    
    # Cleanup temp dir
    rm -rf $EXPORT_DIR
    
    echo ""
    echo "=========================================="
    log_info "✅ Xuất dữ liệu hoàn tất!"
    echo "=========================================="
    echo ""
    echo "📦 File export:"
    echo "   - $EXPORT_FILE"
    echo "   - Size: $(du -h $EXPORT_FILE | cut -f1)"
    echo "   - SHA256: $CHECKSUM"
    echo ""
    echo "📤 Bước tiếp theo:"
    echo "   1. Copy file sang server mới:"
    echo "      scp $EXPORT_FILE user@new-server:/tmp/"
    echo ""
    echo "   2. Trên server mới, chạy script này để import"
    echo ""
    echo "Made with ❤️  by D-Solutions Team"
    echo "=========================================="
    
else
    # IMPORT MODE
    EXPORT_FILE=$(ls -t /tmp/n8n-export-*.tar.gz 2>/dev/null | head -1)
    
    if [ -z "$EXPORT_FILE" ]; then
        log_error "Không tìm thấy file export trong /tmp/"
        exit 1
    fi
    
    log_info "Tìm thấy file: $EXPORT_FILE"
    
    # Verify checksum if exists
    if [ -f "${EXPORT_FILE}.sha256" ]; then
        log_info "Kiểm tra checksum..."
        EXPECTED_CHECKSUM=$(cat ${EXPORT_FILE}.sha256)
        ACTUAL_CHECKSUM=$(sha256sum $EXPORT_FILE | awk '{print $1}')
        
        if [ "$EXPECTED_CHECKSUM" == "$ACTUAL_CHECKSUM" ]; then
            log_info "✓ Checksum hợp lệ"
        else
            log_error "✗ Checksum không khớp!"
            log_error "Expected: $EXPECTED_CHECKSUM"
            log_error "Actual: $ACTUAL_CHECKSUM"
            exit 1
        fi
    fi
    
    # Extract
    log_info "Giải nén file export..."
    EXTRACT_DIR=$(basename $EXPORT_FILE .tar.gz)
    cd /tmp
    tar -xzf $EXPORT_FILE
    
    # Check if N8N is installed
    if [ ! -f "/opt/n8n/docker-compose.yml" ]; then
        log_warn "N8N chưa được cài đặt trên server này"
        read -p "Bạn có muốn chạy script cài đặt không? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            log_info "Vui lòng chạy install_n8n.sh trước, sau đó chạy lại migration script"
            exit 0
        else
            exit 1
        fi
    fi
    
    # Backup current data
    log_info "Backup dữ liệu hiện tại..."
    BACKUP_DIR="/opt/n8n/backups"
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    docker exec n8n sh -c "sqlite3 /home/node/.n8n/database.sqlite \".backup '/backup/pre_migration_$TIMESTAMP.sqlite'\"" || true
    
    # Stop N8N
    log_info "Dừng N8N..."
    docker-compose -f /opt/n8n/docker-compose.yml down
    
    # Import database
    log_info "Import database..."
    cp /tmp/$EXTRACT_DIR/database.sqlite /opt/n8n/data/database.sqlite
    chown 1000:1000 /opt/n8n/data/database.sqlite
    
    # Import config if exists
    if [ -f "/tmp/$EXTRACT_DIR/config" ]; then
        log_info "Import encryption key..."
        cp /tmp/$EXTRACT_DIR/config /opt/n8n/data/config
        chown 1000:1000 /opt/n8n/data/config
    fi
    
    # Start N8N
    log_info "Khởi động N8N..."
    docker-compose -f /opt/n8n/docker-compose.yml up -d
    
    # Wait
    log_info "Đang chờ N8N khởi động..."
    sleep 15
    
    # Verify
    if docker ps | grep -q "n8n"; then
        log_info "✓ N8N đã khởi động thành công"
    else
        log_error "✗ N8N không khởi động được"
        log_error "Kiểm tra logs: docker logs n8n"
        exit 1
    fi
    
    # Cleanup
    rm -rf /tmp/$EXTRACT_DIR
    
    echo ""
    echo "=========================================="
    log_info "✅ Migration hoàn tất!"
    echo "=========================================="
    echo ""
    echo "🎉 N8N đã được import thành công"
    echo ""
    echo "📋 Kiểm tra:"
    echo "   - Truy cập N8N và đăng nhập"
    echo "   - Kiểm tra workflows"
    echo "   - Test các credentials"
    echo "   - Kiểm tra webhook URLs"
    echo ""
    echo "💾 Backup trước khi migration:"
    echo "   - $BACKUP_DIR/pre_migration_$TIMESTAMP.sqlite"
    echo ""
    echo "Made with ❤️  by D-Solutions Team"
    echo "=========================================="
fi
