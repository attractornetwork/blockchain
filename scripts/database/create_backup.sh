#!/bin/bash

# Create backup of all service databases of L2 Attractor
# Usage: ./scripts/create_backup.sh <enclave_name> [backup_directory]

set -e

# Check we receive at least 1 param
if [ "$#" -lt 1 ]; then
    echo "Usage: create_backup.sh <enclave_name> [backup_directory]"
    echo "Example: ./scripts/create_backup.sh cdk"
    echo "Example: ./scripts/create_backup.sh cdk /path/to/backup/dir"
    echo ""
    echo "This script creates backup of all databases in the enclave."
    echo "If backup directory is not specified, it will use /tmp/backup_YYYYMMDD_HHMMSS"
    exit 1
fi

ENCLAVE_NAME=$1
BACKUP_DIR=${2:-"/tmp/backup_$(date +%Y%m%d_%H%M%S)"}

echo "=== CREATING SERVICE BACKUP ==="
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

# Prepare backup directory (clean if exists, else create)
echo "Preparing backup directory: $BACKUP_DIR"
if [ -d "$BACKUP_DIR" ]; then
    echo "Cleaning existing backup directory contents..."
    # Safety checks to avoid catastrophic deletion
    if [ -z "$BACKUP_DIR" ] || [ "$BACKUP_DIR" = "/" ]; then
        echo "ERROR: Refusing to clean unsafe backup directory path: '$BACKUP_DIR'"
        exit 1
    fi
    # Remove all contents inside the directory without deleting the directory itself
    find "$BACKUP_DIR" -mindepth 1 -maxdepth 1 -exec rm -rf -- {} +
else
    echo "Creating backup directory..."
    mkdir -p "$BACKUP_DIR"
fi

# Check if postgres service exists for backup
POSTGRES_SERVICE="postgres-001"
if ! service_exists "$POSTGRES_SERVICE"; then
    echo "ERROR: Postgres service '$POSTGRES_SERVICE' not found in enclave '$ENCLAVE_NAME'!"
    echo "Available services:"
    kurtosis enclave inspect "$ENCLAVE_NAME" | grep -E "^[[:space:]]*[a-zA-Z0-9-]+(-[0-9]+)?[[:space:]]" | awk '{print $2}' | grep -v "^$"
    exit 1
fi

echo "✅ Postgres service found"

# Show current enclave status
echo ""
echo "=== Current enclave status ==="
kurtosis enclave inspect "$ENCLAVE_NAME"

echo ""
echo "=== CREATING DATABASE BACKUPS ==="

# List of databases to backup with their users
declare -A DATABASES=(
    ["prover_db"]="prover_user"
    ["aggregator_db"]="aggregator_user"
    ["bridge_db"]="bridge_user"
    ["event_db"]="event_user"
    ["pool_db"]="pool_user"
    ["state_db"]="state_user"
    ["dac_db"]="dac_user"
    ["pool_manager_db"]="pool_manager_user"
)

BACKUP_SUCCESS=true
BACKUP_COUNT=0

