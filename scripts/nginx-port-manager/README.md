# Nginx Port Manager for Kurtosis CDK

Automatic nginx port management for Kurtosis enclave changes.

## Files in this directory

### Main scripts (3 files):

1. **`nginx_update_ports.sh`** - MAIN SCRIPT
   - Extracts ports from Kurtosis enclave
   - Updates nginx configurations
   - Creates backups and validates configuration

2. **`nginx_auto_start.sh`** - Enable auto-updates
   - Installs systemd services for automatic updates

3. **`nginx_auto_stop.sh`** - Disable auto-updates
   - Stops and removes systemd services

## Quick start

```bash
# 1. Navigate to directory
cd scripts/nginx-port-manager/

# 2. Update ports now
sudo ./nginx_update_ports.sh
```

## Commands

### Main script - nginx_update_ports.sh

```bash
# Show help
./nginx_update_ports.sh --help

# Update nginx ports now
sudo ./nginx_update_ports.sh

# Update ports for specific enclave
sudo ./nginx_update_ports.sh my-enclave
```

## What the system does

### Supported services:
- **RPC** (`rpc.testnet.attra.me`) - HTTP and WebSocket ports
- **Explorer** (`explorer.testnet.attra.me`) - Frontend, API, Stats

## Automatic startup on boot

### Enable auto-startup:
```bash
# Enable automatic port updates on system boot (default: cdk enclave)
sudo ./nginx_auto_start.sh

# Enable for specific enclave
sudo ./nginx_auto_start.sh my-enclave
```

### Disable auto-startup:
```bash
# Disable automatic startup (service remains installed)
sudo ./nginx_auto_stop.sh

# Remove service completely
sudo ./nginx_auto_stop.sh --remove-all
```

## Installation

### Requirements:
- Docker and Docker Compose installed and running
- nginx running in docker container (attractor-nginx)
- Kurtosis CLI installed and configured
- Root privileges for configuration changes

### First time setup:
```bash
cd scripts/nginx-port-manager/

# Test the script
sudo ./nginx_update_ports.sh --help

# Run first update
sudo ./nginx_update_ports.sh
```

## How it works

### Manual update:
1. **Port extraction**: Script queries Kurtosis enclave for current service ports
2. **Configuration update**: Updates nginx .conf files with new ports
3. **Backup creation**: Creates backup of existing configurations
4. **Validation**: Tests nginx configuration using `docker exec attractor-nginx nginx -t`
5. **Reload**: Reloads nginx via `docker compose up -d` in `/opt/attractor`

### Automatic startup:
- **Systemd service**: `nginx-port-updater.service` runs on boot
- **Timing**: Executes 2 minutes after system startup (ensures all services are ready)
- **Enclave**: Automatically uses specified enclave name (default: `cdk`)
- **Logs**: All output goes to systemd journal (`journalctl -u nginx-port-updater`)

## Troubleshooting

### Check operation:
```bash
# Test nginx configuration
docker exec attractor-nginx nginx -t

# Check nginx container status
docker ps | grep attractor-nginx

# View script logs
tail -f /var/log/nginx-port-updater.log

# Check auto-startup service status
systemctl status nginx-port-updater

# Check if service is enabled for boot
systemctl is-enabled nginx-port-updater

# View service logs
journalctl -u nginx-port-updater -f
```

### Recovery on issues:
```bash
# Manual port update
sudo ./nginx_update_ports.sh

# Restore nginx if needed
cd /opt/attractor && sudo docker compose up -d
```
