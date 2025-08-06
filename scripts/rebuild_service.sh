#!/bin/bash

# Rebuild service script that removes and re-adds a service with new configurations
# Usage: ./scripts/rebuild_service.sh <enclave_name> <service_name>

set -e

# Check we receive 2 params
if [ "$#" -ne 2 ]; then
    echo "Usage: rebuild_service.sh <enclave_name> <service_name>"
    echo "Example: ./scripts/rebuild_service.sh cdk grafana-001"
    echo "Example: ./scripts/rebuild_service.sh cdk bs-backend-001"
    exit 1
fi

ENCLAVE_NAME=$1
SERVICE_NAME=$2

echo "=== REBUILD SERVICE ==="
echo "Enclave: $ENCLAVE_NAME"
echo "Service: $SERVICE_NAME"
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

# Check if service exists
if ! service_exists "$SERVICE_NAME"; then
    echo "ERROR: Service '$SERVICE_NAME' not found in enclave '$ENCLAVE_NAME'!"
    echo "Available services:"
    kurtosis enclave inspect "$ENCLAVE_NAME" | grep -E "^[[:space:]]*[a-zA-Z0-9-]+(-[0-9]+)?[[:space:]]" | awk '{print $2}' | grep -v "^$"
    exit 1
fi

# Create backup
echo ""
echo "=== Creating backup ==="
BACKUP_DIR="/tmp/rebuild_backup_$(date +%Y%m%d_%H%M%S)"
echo "Creating backup in: $BACKUP_DIR"
mkdir -p "$BACKUP_DIR"

# Check if postgres service exists for backup
POSTGRES_SERVICE="postgres-001"
if service_exists "$POSTGRES_SERVICE"; then
    echo "Backing up databases from $POSTGRES_SERVICE..."
    
    # Backup databases with correct users
    echo "Backing up prover_db database..."
    if kurtosis service exec "$ENCLAVE_NAME" "$POSTGRES_SERVICE" "PGPASSWORD=master_password pg_dump -U prover_user -d prover_db > /tmp/prover_db_backup.sql" 2>/dev/null; then
        echo "Successfully backed up prover_db"
        kurtosis service files download "$ENCLAVE_NAME" "$POSTGRES_SERVICE" /tmp/prover_db_backup.sql "$BACKUP_DIR/"
    else
        echo "WARNING: Could not backup prover_db database"
    fi
    
    echo "Backing up aggregator_db database..."
    if kurtosis service exec "$ENCLAVE_NAME" "$POSTGRES_SERVICE" "PGPASSWORD=master_password pg_dump -U aggregator_user -d aggregator_db > /tmp/aggregator_db_backup.sql" 2>/dev/null; then
        echo "Successfully backed up aggregator_db"
        kurtosis service files download "$ENCLAVE_NAME" "$POSTGRES_SERVICE" /tmp/aggregator_db_backup.sql "$BACKUP_DIR/"
    else
        echo "WARNING: Could not backup aggregator_db database"
    fi
    
    echo "Backing up bridge_db database..."
    if kurtosis service exec "$ENCLAVE_NAME" "$POSTGRES_SERVICE" "PGPASSWORD=master_password pg_dump -U bridge_user -d bridge_db > /tmp/bridge_db_backup.sql" 2>/dev/null; then
        echo "Successfully backed up bridge_db"
        kurtosis service files download "$ENCLAVE_NAME" "$POSTGRES_SERVICE" /tmp/bridge_db_backup.sql "$BACKUP_DIR/"
    else
        echo "WARNING: Could not backup bridge_db database"
    fi
else
    echo "No postgres service found, skipping database backup"
fi

echo "Backup completed: $BACKUP_DIR"

# Show current service status
echo ""
echo "=== Current service status ==="
kurtosis enclave inspect "$ENCLAVE_NAME" | grep -A 5 "[[:space:]]${SERVICE_NAME}[[:space:]]"

# Confirmation prompt
echo ""
echo "⚠️  WARNING: This will remove and re-add the service '$SERVICE_NAME'!"
echo "The service will be rebuilt with new configurations from the current files."
echo "All L2 blockchain data will be preserved."
echo ""
read -p "Are you sure you want to rebuild $SERVICE_NAME? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Rebuild cancelled."
    exit 0
fi

echo ""
echo "=== Rebuilding $SERVICE_NAME ==="

# Stop the service first
echo "Stopping $SERVICE_NAME..."
kurtosis service stop "$ENCLAVE_NAME" "$SERVICE_NAME"

echo "Waiting for $SERVICE_NAME to stop..."
sleep 5

# Remove the service
echo "Removing $SERVICE_NAME..."
kurtosis service rm "$ENCLAVE_NAME" "$SERVICE_NAME"

echo "Waiting for service removal..."
sleep 3

# Re-add the service using the main Kurtosis run command
echo "Re-adding $SERVICE_NAME with new configurations..."
echo "This will rebuild the service with current configuration files..."

# Get the current working directory to run kurtosis from
CURRENT_DIR=$(pwd)

# Run kurtosis to re-add the service
# Note: This will use the current configuration files
echo "Running kurtosis to rebuild $SERVICE_NAME..."
kurtosis run --enclave "$ENCLAVE_NAME" --args-file params.yml --image-download always .

echo ""
echo "=== REBUILD COMPLETED ==="
echo "Service: $SERVICE_NAME"
echo "Enclave: $ENCLAVE_NAME"
echo "Backup location: $BACKUP_DIR"
echo ""
echo "Services status:"
kurtosis enclave inspect "$ENCLAVE_NAME"

echo ""
echo "=== VERIFICATION ==="
echo "Checking if $SERVICE_NAME is running..."

# Check if service is running
if service_exists "$SERVICE_NAME"; then
    if kurtosis enclave inspect "$ENCLAVE_NAME" | grep -A 2 "[[:space:]]${SERVICE_NAME}[[:space:]]" | grep -q "RUNNING"; then
        echo "✅ $SERVICE_NAME is running successfully!"
    else
        echo "❌ $SERVICE_NAME failed to start"
        echo "Check service logs:"
        echo "kurtosis service logs $ENCLAVE_NAME $SERVICE_NAME"
    fi
else
    echo "❌ $SERVICE_NAME was not re-added successfully"
fi

exit 0 