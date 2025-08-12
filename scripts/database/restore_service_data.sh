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

# Check if environment prefix exists by checking containers that start with it
# Example: for ENCLAVE_NAME="cdk" match names like "cdk-erigon-rpc-001--<uuid>"
if ! docker ps -a --format '{{.Names}}' | grep -q -E -- "^${ENCLAVE_NAME}-"; then
    echo "ERROR: Enclave '$ENCLAVE_NAME' not found!"
    echo "Available environments (by container prefixes):"
    docker ps -a --format '{{.Names}}' \
      | sed 's/--[a-f0-9]\{32\}$//' \
      | awk -F '-' '{print $1}' \
      | sort -u
    exit 1
fi

# Function to check if service exists using Docker
service_exists() {
    local service=$1
    local id
    id=$(get_container_id "$service")
    [ -n "$id" ]
}

# Function to check if service is running using Docker
service_is_running() {
    local service=$1
    local id
    id=$(get_container_id "$service")
    if [ -z "$id" ]; then
        return 1
    fi
    docker ps --format '{{.ID}}' | awk -v target="$id" '$0==target { found=1 } END{ exit found?0:1 }'
}

# Function to get container ID for a service
get_container_id() {
    local service=$1
    docker ps -a --format '{{.Names}}\t{{.ID}}' \
      | awk -v svc="$service" -F '\t' '
          $1==svc || $1 ~ ("^"svc"--[a-f0-9]{32}$") || \
          $1 ~ ("^"ENVIRON["ENCLAVE_NAME"]"-.*"svc"(--[a-f0-9]{32})?$") {print $2; exit}
        '
}

# Find actual service name (returns first match) given a short name
find_service_name() {
    local short=$1
    docker ps -a --format '{{.Names}}' \
      | grep -E -- "(^${ENCLAVE_NAME}-.*${short}(--[a-f0-9]{32})?$)|(^${short}(--[a-f0-9]{32})?$)" \
      | head -n1
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
POSTGRES_SERVICE=$(find_service_name "postgres-001")
if [ -z "$POSTGRES_SERVICE" ]; then
    echo "⚠️  Postgres service '$POSTGRES_SERVICE' not found in enclave '$ENCLAVE_NAME'"
    echo "    Skipping database backups and proceeding with blockchain data backup only."
    POSTGRES_SERVICE=""
else
    echo "✅ Postgres service found"
fi

# Show current enclave status
echo ""
echo "=== Current enclave status ==="
echo "Enclave: $ENCLAVE_NAME"
echo "Containers:"
docker ps -a --format '{{.Names}}\t{{.Status}}\t{{.Ports}}' | grep -E -- "^${ENCLAVE_NAME}-"

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
BC_BACKUP_SUCCESS=false

if [ -n "$POSTGRES_SERVICE" ]; then
for db_name in "${!DATABASES[@]}"; do
    db_user="${DATABASES[$db_name]}"
    backup_file="${db_name}_backup.sql"

    echo "Backing up $db_name database..."

    # Get container ID for postgres service
    container_id=$(get_container_id "$POSTGRES_SERVICE")
    if [ -z "$container_id" ]; then
        echo "❌ Could not find container for $POSTGRES_SERVICE"
        continue
    fi

    # Try to backup the database
    if docker exec "$container_id" bash -c "PGPASSWORD=master_password pg_dump -U $db_user -d $db_name > /tmp/$backup_file" 2>/dev/null; then
        echo "✅ Successfully backed up $db_name"

        # Check if the backup file was created and has content
        file_size=$(docker exec "$container_id" bash -lc "ls -lh /tmp/$backup_file 2>/dev/null | awk '{print \$5}' || echo '0'")
        if [ "$file_size" != "0" ] && [ "$file_size" != "" ]; then
            echo "✅ Backup file size: $file_size"
        else
            echo "⚠️  Backup file appears to be empty or missing"
        fi

        # Download the backup file via base64 stream into the specified backup directory
        echo "Downloading $backup_file from container via base64..."
        if docker exec "$container_id" bash -lc "base64 /tmp/$backup_file" > "$BACKUP_DIR/$backup_file.b64"; then
            if base64 -d "$BACKUP_DIR/$backup_file.b64" > "$BACKUP_DIR/$backup_file"; then
                rm -f "$BACKUP_DIR/$backup_file.b64"
                file_bytes=$(wc -c < "$BACKUP_DIR/$backup_file" | tr -d '[:space:]')
                echo "✅ Downloaded $backup_file to $BACKUP_DIR (${file_bytes} bytes)"
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
        docker exec "$container_id" bash -lc "rm -f /tmp/$backup_file"
    else
        echo "⚠️  Could not backup $db_name database (database might not exist or be empty)"
    fi
done
else
  echo "Skipping database backups because postgres service is not available."
fi

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

    # Get container ID for the service
    local container_id=$(get_container_id "$service_name")
    if [ -z "$container_id" ]; then
        echo "❌ Could not find container for $service_name"
        return 0
    fi

    if service_is_running "$service_name"; then
        # Online archive without stopping the service
        if docker exec "$container_id" sh -lc "tar -czf /tmp/${out_file_name}.tar.gz -C /home/erigon/data dynamic-Attractor-sequencer 2>/dev/null || tar -czf /tmp/${out_file_name}.tar.gz -C /home/erigon/data datadir 2>/dev/null"; then
            echo "✅ Blockchain data archive created for $service_name"
            docker exec "$container_id" sh -lc "ls -lh /tmp/${out_file_name}.tar.gz"

            # Download archive via base64 stream into the specified backup directory
            echo "Downloading archive via base64 transfer..."
            if docker exec "$container_id" sh -lc "base64 /tmp/${out_file_name}.tar.gz" > "$BACKUP_DIR/${out_file_name}.tar.gz.b64"; then
                if base64 -d "$BACKUP_DIR/${out_file_name}.tar.gz.b64" > "$BACKUP_DIR/${out_file_name}.tar.gz"; then
                    rm -f "$BACKUP_DIR/${out_file_name}.tar.gz.b64"
                    echo "✅ Archive saved: $BACKUP_DIR/${out_file_name}.tar.gz"
                    BC_BACKUP_SUCCESS=true
                else
                    echo "❌ Failed to decode archive: $BACKUP_DIR/${out_file_name}.tar.gz.b64"
                fi
                # Clean up the file from container
                docker exec "$container_id" sh -lc "rm -f /tmp/${out_file_name}.tar.gz" || true
            else
                echo "❌ Failed to transfer archive via base64 for ${out_file_name}.tar.gz"
            fi
        else
            echo "❌ Failed to create $out_file_name archive in container"
        fi
    else
        echo "Service $service_name is not running; attempting offline copy via docker cp..."
        # Try to locate container (stopped) and copy data out
        if [ -z "$container_id" ]; then
            echo "❌ Could not find container ID for $service_name; skipping blockchain backup"
            return 0
        fi
        TMP_DIR=$(mktemp -d)
        echo "Copying datadir from container $container_id..."
        if docker cp "$container_id:/home/erigon/data/dynamic-Attractor-sequencer" "$TMP_DIR/"; then
            echo "Creating archive..."
            tar -czf "$BACKUP_DIR/${out_file_name}.tar.gz" -C "$TMP_DIR" dynamic-Attractor-sequencer && echo "✅ Archive saved: $BACKUP_DIR/${out_file_name}.tar.gz" && BC_BACKUP_SUCCESS=true
        else
            echo "❌ Failed to copy datadir from container"
        fi
        rm -rf "$TMP_DIR"
    fi
}

