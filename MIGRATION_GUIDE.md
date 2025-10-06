# 🚀 N8N Migration Guide

Complete guide for migrating N8N from one VPS to another.

## 📋 Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Migration Steps](#migration-steps)
- [Troubleshooting](#troubleshooting)
- [FAQ](#faq)

## Overview

The migration script (`migrate_n8n.sh`) helps you move your N8N instance from one server to another with:
- ✅ Complete data export/import
- ✅ Checksum verification for data integrity
- ✅ Automatic backups before import
- ✅ Zero-configuration migration

## Prerequisites

### On Source Server (Old VPS)
- N8N must be running
- Root or sudo access
- Script: `migrate_n8n.sh`

### On Destination Server (New VPS)
- Fresh Ubuntu 20.04+ installation
- N8N installed (using `install_n8n.sh`)
- Root or sudo access
- Script: `migrate_n8n.sh`

## Migration Steps

### Step 1: Export from Source Server

```bash
# Download migration script
curl -sSL https://raw.githubusercontent.com/D-SOLUTIONS-TECHNOLOGY-MEDIA-CO-LTD/n8n-installation-script/main/migrate_n8n.sh > migrate_n8n.sh
chmod +x migrate_n8n.sh

# Run export
sudo ./migrate_n8n.sh
```

**Output:**
```
Export file: /tmp/n8n-export-20251006_143022.tar.gz
Size: 12.5 MB
SHA256: a1b2c3d4...
```

### Step 2: Transfer Export File

**Option A: Using SCP**
```bash
scp /tmp/n8n-export-*.tar.gz user@new-server-ip:/tmp/
scp /tmp/n8n-export-*.tar.gz.sha256 user@new-server-ip:/tmp/
```

**Option B: Using SFTP**
```bash
sftp user@new-server-ip
put /tmp/n8n-export-*.tar.gz
put /tmp/n8n-export-*.tar.gz.sha256
bye
```

**Option C: Using rsync**
```bash
rsync -avz /tmp/n8n-export-*.tar.gz user@new-server-ip:/tmp/
```

### Step 3: Setup Destination Server

```bash
# Install N8N on new server first
curl -sSL https://raw.githubusercontent.com/D-SOLUTIONS-TECHNOLOGY-MEDIA-CO-LTD/n8n-installation-script/main/install_n8n.sh > install_n8n.sh
chmod +x install_n8n.sh
sudo ./install_n8n.sh
```

**Important:** Use the same or new domain name when prompted.

### Step 4: Import to Destination Server

```bash
# Download migration script
curl -sSL https://raw.githubusercontent.com/D-SOLUTIONS-TECHNOLOGY-MEDIA-CO-LTD/n8n-installation-script/main/migrate_n8n.sh > migrate_n8n.sh
chmod +x migrate_n8n.sh

# Run import (script auto-detects export file in /tmp/)
sudo ./migrate_n8n.sh
```

**The script will:**
1. Verify checksum
2. Backup current data (if any)
3. Stop N8N
4. Import database and configs
5. Start N8N
6. Verify services

### Step 5: Verify Migration

```bash
# Check N8N status
docker ps | grep n8n

# View logs
docker logs n8n

# Access web interface
https://your-new-domain.com
```

**Checklist:**
- [ ] Login with existing credentials
- [ ] All workflows are present
- [ ] All credentials are working
- [ ] Webhook URLs are updated
- [ ] Scheduled workflows are active
- [ ] Executions history is present

## Update DNS

After successful migration:

1. **Update A Record**
   - Point your domain to new server IP
   - Wait for DNS propagation (5-60 minutes)

2. **Verify DNS**
   ```bash
   dig +short your-domain.com
   nslookup your-domain.com
   ```

3. **Test HTTPS**
   ```bash
   curl -I https://your-domain.com
   ```

## Rollback (If Needed)

If something goes wrong on the destination server:

```bash
# Stop N8N
sudo docker-compose -f /opt/n8n/docker-compose.yml down

# Restore pre-migration backup
sudo cp /opt/n8n/backups/pre_migration_*.sqlite /opt/n8n/data/database.sqlite

# Start N8N
sudo docker-compose -f /opt/n8n/docker-compose.yml up -d
```

On source server, you can keep it running as backup until migration is verified.

## Troubleshooting

### Export File Not Found

**Problem:** Script can't find N8N installation
```bash
# Verify N8N is running
docker ps | grep n8n

# Check installation
ls -la /opt/n8n/
```

### Checksum Mismatch

**Problem:** File corrupted during transfer
```bash
# Re-transfer the file
scp /tmp/n8n-export-*.tar.gz user@new-server:/tmp/

# Or generate new checksum
sha256sum /tmp/n8n-export-*.tar.gz > /tmp/n8n-export-*.tar.gz.sha256
```

### Import Fails

**Problem:** N8N won't start after import
```bash
# Check logs
docker logs n8n

# Verify permissions
sudo chown -R 1000:1000 /opt/n8n/data

# Restart
sudo docker-compose -f /opt/n8n/docker-compose.yml restart
```

### Webhook URLs Not Working

**Problem:** Old webhook URLs still pointing to old server

**Solution:**
1. Update DNS to point to new server
2. Wait for DNS propagation
3. Webhooks will automatically work once DNS updates

**Or manually update in workflows:**
1. Open each workflow
2. Edit webhook nodes
3. Click "Test URL" to regenerate
4. Save workflow

## FAQ

### Q: How long does migration take?
**A:** Typically 10-20 minutes depending on data size and transfer speed.

### Q: Will my workflows stop working during migration?
**A:** Yes, briefly. Old server keeps running until you update DNS. After DNS update, there might be 5-60 minutes of downtime during DNS propagation.

### Q: Can I migrate to a different domain?
**A:** Yes! Just use the new domain when running `install_n8n.sh` on destination server. All workflows and credentials are preserved.

### Q: What if I have custom SSL certificates?
**A:** Migration script doesn't handle custom certs. After migration, you'll need to manually configure Caddy with your certificates.

### Q: Can I migrate from Docker to non-Docker installation?
**A:** No, this script only supports Docker-to-Docker migration.

### Q: Do I need to backup before migration?
**A:** The script automatically creates backups, but it's recommended to have manual backups as well.

### Q: Can I test migration before making it live?
**A:** Yes! Set up destination server with a different test domain, complete migration, test everything, then update DNS to make it live.

### Q: What about running executions?
**A:** Running executions on source server will be interrupted. Wait for critical executions to complete before starting migration.

## Best Practices

1. **Plan During Low Traffic**
   - Schedule migration during off-peak hours
   - Notify users about maintenance window

2. **Test Thoroughly**
   - Use test domain for initial migration
   - Verify all workflows and credentials
   - Test webhooks and API calls

3. **Keep Source Server Running**
   - Don't shut down source until migration verified
   - Keep it as backup for rollback

4. **Document Your Setup**
   - Note any custom configurations
   - List all integrations and webhooks
   - Keep credentials secure

5. **Monitor After Migration**
   - Watch logs for errors
   - Check execution history
   - Verify scheduled workflows trigger

## Advanced: Manual Migration

If you prefer manual control:

```bash
# On source server
sudo docker exec n8n sh -c "sqlite3 /home/node/.n8n/database.sqlite '.backup /tmp/database.sqlite'"
sudo docker cp n8n:/tmp/database.sqlite ./
scp database.sqlite user@new-server:/tmp/

# On destination server
sudo docker-compose -f /opt/n8n/docker-compose.yml down
sudo cp /tmp/database.sqlite /opt/n8n/data/database.sqlite
sudo chown 1000:1000 /opt/n8n/data/database.sqlite
sudo docker-compose -f /opt/n8n/docker-compose.yml up -d
```

## Support

Need help? Contact us:
- 📧 Email: support@d-solutions.vn
- 🌐 Website: [d-solutions.vn](https://d-solutions.vn)
- 💬 GitHub Issues: [Create Issue](https://github.com/D-SOLUTIONS-TECHNOLOGY-MEDIA-CO-LTD/n8n-installation-script/issues)

---

**Made with ❤️ by D-Solutions Team**
