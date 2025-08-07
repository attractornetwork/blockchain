#!/bin/bash

# Create backup of all service databases
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

# Create backup directory
echo "Creating backup directory: $BACKUP_DIR"
mkdir -p "$BACKUP_DIR"

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
        
        # Download the backup file
        echo "Downloading $backup_file from container..."
        if kurtosis service files download "$ENCLAVE_NAME" "$POSTGRES_SERVICE" "/tmp/$backup_file" "$BACKUP_DIR/"; then
            echo "✅ Downloaded $backup_file to $BACKUP_DIR"
            # Verify the file was actually downloaded
            if [ -f "$BACKUP_DIR/$backup_file" ]; then
                file_size=$(du -h "$BACKUP_DIR/$backup_file" | cut -f1)
                echo "✅ File verified: $backup_file ($file_size)"
                BACKUP_COUNT=$((BACKUP_COUNT + 1))
            else
                echo "❌ File download failed - file not found in $BACKUP_DIR"
                BACKUP_SUCCESS=false
            fi
        else
            echo "❌ Failed to download $backup_file"
            BACKUP_SUCCESS=false
        fi
        
        # Clean up the file from container
        kurtosis service exec "$ENCLAVE_NAME" "$POSTGRES_SERVICE" "rm -f /tmp/$backup_file"
    else
        echo "⚠️  Could not backup $db_name database (database might not exist or be empty)"
    fi
done

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

exit 0 