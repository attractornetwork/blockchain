# Database Scripts

This directory contains scripts for backing up and restoring service databases in L2 Attractor enclaves.

## Scripts

### `create_backup.sh`
Creates comprehensive backups of all service databases in a Kurtosis enclave.

**Purpose:** Safeguard critical data before maintenance, updates, or service rebuilds.

**What it backs up:**
- Prover database
- Aggregator database  
- Bridge database
- Event database
- Pool database
- State database
- DAC database
- Pool manager database

**Usage:** `./create_backup.sh <enclave_name> [backup_directory]`

### `restore_service_data.sh`
Restores previously created database backups to running services in an enclave.

**Purpose:** Recover service data after rebuilding services or restoring from a backup.

**What it restores:**
- All available database dumps from the backup directory
- Automatically detects and restores available backup files
- Ensures data consistency across services

**Usage:** `./restore_service_data.sh <enclave_name> <backup_directory>`

## How It Works

Both scripts now use Docker container inspection and execution instead of Kurtosis CLI, making them completely independent and more reliable after server reboots or when Kurtosis CLI has issues.

**Service Detection:** Scripts look for containers with names matching the pattern `{service_name}--{enclave_uuid}` to identify services.

**Database Operations:** All PostgreSQL operations (backup, restore, verification) are performed using `docker exec` commands directly on the postgres container.

**Blockchain Data:** Erigon data backup and restore operations use `docker exec` and `docker cp` commands for reliable data transfer.

## Workflow

1. **Backup:** Use `create_backup.sh` before making changes to services
2. **Rebuild:** Rebuild services as needed
3. **Restore:** Use `restore_service_data.sh` to restore data to rebuilt services

## Prerequisites

- Docker installed and running
- Running enclave with postgres-001 service
- Appropriate permissions to access Docker containers