# Бэкап sequencer
ERIGON_SEQUENCER="${ENCLAVE_NAME}-erigon-sequencer-001"
backup_erigon_datadir "$ERIGON_SEQUENCER" "blockchain_data_backup_sequencer"

# Бэкап rpc-ноды (ускоряет восстановление и проверку транзакций)
ERIGON_RPC="${ENCLAVE_NAME}-erigon-rpc-001"
backup_erigon_datadir "$ERIGON_RPC" "blockchain_data_backup_rpc"

echo ""
echo "=== BACKUP SUMMARY ==="
echo "Backup directory: $BACKUP_DIR"
echo "Successfully backed up: $BACKUP_COUNT database(s)"

if [ "$BACKUP_SUCCESS" = true ] && { [ $BACKUP_COUNT -gt 0 ] || [ "$BC_BACKUP_SUCCESS" = true ]; }; then
    echo "✅ Backup completed successfully!"

    echo ""
    echo "=== BACKUP CONTENTS ==="
    ls -la "$BACKUP_DIR"

    echo ""
    echo "=== BACKUP VERIFICATION ==="
    echo "You can verify the backup by checking file sizes:"
    for file in "$BACKUP_DIR"/*.sql; do
        if [ -f "$file" ]; then
            size_bytes=$(wc -c < "$file" | tr -d '[:space:]')
            echo "  $(basename "$file"): ${size_bytes} bytes"
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
    echo "  docker cp $BACKUP_DIR/<db_name>_backup.sql \$(docker ps -a --format 'table {{.ID}}\t{{.Names}}' | grep 'postgres-001--' | awk '{print \$1}' | head -n1):/tmp/"
    echo "  docker exec \$(docker ps -a --format 'table {{.ID}}\t{{.Names}}' | grep 'postgres-001--' | awk '{print \$1}' | head -n1) bash -c 'PGPASSWORD=master_password psql -U <user> -d <db_name> < /tmp/<db_name>_backup.sql'"

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
