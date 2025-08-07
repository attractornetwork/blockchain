#!/bin/bash

# Full backup script for Polygon CDK environment
# Backs up PostgreSQL databases AND blockchain data from Erigon nodes
# Usage: ./scripts/database/create_full_backup.sh <enclave_name>

set -e

# Check we receive 1 param
if [ "$#" -ne 1 ]; then
    echo "Usage: create_full_backup.sh <enclave_name>"
    echo "Example: ./scripts/database/create_full_backup.sh cdk"
    exit 1
fi

ENCLAVE_NAME=$1

echo "=== FULL BACKUP SCRIPT ==="
echo "Enclave: $ENCLAVE_NAME"
echo ""

# Check if enclave exists
if ! kurtosis enclave ls | grep -q "$ENCLAVE_NAME"; then
    echo "ERROR: Enclave '$ENCLAVE_NAME' not found!"
    echo "Available enclaves:"
    kurtosis enclave ls
    exit 1
fi

# Create backup directory
BACKUP_DIR="scripts/database/backup_$(date +%Y%m%d_%H%M%S)"
echo "Creating backup directory: $BACKUP_DIR"
mkdir -p "$BACKUP_DIR"

# Function to check if service exists
service_exists() {
    local service=$1
    kurtosis enclave inspect "$ENCLAVE_NAME" | grep -q "[[:space:]]${service}[[:space:]]"
}

echo ""
echo "=== BACKING UP POSTGRESQL DATABASES ==="

# Check if postgres service exists for backup
POSTGRES_SERVICE="postgres-001"
if service_exists "$POSTGRES_SERVICE"; then
    echo "Backing up databases from $POSTGRES_SERVICE..."
    
    # List of databases to backup
    declare -A databases=(
        ["prover_db"]="prover_user"
        ["aggregator_db"]="aggregator_user"
        ["bridge_db"]="bridge_user"
        ["dac_db"]="dac_user"
        ["pool_manager_db"]="pool_manager_user"
        ["event_db"]="event_user"
        ["pool_db"]="pool_user"
        ["state_db"]="state_user"
    )
    
    for db_name in "${!databases[@]}"; do
        db_user="${databases[$db_name]}"
        echo "Backing up $db_name database..."
        
        # Create backup using pg_dump
        if kurtosis service exec "$ENCLAVE_NAME" "$POSTGRES_SERVICE" "PGPASSWORD=master_password pg_dump -U $db_user -d $db_name > /tmp/${db_name}_backup.sql" 2>/dev/null; then
            echo "Successfully created $db_name backup"
            
            # Download via base64
            echo "Downloading $db_name backup..."
            kurtosis service exec "$ENCLAVE_NAME" "$POSTGRES_SERVICE" "base64 /tmp/${db_name}_backup.sql" > "$BACKUP_DIR/${db_name}_backup.sql.b64"
            
            # Decode on host
            base64 -d "$BACKUP_DIR/${db_name}_backup.sql.b64" > "$BACKUP_DIR/${db_name}_backup.sql"
            rm "$BACKUP_DIR/${db_name}_backup.sql.b64"
            
            echo "✅ $db_name backup completed"
        else
            echo "❌ Could not backup $db_name database"
        fi
    done
else
    echo "No postgres service found, skipping database backup"
fi

echo ""
echo "=== BACKING UP BLOCKCHAIN DATA ==="

