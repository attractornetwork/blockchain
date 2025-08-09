# Nginx Port Manager for Kurtosis CDK

Automatic nginx port management for Kurtosis enclave changes.

## Files in this directory

### Main scripts (4 files):

1. **`nginx_manager.sh`** - MAIN SCRIPT
   - Unified management interface
   - 3 simple commands: update, start, stop

2. **`nginx_update_ports.sh`** - Port update
   - Extracts ports from Kurtosis enclave
   - Updates nginx configurations
   - Creates backups and validates configuration

3. **`nginx_auto_start.sh`** - Enable auto-update
   - Installs systemd services
   - Configures update interval
   - Activates automatic updates

4. **`nginx_auto_stop.sh`** - Disable auto-update
   - Stops systemd services
   - Disables automatic updates
   - Optionally removes files

## Quick start

```bash
# 1. Navigate to directory
cd scripts/nginx-port-manager/

# 2. Update ports now
./nginx_manager.sh update

# 3. Enable auto-update every 5 minutes
./nginx_manager.sh start 5

# 4. Disable auto-update
./nginx_manager.sh stop
```

## Commands

### Main script - nginx_manager.sh

```bash
# Show help
./nginx_manager.sh

# Update nginx ports now
./nginx_manager.sh update

# Enable auto-update every N minutes
./nginx_manager.sh start 5      # every 5 minutes
./nginx_manager.sh start 10     # every 10 minutes
./nginx_manager.sh start 15     # every 15 minutes

# Disable auto-update
./nginx_manager.sh stop
```

### Direct commands (if needed)

```bash
# Port update only
sudo ./nginx_update_ports.sh

# Enable auto-update only (5 minute interval)
sudo ./nginx_auto_start.sh --interval=5

# Disable auto-update only
sudo ./nginx_auto_stop.sh --force
```

## Server installation

```bash
# 1. Copy all 4 files to server
scp nginx_manager.sh nginx_update_ports.sh nginx_auto_start.sh nginx_auto_stop.sh user@server:/tmp/

# 2. On server - make executable
ssh user@server
chmod +x /tmp/nginx_*.sh

# 3. Start auto-update
sudo /tmp/nginx_manager.sh start 5

# 4. Test (update ports now)
sudo /tmp/nginx_manager.sh update
```

## What the system does

### Supported services:
- **RPC** (`rpc.testnet.attra.me`) - HTTP and WebSocket ports
- **Explorer** (`explorer.testnet.attra.me`) - Frontend, API, Stats
- **Bridge UI** (`bridge.testnet.attra.me`) - Bridge web interface
- **DAC** (`da.testnet.attra.me`) - Data Availability Committee
- **Faucet** (`faucet.testnet.attra.me`) - Token faucet (optional)

### Update process:
1. Extracts current ports from `kurtosis enclave inspect cdk`
2. Creates backup of current nginx configurations
3. Generates new configurations with current ports
4. Validates nginx configuration (`nginx -t`)
5. Reloads nginx or restores from backup on errors

## Files created in the system

When auto-update is installed:

```
/opt/attractor/scripts/
└── nginx_update_ports.sh                    # Working copy of script

/etc/systemd/system/
├── nginx-port-updater.service               # systemd service
└── nginx-port-updater.timer                 # systemd timer

/opt/attractor/nginx/conf.d/
├── rpc.testnet.attra.me.conf                # RPC configuration
├── explorer.testnet.attra.me.conf           # Explorer configuration
├── bridge.testnet.attra.me.conf             # Bridge configuration
├── da.testnet.attra.me.conf                 # DAC configuration
└── backup/                                  # Configuration backups

/var/log/
└── nginx-port-updater.log                   # Script logs
```

## Checking operation

```bash
# Check systemd service status
sudo systemctl status nginx-port-updater.service
sudo systemctl status nginx-port-updater.timer

# View logs
sudo journalctl -u nginx-port-updater.service -f
sudo tail -f /var/log/nginx-port-updater.log

# Check nginx
sudo nginx -t
sudo systemctl status nginx

# Check enclave
kurtosis enclave inspect cdk
```

## Requirements

- **Kurtosis CLI** installed and available
- **nginx** installed and running
- **systemd** (for auto-update)
- **Root privileges** for nginx configuration changes
- **CDK enclave** running in Kurtosis

## Recovery on issues

```bash
# Stop auto-update and remove all files
sudo ./nginx_manager.sh stop

# Restore nginx configurations from backup
sudo cp /opt/attractor/nginx/conf.d/backup/*.conf /opt/attractor/nginx/conf.d/
sudo systemctl reload nginx
``` 
