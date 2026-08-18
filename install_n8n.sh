#!/bin/bash

###########################################
# N8N Installation Script for Ubuntu
# Version: 1.0.0
# Author: D-Solutions Team
###########################################

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    log_error "Vui lòng chạy script với quyền root (sudo)"
    exit 1
fi

# Banner
echo "=========================================="
echo "   N8N Installation Script"
echo "   D-Solutions Technology Media Co., Ltd."
echo "=========================================="
echo ""

# Check Ubuntu version
log_info "Kiểm tra hệ điều hành..."
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$NAME
    VER=$VERSION_ID
else
    log_error "Không thể xác định hệ điều hành"
    exit 1
fi

if [[ "$OS" != *"Ubuntu"* ]]; then
    log_error "Script này chỉ hỗ trợ Ubuntu"
    exit 1
fi

log_info "Hệ điều hành: $OS $VER"

# Get domain from user
echo ""
read -p "Nhập tên miền của bạn (ví dụ: n8n.yourdomain.com): " DOMAIN

if [ -z "$DOMAIN" ]; then
    log_error "Tên miền không được để trống"
    exit 1
fi

# Validate DNS
log_info "Kiểm tra DNS cho $DOMAIN..."
SERVER_IP=$(curl -s ifconfig.me)
DOMAIN_IP=$(dig +short $DOMAIN | tail -n1)

if [ -z "$DOMAIN_IP" ]; then
    log_error "Không thể resolve domain $DOMAIN"
    log_error "Vui lòng cấu hình DNS A record trỏ về IP: $SERVER_IP"
    exit 1
fi

if [ "$SERVER_IP" != "$DOMAIN_IP" ]; then
    log_warn "Domain $DOMAIN đang trỏ về $DOMAIN_IP"
    log_warn "IP server hiện tại: $SERVER_IP"
    read -p "Bạn có muốn tiếp tục? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Update system
log_info "Cập nhật hệ thống..."
apt-get update -qq
apt-get upgrade -y -qq

# Install dependencies
log_info "Cài đặt các gói phụ thuộc..."
apt-get install -y -qq \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    software-properties-common \
    sqlite3

# Install Docker
if ! command -v docker &> /dev/null; then
    log_info "Cài đặt Docker..."
    curl -fsSL https://get.docker.com | sh
    systemctl enable docker
    systemctl start docker
else
    log_info "Docker đã được cài đặt"
fi

# Install Docker Compose v2
# LƯU Ý: docker-compose v1 (Python 1.29.2) KHÔNG tương thích Docker Engine mới -
# fail KeyError 'ContainerConfig' khi recreate container (verified n8n box 08/2026).
# Bắt buộc dùng v2: ưu tiên plugin `docker compose`, fallback standalone binary.
COMPOSE_CMD="docker compose"
if ! docker compose version &> /dev/null; then
    log_info "Cài đặt Docker Compose v2 standalone..."
    curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    COMPOSE_CMD="docker-compose"
fi

# Create directories
log_info "Tạo cấu trúc thư mục..."
mkdir -p /opt/n8n/{data,caddy,backups}
chmod -R 755 /opt/n8n

# Create docker-compose.yml
log_info "Tạo file docker-compose.yml..."
cat > /opt/n8n/docker-compose.yml << EOF
version: '3.8'

services:
  n8n:
    image: n8nio/n8n:latest
    container_name: n8n
    restart: unless-stopped
    environment:
      - N8N_HOST=${DOMAIN}
      - N8N_PORT=5678
      - N8N_PROTOCOL=https
      - NODE_ENV=production
      - WEBHOOK_URL=https://${DOMAIN}/
      - GENERIC_TIMEZONE=Asia/Ho_Chi_Minh
      - N8N_LOG_LEVEL=info
      - EXECUTIONS_PROCESS=main
      - EXECUTIONS_MODE=regular
      - N8N_METRICS=false
      - N8N_DIAGNOSTICS_ENABLED=false
      - DB_TYPE=sqlite
      - DB_SQLITE_VACUUM_ON_STARTUP=true
    volumes:
      - /opt/n8n/data:/home/node/.n8n
      - /opt/n8n/backups:/backup
    networks:
      - n8n-network
    healthcheck:
      test: ["CMD", "wget", "--spider", "-q", "http://localhost:5678/healthz"]
      interval: 30s
      timeout: 10s
      retries: 3

  caddy:
    image: caddy:latest
    container_name: caddy
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - /opt/n8n/caddy/Caddyfile:/etc/caddy/Caddyfile
      - /opt/n8n/caddy/data:/data
      - /opt/n8n/caddy/config:/config
    networks:
      - n8n-network
    depends_on:
      - n8n