# Check if Erigon sequencer exists
ERIGON_SEQUENCER="cdk-erigon-sequencer-001"
if service_exists "$ERIGON_SEQUENCER"; then
    echo "Backing up blockchain data from $ERIGON_SEQUENCER..."
    
    # Create blockchain data backup
    echo "Creating blockchain data archive..."
    if kurtosis service exec "$ENCLAVE_NAME" "$ERIGON_SEQUENCER" "tar -czf /tmp/blockchain_data_backup.tar.gz -C /home/erigon/data dynamic-Attractor-sequencer"; then
        echo "Successfully created blockchain data backup"
        
        # Check size
        kurtosis service exec "$ENCLAVE_NAME" "$ERIGON_SEQUENCER" "ls -lh /tmp/blockchain_data_backup.tar.gz"
        
        # Download via base64
        echo "Downloading blockchain data backup..."
        kurtosis service exec "$ENCLAVE_NAME" "$ERIGON_SEQUENCER" "base64 /tmp/blockchain_data_backup.tar.gz" > "$BACKUP_DIR/blockchain_data_backup.tar.gz.b64"
        
        # Decode on host
        base64 -d "$BACKUP_DIR/blockchain_data_backup.tar.gz.b64" > "$BACKUP_DIR/blockchain_data_backup.tar.gz"
        rm "$BACKUP_DIR/blockchain_data_backup.tar.gz.b64"
        
        echo "✅ Blockchain data backup completed"
    else
        echo "❌ Could not create blockchain data backup"
    fi
else
    echo "No Erigon sequencer found, skipping blockchain data backup"
fi

# Check if Erigon RPC exists
ERIGON_RPC="cdk-erigon-rpc-001"
if service_exists "$ERIGON_RPC"; then
    echo "Backing up RPC node data from $ERIGON_RPC..."
    
    # Create RPC data backup
    echo "Creating RPC data archive..."
    if kurtosis service exec "$ENCLAVE_NAME" "$ERIGON_RPC" "tar -czf /tmp/rpc_data_backup.tar.gz -C /home/erigon/data dynamic-Attractor-sequencer"; then
        echo "Successfully created RPC data backup"
        
        # Check size
        kurtosis service exec "$ENCLAVE_NAME" "$ERIGON_RPC" "ls -lh /tmp/rpc_data_backup.tar.gz"
        
        # Download via base64
        echo "Downloading RPC data backup..."
        kurtosis service exec "$ENCLAVE_NAME" "$ERIGON_RPC" "base64 /tmp/rpc_data_backup.tar.gz" > "$BACKUP_DIR/rpc_data_backup.tar.gz.b64"
        
        # Decode on host
        base64 -d "$BACKUP_DIR/rpc_data_backup.tar.gz.b64" > "$BACKUP_DIR/rpc_data_backup.tar.gz"
        rm "$BACKUP_DIR/rpc_data_backup.tar.gz.b64"
        
        echo "✅ RPC data backup completed"
    else
        echo "❌ Could not create RPC data backup"
    fi
else
    echo "No Erigon RPC found, skipping RPC data backup"
fi

echo ""
echo "=== CREATING BACKUP INFO ==="

# Create backup info file
cat > "$BACKUP_DIR/backup_info.txt" << EOF
Full Backup Information
=======================

Backup created: $(date)
Enclave: $ENCLAVE_NAME
Backup directory: $BACKUP_DIR

PostgreSQL Databases:
$(ls -la "$BACKUP_DIR"/*.sql 2>/dev/null | awk '{print $5, $9}' || echo "No database backups found")

Blockchain Data:
$(ls -la "$BACKUP_DIR"/*.tar.gz 2>/dev/null | awk '{print $5, $9}' || echo "No blockchain data backups found")

Total backup size: $(du -sh "$BACKUP_DIR" | cut -f1)

Services backed up:
- PostgreSQL databases (if postgres-001 exists)
- Erigon sequencer blockchain data (if cdk-erigon-sequencer-001 exists)
- Erigon RPC node data (if cdk-erigon-rpc-001 exists)

To restore this backup, use: ./scripts/database/restore_full_backup.sh $ENCLAVE_NAME $BACKUP_DIR
EOF

echo "Backup info saved to: $BACKUP_DIR/backup_info.txt"

echo ""
echo "=== BACKUP COMPLETED ==="
echo "Backup location: $BACKUP_DIR"
echo "Contents:"
ls -lh "$BACKUP_DIR"

echo ""
echo "Total backup size: $(du -sh "$BACKUP_DIR" | cut -f1)"
echo ""
echo "✅ Full backup completed successfully!"
echo "To restore: ./scripts/database/restore_full_backup.sh $ENCLAVE_NAME $BACKUP_DIR" 