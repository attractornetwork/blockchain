# Nginx Port Manager for Kurtosis CDK

Automatic nginx port management for Kurtosis enclave changes.

## Files in this directory

### Main scripts (4 files):

1. **`nginx_manager.sh`** - MAIN SCRIPT
   - Unified management interface
   - 1 simple command: update

2. **`nginx_update_ports.sh`** - Port update
   - Extracts ports from Kurtosis enclave
   - Updates nginx configurations
   - Creates backups and validates configuration

## Quick start

```bash
# 1. Navigate to directory
cd scripts/nginx-port-manager/

# 2. Update ports now
./nginx_manager.sh update
```

## Commands

### Main script - nginx_manager.sh

```bash
# Show help
./nginx_manager.sh

# Update nginx ports now
./nginx_manager.sh update
```

### Direct commands (if needed)

```bash
# Port update only
sudo ./nginx_update_ports.sh
```

## What the system does

### Supported services:
- **RPC** (`rpc.testnet.attra.me`) - HTTP and WebSocket ports
- **Explorer** (`explorer.testnet.attra.me`) - Frontend, API, Stats
