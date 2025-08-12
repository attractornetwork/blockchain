# Database Backup and Restore Scripts

This directory contains scripts for backing up and restoring service databases in L2 Attractor enclaves.

## Scripts

### `create_backup.sh`
Creates comprehensive backups of all service databases in a Kurtosis enclave.

**Purpose:** Safeguard critical data before service rebuilds, migrations, or maintenance operations.

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
Restores database dumps to running services after they have been rebuilt.

**Purpose:** Restore service state and data after service reconstruction or when migrating to new enclaves.

**What it restores:**
- All available database backups from the specified backup directory
- Automatically detects and restores available backup files
- Ensures data consistency across services

**Usage:** `./restore_service_data.sh <enclave_name> <backup_directory>`

## Typical Workflow

1. **Before maintenance:** Use `create_backup.sh` to save current state
2. **After service rebuild:** Use `restore_service_data.sh` to restore data
3. **Data migration:** Use both scripts to move data between enclaves

## Requirements

- Kurtosis CLI installed and configured
- Running enclave with PostgreSQL service
- Appropriate permissions to access enclave services