for db_name in "${!DATABASES[@]}"; do
    db_user="${DATABASES[$db_name]}"
    backup_file="${db_name}_backup.sql"

    echo "Backing up $db_name database..."

    # Try to backup the database
    if kurtosis service exec "$ENCLAVE_NAME" "$POSTGRES_SERVICE" "PGPASSWORD=master_password pg_dump -U $db_user -d $db_name > /tmp/$backup_file" 2>/dev/null; then
        echo "✅ Successfully backed up $db_name"

        # Check if the backup file was created and has content
        file_size=$(kurtosis service exec "$ENCLAVE_NAME" "$POSTGRES_SERVICE" "ls -lh /tmp/$backup_file 2>/dev/null | awk '{print \$5}' || echo '0'")
        if [ "$file_size" != "0" ] && [ "$file_size" != "" ]; then
            echo "✅ Backup file size: $file_size"
        else
            echo "⚠️  Backup file appears to be empty or missing"
        fi

        # Download the backup file via base64 stream into the specified backup directory
        echo "Downloading $backup_file from container via base64..."
        if kurtosis service exec "$ENCLAVE_NAME" "$POSTGRES_SERVICE" "base64 /tmp/$backup_file" > "$BACKUP_DIR/$backup_file.b64"; then
            if base64 -d "$BACKUP_DIR/$backup_file.b64" > "$BACKUP_DIR/$backup_file"; then
                rm -f "$BACKUP_DIR/$backup_file.b64"
                file_size=$(du -h "$BACKUP_DIR/$backup_file" | cut -f1)
                echo "✅ Downloaded $backup_file to $BACKUP_DIR ($file_size)"
                BACKUP_COUNT=$((BACKUP_COUNT + 1))
            else
                echo "❌ Failed to decode $backup_file from base64"
                BACKUP_SUCCESS=false
            fi
        else
            echo "❌ Failed to transfer $backup_file via base64"
            BACKUP_SUCCESS=false
        fi

        # Clean up the file from container
        kurtosis service exec "$ENCLAVE_NAME" "$POSTGRES_SERVICE" "rm -f /tmp/$backup_file"
    else
        echo "⚠️  Could not backup $db_name database (database might not exist or be empty)"
    fi
done

echo ""
echo "=== BACKING UP BLOCKCHAIN DATA (ERIGON) ==="

# Общая функция бэкапа датадира Erigon с остановкой сервиса
backup_erigon_datadir() {
    local service_name="$1"
    local out_file_name="$2"

    if ! service_exists "$service_name"; then
        echo "No service '$service_name' found, skipping"
        return 0
    fi

    echo "Preparing to backup blockchain data from $service_name..."

    if service_is_running "$service_name"; then
        # Online archive without stopping the service
        if kurtosis service exec "$ENCLAVE_NAME" "$service_name" "tar -czf /tmp/${out_file_name}.tar.gz -C /home/erigon/data dynamic-Attractor-sequencer"; then
            echo "✅ Blockchain data archive created for $service_name"
            kurtosis service exec "$ENCLAVE_NAME" "$service_name" "ls -lh /tmp/${out_file_name}.tar.gz"

            # Download archive via base64 stream into the specified backup directory
            echo "Downloading archive via base64 transfer..."
            if kurtosis service exec "$ENCLAVE_NAME" "$service_name" "base64 /tmp/${out_file_name}.tar.gz" > "$BACKUP_DIR/${out_file_name}.tar.gz.b64"; then
                if base64 -d "$BACKUP_DIR/${out_file_name}.tar.gz.b64" > "$BACKUP_DIR/${out_file_name}.tar.gz"; then
                    rm -f "$BACKUP_DIR/${out_file_name}.tar.gz.b64"
                    echo "✅ Archive saved: $BACKUP_DIR/${out_file_name}.tar.gz"
                else
                    echo "❌ Failed to decode archive: $BACKUP_DIR/${out_file_name}.tar.gz.b64"
                fi
                # Clean up the file from container
                kurtosis service exec "$ENCLAVE_NAME" "$service_name" "rm -f /tmp/${out_file_name}.tar.gz" || true
            else
                echo "❌ Failed to transfer archive via base64 for ${out_file_name}.tar.gz"
            fi
        else
            echo "❌ Failed to create $out_file_name archive in container"
        fi
    else
        echo "Service $service_name is not running; attempting offline copy via docker cp..."
        # Try to locate container (stopped) and copy data out
        CONTAINER_ID=$(sudo docker ps -a | grep -F "${service_name}--" | awk '{print $1}' | head -n1)
        if [ -z "$CONTAINER_ID" ]; then
            echo "❌ Could not find container ID for $service_name; skipping blockchain backup"
            return 0
        fi
        TMP_DIR=$(mktemp -d)
        echo "Copying datadir from container $CONTAINER_ID..."
        if sudo docker cp "$CONTAINER_ID:/home/erigon/data/dynamic-Attractor-sequencer" "$TMP_DIR/"; then
            echo "Creating archive..."
            tar -czf "$BACKUP_DIR/${out_file_name}.tar.gz" -C "$TMP_DIR" dynamic-Attractor-sequencer && echo "✅ Archive saved: $BACKUP_DIR/${out_file_name}.tar.gz"
        else
            echo "❌ Failed to copy datadir from container"
        fi
        rm -rf "$TMP_DIR"
    fi
}

