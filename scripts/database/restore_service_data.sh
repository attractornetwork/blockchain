#!/bin/bash

# Service data restoration script for L2 Attractor
# Usage: ./scripts/database/restore_service_data.sh <enclave_name> <backup_directory>

set -e

# Check we receive 2 params
if [ "$#" -ne 2 ]; then
    echo "Usage: restore_service_data.sh <enclave_name> <backup_directory>"
    echo "Example: ./scripts/database/restore_service_data.sh cdk /mnt/c/Users/oneze/kurtosis-test/blockchain/scripts/database/backup"
    echo ""
    echo "This script restores database dumps to running services in the enclave."
    echo "It should be used after rebuilding services with rebuild_single_service.sh"
    exit 1
fi

ENCLAVE_NAME=$1
BACKUP_DIR=$2

echo "=== SERVICE DATA RESTORATION ==="
echo "Enclave: $ENCLAVE_NAME"
echo "Backup directory: $BACKUP_DIR"
echo ""

# Check if enclave exists
if ! kurtosis enclave ls | grep -q "$ENCLAVE_NAME"; then
    echo "ERROR: Enclave '$ENCLAVE_NAME' not found!"
    echo "Available enclaves:"
    kurtosis enclave ls
    exit 1
fi

# Check if backup directory exists
if [ ! -d "$BACKUP_DIR" ]; then
    echo "ERROR: Backup directory '$BACKUP_DIR' not found!"
    exit 1
fi

# Function to check if service exists
service_exists() {
    local service=$1
    kurtosis enclave inspect "$ENCLAVE_NAME" | grep -q "[[:space:]]${service}[[:space:]]"
}

# Function to check if service is running
service_is_running() {
    local service=$1
    kurtosis enclave inspect "$ENCLAVE_NAME" | grep -A 2 "[[:space:]]${service}[[:space:]]" | grep -q "RUNNING"
}

# Check if postgres service exists
POSTGRES_SERVICE="postgres-001"
if ! service_exists "$POSTGRES_SERVICE"; then
    echo "ERROR: Postgres service '$POSTGRES_SERVICE' not found in enclave '$ENCLAVE_NAME'!"
    echo "Available services:"
    kurtosis enclave inspect "$ENCLAVE_NAME" | grep -E "^[[:space:]]*[a-zA-Z0-9-]+(-[0-9]+)?[[:space:]]" | awk '{print $2}' | grep -v "^$"
    exit 1
fi

# Check if postgres is running
if ! service_is_running "$POSTGRES_SERVICE"; then
    echo "ERROR: Postgres service '$POSTGRES_SERVICE' is not running!"
    echo "Please ensure postgres is running before restoring data."
    exit 1
fi

echo "✅ Postgres service found and running"

# List available backup files
echo ""
echo "=== Available backup files ==="
BACKUP_FILES=()
if [ -f "$BACKUP_DIR/prover_db_backup.sql" ]; then
    BACKUP_FILES+=("prover_db_backup.sql")
    echo "✅ prover_db_backup.sql"
fi
if [ -f "$BACKUP_DIR/aggregator_db_backup.sql" ]; then
    BACKUP_FILES+=("aggregator_db_backup.sql")
    echo "✅ aggregator_db_backup.sql"
fi
if [ -f "$BACKUP_DIR/bridge_db_backup.sql" ]; then
    BACKUP_FILES+=("bridge_db_backup.sql")
    echo "✅ bridge_db_backup.sql"
fi
if [ -f "$BACKUP_DIR/dac_db_backup.sql" ]; then
    BACKUP_FILES+=("dac_db_backup.sql")
    echo "✅ dac_db_backup.sql"
fi
if [ -f "$BACKUP_DIR/pool_manager_db_backup.sql" ]; then
    BACKUP_FILES+=("pool_manager_db_backup.sql")
    echo "✅ pool_manager_db_backup.sql"
fi