networks:
  n8n-network:
    driver: bridge
EOF

# Create Caddyfile
log_info "Tạo file Caddyfile..."
cat > /opt/n8n/caddy/Caddyfile << EOF
${DOMAIN} {
    reverse_proxy n8n:5678
    
    encode gzip
    
    header {
        X-Frame-Options "SAMEORIGIN"
        X-Content-Type-Options "nosniff"
        X-XSS-Protection "1; mode=block"
        Referrer-Policy "strict-origin-when-cross-origin"
    }
    
    log {
        output file /data/access.log
        format json
    }
}
EOF

# Set correct permissions
log_info "Thiết lập quyền truy cập..."
chown -R 1000:1000 /opt/n8n/data
chmod -R 755 /opt/n8n/caddy

# Start services
log_info "Khởi động N8N..."
cd /opt/n8n
$COMPOSE_CMD up -d

# Wait for services to start
log_info "Đang chờ các dịch vụ khởi động..."
sleep 10

# Check if services are running
if docker ps | grep -q "n8n"; then
    log_info "✓ N8N container đang chạy"
else
    log_error "✗ N8N container không khởi động được"
    docker logs n8n
    exit 1
fi

if docker ps | grep -q "caddy"; then
    log_info "✓ Caddy container đang chạy"
else
    log_error "✗ Caddy container không khởi động được"
    docker logs caddy
    exit 1
fi

# Setup backup cron job
log_info "Thiết lập backup tự động..."
cat > /etc/cron.daily/n8n-backup << 'EOF'
#!/bin/bash
# Backup n8n SQLite DB via the host sqlite3 .backup API.
# The n8nio/n8n image ships no sqlite3 CLI, so the backup MUST run on the host,
# against the mounted DB file (/opt/n8n/data <-> container /home/node/.n8n).
set -euo pipefail

BACKUP_DIR="/opt/n8n/backups"
DB_FILE="/opt/n8n/data/database.sqlite"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="$BACKUP_DIR/database_$TIMESTAMP.sqlite"

# Fail loudly (cron mail / stderr) instead of silently, so a broken backup is visible.
if ! command -v sqlite3 &> /dev/null; then
    echo "n8n-backup ERROR: sqlite3 not found on host" >&2
    exit 1
fi
if [ ! -f "$DB_FILE" ]; then
    echo "n8n-backup ERROR: database not found at $DB_FILE" >&2
    exit 1
fi

mkdir -p "$BACKUP_DIR"

# .backup = SQLite online backup API: consistent snapshot even while n8n is writing.
sqlite3 "$DB_FILE" ".backup '$BACKUP_FILE'"

# Verify the backup was actually produced and is non-empty before pruning old ones.
if [ ! -s "$BACKUP_FILE" ]; then
    echo "n8n-backup ERROR: backup file empty or missing: $BACKUP_FILE" >&2
    exit 1
fi

# Keep only last 7 days of backups
find "$BACKUP_DIR" -name "database_*.sqlite" -mtime +7 -delete

echo "Backup completed: $BACKUP_FILE"
EOF

chmod +x /etc/cron.daily/n8n-backup

# Final message
echo ""
echo "=========================================="
log_info "✅ Cài đặt hoàn tất!"
echo "=========================================="
echo ""
echo "🌐 Truy cập N8N tại: https://${DOMAIN}"
echo ""
echo "📋 Thông tin hữu ích:"
echo "   - Thư mục cài đặt: /opt/n8n"
echo "   - Database: /opt/n8n/data/database.sqlite"
echo "   - Backups: /opt/n8n/backups"
echo "   - Logs: docker logs n8n"
echo ""
echo "🔧 Các lệnh hữu ích:"
echo "   - Xem logs: docker logs -f n8n"
echo "   - Khởi động lại: $COMPOSE_CMD -f /opt/n8n/docker-compose.yml restart"
echo "   - Dừng: $COMPOSE_CMD -f /opt/n8n/docker-compose.yml down"
echo "   - Khởi động: $COMPOSE_CMD -f /opt/n8n/docker-compose.yml up -d"
echo ""
echo "⚠️  Lưu ý: Có thể mất vài phút để Caddy tạo SSL certificate"
echo ""
echo "Made with ❤️  by D-Solutions Team"
echo "=========================================="