# Бэкап sequencer
ERIGON_SEQUENCER="cdk-erigon-sequencer-001"
backup_erigon_datadir "$ERIGON_SEQUENCER" "blockchain_data_backup_sequencer"

# Бэкап rpc-ноды (ускоряет восстановление и проверку транзакций)
ERIGON_RPC="cdk-erigon-rpc-001"
backup_erigon_datadir "$ERIGON_RPC" "blockchain_data_backup_rpc"

echo ""
echo "=== BACKUP SUMMARY ==="
echo "Backup directory: $BACKUP_DIR"
echo "Successfully backed up: $BACKUP_COUNT database(s)"

if [ "$BACKUP_SUCCESS" = true ] && [ $BACKUP_COUNT -gt 0 ]; then
    echo "✅ Backup completed successfully!"

    echo ""
    echo "=== BACKUP CONTENTS ==="
    ls -la "$BACKUP_DIR"

    echo ""
    echo "=== BACKUP VERIFICATION ==="
    echo "You can verify the backup by checking file sizes:"
    for file in "$BACKUP_DIR"/*.sql; do
        if [ -f "$file" ]; then
            size=$(du -h "$file" | cut -f1)
            echo "  $(basename "$file"): $size"
        fi
    done

    echo ""
    echo "=== USAGE EXAMPLES ==="
    echo "To restore from this backup:"
    echo "  ./scripts/restore_service_data.sh $ENCLAVE_NAME $BACKUP_DIR"
    echo ""
    echo "To use this backup for safe service update:"
    echo "  ./scripts/update_service_safely.sh $ENCLAVE_NAME <service_name>"
    echo ""
    echo "To manually restore a specific database:"
    echo "  kurtosis service files upload $ENCLAVE_NAME postgres-001 $BACKUP_DIR/<db_name>_backup.sql /tmp/"
    echo "  kurtosis service exec $ENCLAVE_NAME postgres-001 'PGPASSWORD=master_password psql -U <user> -d <db_name> < /tmp/<db_name>_backup.sql'"

    # Create a metadata file with backup information
    cat > "$BACKUP_DIR/backup_info.txt" << EOF
Backup Information
==================
Created: $(date)
Enclave: $ENCLAVE_NAME
Backup directory: $BACKUP_DIR
Databases backed up: $BACKUP_COUNT

Available databases:
EOF

    # Add available databases to the metadata file
    for file in "$BACKUP_DIR"/*.sql; do
        if [ -f "$file" ]; then
            echo "  - $(basename "$file")" >> "$BACKUP_DIR/backup_info.txt"
        fi
    done

    if [ -f "$BACKUP_DIR/blockchain_data_backup_sequencer.tar.gz" ]; then
        echo "  - blockchain_data_backup_sequencer.tar.gz" >> "$BACKUP_DIR/backup_info.txt"
    fi
    if [ -f "$BACKUP_DIR/blockchain_data_backup_rpc.tar.gz" ]; then
        echo "  - blockchain_data_backup_rpc.tar.gz" >> "$BACKUP_DIR/backup_info.txt"
    fi

    cat >> "$BACKUP_DIR/backup_info.txt" << EOF

Restore commands:
- Full restore: ./scripts/restore_service_data.sh $ENCLAVE_NAME $BACKUP_DIR
- Safe update: ./scripts/update_service_safely.sh $ENCLAVE_NAME <service_name>

Note: Keep this backup directory until you verify that the restored services are working correctly.
EOF

    echo ""
    echo "📄 Backup metadata saved to: $BACKUP_DIR/backup_info.txt"

else
    echo "❌ Backup failed or no databases were backed up!"
    echo "Please check the logs above for errors."
    exit 1
fi

echo ""
echo "Backup completed successfully!"
echo "Backup location: $BACKUP_DIR"