if [ ${#BACKUP_FILES[@]} -eq 0 ]; then
    echo "❌ No backup files found in $BACKUP_DIR"
    echo "Available files:"
    ls -la "$BACKUP_DIR"
    exit 1
fi

echo ""
echo "Found ${#BACKUP_FILES[@]} backup file(s) to restore"

# Confirmation prompt
echo ""
echo "⚠️  WARNING: This will restore database data from backup files!"
echo "This operation will overwrite existing data in the databases."
echo "Make sure you have stopped all services that use these databases."
echo ""
read -p "Are you sure you want to restore data from backup? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Restoration cancelled."
    exit 0
fi

echo ""
echo "=== Restoring database data ==="

# Function to restore database
restore_database() {
    local backup_file=$1
    local db_name=$2
    local db_user=$3

    echo "Restoring $db_name from $backup_file..."

    # Upload backup file to postgres container using base64
    echo "Uploading backup file to postgres container..."

    # Encode the backup file to base64 and upload
    if base64 "$BACKUP_DIR/$backup_file" | kurtosis service exec "$ENCLAVE_NAME" "$POSTGRES_SERVICE" "base64 -d > /tmp/$backup_file"; then
        echo "✅ File uploaded successfully"

        # Check if database exists and has active connections
        echo "Checking database $db_name status..."

        # Check if database exists (more reliable method)
        db_exists_result=$(kurtosis service exec "$ENCLAVE_NAME" "$POSTGRES_SERVICE" "PGPASSWORD=master_password psql -U master_user -d master -c \"SELECT datname FROM pg_database WHERE datname = '$db_name';\" 2>/dev/null | grep -c '$db_name' || echo '0'")

        if [ "$db_exists_result" = "1" ]; then
            echo "Database $db_name exists. Force dropping and recreating for complete data replacement..."

            # Force drop database (terminate connections first)
            echo "Terminating all connections to $db_name..."
            kurtosis service exec "$ENCLAVE_NAME" "$POSTGRES_SERVICE" "PGPASSWORD=master_password psql -U master_user -d master -c \"SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '$db_name' AND pid <> pg_backend_pid();\" 2>/dev/null || true"

            echo "Dropping and recreating $db_name..."
            kurtosis service exec "$ENCLAVE_NAME" "$POSTGRES_SERVICE" "PGPASSWORD=master_password psql -U master_user -d master -c \"DROP DATABASE IF EXISTS $db_name;\""
            kurtosis service exec "$ENCLAVE_NAME" "$POSTGRES_SERVICE" "PGPASSWORD=master_password psql -U master_user -d master -c \"CREATE DATABASE $db_name;\""
            kurtosis service exec "$ENCLAVE_NAME" "$POSTGRES_SERVICE" "PGPASSWORD=master_password psql -U master_user -d master -c \"GRANT ALL PRIVILEGES ON DATABASE $db_name TO $db_user;\""
        else
            echo "Creating database $db_name..."
            kurtosis service exec "$ENCLAVE_NAME" "$POSTGRES_SERVICE" "PGPASSWORD=master_password psql -U master_user -d master -c \"CREATE DATABASE $db_name;\""
            kurtosis service exec "$ENCLAVE_NAME" "$POSTGRES_SERVICE" "PGPASSWORD=master_password psql -U master_user -d master -c \"GRANT ALL PRIVILEGES ON DATABASE $db_name TO $db_user;\""
        fi

        # Restore data
        echo "Restoring data to $db_name..."
        if kurtosis service exec "$ENCLAVE_NAME" "$POSTGRES_SERVICE" "PGPASSWORD=master_password psql -U $db_user -d $db_name < /tmp/$backup_file"; then
            echo "✅ Successfully restored $db_name"
        else
            echo "❌ Failed to restore $db_name"
            return 1
        fi

        # Clean up uploaded file
        kurtosis service exec "$ENCLAVE_NAME" "$POSTGRES_SERVICE" "rm -f /tmp/$backup_file"
    else
        echo "❌ Failed to upload backup file"
        return 1
    fi
}

# Helper to restore a specific erigon service from a given archive via docker cp
restore_erigon_service_datadir() {
    local service_name="$1"
    local archive_path="$2"

    if ! service_exists "$service_name"; then
        echo "⚠️  Service '$service_name' not found, skipping"
        return 0
    fi

    echo "✅ Target service: $service_name"

    # Determine docker binary (with sudo if needed)
    local DOCKER_BIN="docker"
    if [ "$(id -u)" -ne 0 ] && command -v sudo >/dev/null 2>&1; then
        DOCKER_BIN="sudo docker"
    fi

    # Find running container ID
    echo "Getting container ID for $service_name..."
    local CONTAINER_ID=$($DOCKER_BIN ps | grep -F "${service_name}--" | awk '{print $1}')
    if [ -z "$CONTAINER_ID" ]; then
        echo "❌ Could not find running container for $service_name"
        echo "Available containers:"
        $DOCKER_BIN ps | grep -F erigon || true
        return 1
    fi
    echo "Found container ID: $CONTAINER_ID"

    # Stop erigon process inside container (keep container alive via proc-runner TRAP)
    echo "Stopping erigon process (container stays up)..."
    kurtosis service exec "$ENCLAVE_NAME" "$service_name" "kill -s TRAP 1 || kill -5 1" || true
    sleep 2

    # Clean existing datadir contents to avoid mixing indexes
    echo "Cleaning datadir contents..."
    kurtosis service exec "$ENCLAVE_NAME" "$service_name" "mkdir -p /home/erigon/data/dynamic-Attractor-sequencer && rm -rf /home/erigon/data/dynamic-Attractor-sequencer/*" || true

    # Copy archive into container
    echo "Copying archive to container..."
    if ! $DOCKER_BIN cp "$archive_path" "$CONTAINER_ID:/tmp/blockchain_data_backup.tar.gz"; then
        echo "❌ Failed to copy archive to container"
        return 1
    fi
    echo "✅ Archive copied"

    # Verify inside container
    kurtosis service exec "$ENCLAVE_NAME" "$service_name" "ls -lh /tmp/blockchain_data_backup.tar.gz"

    # Extract into datadir
    echo "Extracting into /home/erigon/data..."
    if ! kurtosis service exec "$ENCLAVE_NAME" "$service_name" "cd /home/erigon/data && tar -xzf /tmp/blockchain_data_backup.tar.gz && rm -f /tmp/blockchain_data_backup.tar.gz && chown -R erigon:erigon dynamic-Attractor-sequencer || true"; then
        echo "❌ Extraction failed"
        return 1
    fi
    echo "✅ Extraction complete"

    # Verify datadir size
    kurtosis service exec "$ENCLAVE_NAME" "$service_name" "du -sh /home/erigon/data/dynamic-Attractor-sequencer || true"

    # Restart the container via Docker to relaunch erigon
    echo "Restarting container via Docker..."
    if $DOCKER_BIN restart "$CONTAINER_ID" >/dev/null 2>&1; then
        echo "✅ Container restarted ($CONTAINER_ID)"
    else
        echo "⚠️  Failed to restart container automatically; please run: docker restart $CONTAINER_ID"
    fi

    return 0
}

# Function to restore blockchain data for sequencer and rpc if their backups are present
restore_blockchain_data() {
    local backup_seq="$BACKUP_DIR/blockchain_data_backup_sequencer.tar.gz"
    local backup_rpc="$BACKUP_DIR/blockchain_data_backup_rpc.tar.gz"

    local restored_any=false

    if [ -f "$backup_seq" ]; then
        echo "Restoring sequencer from: $backup_seq"
        restore_erigon_service_datadir "cdk-erigon-sequencer-001" "$backup_seq" || return 1
        restored_any=true
    fi

    if [ -f "$backup_rpc" ]; then
        echo "Restoring rpc node from: $backup_rpc"
        restore_erigon_service_datadir "cdk-erigon-rpc-001" "$backup_rpc" || return 1
        restored_any=true
    fi

    return 0
}

# Restore each database
RESTORATION_SUCCESS=true

if [ -f "$BACKUP_DIR/prover_db_backup.sql" ]; then
    if ! restore_database "prover_db_backup.sql" "prover_db" "prover_user"; then
        RESTORATION_SUCCESS=false
    fi
fi

if [ -f "$BACKUP_DIR/aggregator_db_backup.sql" ]; then
    if ! restore_database "aggregator_db_backup.sql" "aggregator_db" "aggregator_user"; then
        RESTORATION_SUCCESS=false
    fi
fi

if [ -f "$BACKUP_DIR/bridge_db_backup.sql" ]; then
    if ! restore_database "bridge_db_backup.sql" "bridge_db" "bridge_user"; then
        RESTORATION_SUCCESS=false
    fi
fi

if [ -f "$BACKUP_DIR/dac_db_backup.sql" ]; then
    if ! restore_database "dac_db_backup.sql" "dac_db" "dac_user"; then
        RESTORATION_SUCCESS=false
    fi
fi

if [ -f "$BACKUP_DIR/pool_manager_db_backup.sql" ]; then
    if ! restore_database "pool_manager_db_backup.sql" "pool_manager_db" "pool_manager_user"; then
        RESTORATION_SUCCESS=false
    fi
fi

# Restore blockchain data after databases
echo ""
echo "=== RESTORING BLOCKCHAIN DATA ==="
if ! restore_blockchain_data; then
    echo "⚠️  Blockchain data restoration failed, but continuing..."
    # Don't fail the entire script if blockchain restoration fails
fi

echo ""
echo "=== RESTORATION COMPLETED ==="

if [ "$RESTORATION_SUCCESS" = true ]; then
    echo "✅ All databases restored successfully!"
    echo ""
    echo "Next steps:"
    echo "1. Start your services that were rebuilt:"
    echo "   kurtosis service start $ENCLAVE_NAME <service_name>"
    echo ""
    echo "2. Verify data integrity:"
    echo "   kurtosis service logs $ENCLAVE_NAME <service_name>"
    echo ""
    echo "3. Run sanity checks:"
    echo "   ./scripts/sanity-check.sh"
else
    echo "❌ Some databases failed to restore!"
    echo "Please check the logs above and try again."
    exit 1
fi

echo ""
echo "=== VERIFICATION ==="
echo "Checking database connectivity..."

# Test database connections
for db_file in "${BACKUP_FILES[@]}"; do
    case $db_file in
        "prover_db_backup.sql")
            echo "Testing prover_db connection..."
            if kurtosis service exec "$ENCLAVE_NAME" "$POSTGRES_SERVICE" "PGPASSWORD=master_password psql -U prover_user -d prover_db -c 'SELECT 1;'" >/dev/null 2>&1; then
                echo "✅ prover_db is accessible"
            else
                echo "❌ prover_db is not accessible"
            fi
            ;;
        "aggregator_db_backup.sql")
            echo "Testing aggregator_db connection..."
            if kurtosis service exec "$ENCLAVE_NAME" "$POSTGRES_SERVICE" "PGPASSWORD=master_password psql -U aggregator_user -d aggregator_db -c 'SELECT 1;'" >/dev/null 2>&1; then
                echo "✅ aggregator_db is accessible"
            else
                echo "❌ aggregator_db is not accessible"
            fi
            ;;
        "bridge_db_backup.sql")
            echo "Testing bridge_db connection..."
            if kurtosis service exec "$ENCLAVE_NAME" "$POSTGRES_SERVICE" "PGPASSWORD=master_password psql -U bridge_user -d bridge_db -c 'SELECT 1;'" >/dev/null 2>&1; then
                echo "✅ bridge_db is accessible"
            else
                echo "❌ bridge_db is not accessible"
            fi
            ;;
        "dac_db_backup.sql")
            echo "Testing dac_db connection..."
            if kurtosis service exec "$ENCLAVE_NAME" "$POSTGRES_SERVICE" "PGPASSWORD=master_password psql -U dac_user -d dac_db -c 'SELECT 1;'" >/dev/null 2>&1; then
                echo "✅ dac_db is accessible"
            else
                echo "❌ dac_db is not accessible"
            fi
            ;;
        "pool_manager_db_backup.sql")
            echo "Testing pool_manager_db connection..."
            if kurtosis service exec "$ENCLAVE_NAME" "$POSTGRES_SERVICE" "PGPASSWORD=master_password psql -U pool_manager_user -d pool_manager_db -c 'SELECT 1;'" >/dev/null 2>&1; then
                echo "✅ pool_manager_db is accessible"
            else
                echo "❌ pool_manager_db is not accessible"
            fi
            ;;
    esac
done

echo ""
echo "Data restoration completed successfully!"
echo "Backup directory: $BACKUP_DIR"
echo "You can now safely delete the backup directory if everything is working correctly."
