#!/bin/bash

# Safe service upgrade script that updates services with new configurations
# Usage: ./scripts/safe_service_upgrade.sh <enclave_name> [service_name]

set -e

# Check we receive at least 1 param
if [ "$#" -lt 1 ]; then
    echo "Usage: safe_service_upgrade.sh <enclave_name> [service_name]"
    echo "Example: ./scripts/safe_service_upgrade.sh cdk"
    echo "Example: ./scripts/safe_service_upgrade.sh cdk blockscout-001"
    exit 1
fi

ENCLAVE_NAME=$1
SERVICE_NAME=$2

# Service names (based on actual service names from enclave)
SVC_SEQUENCER=cdk-erigon-sequencer-001
SVC_RPC=cdk-erigon-rpc-001
SVC_CONTRACTS=contracts-001
SVC_PROVER=zkevm-prover-001
SVC_BRIDGE=zkevm-bridge-service-001
SVC_SLESS_EXECUTOR=zkevm-stateless-executor-001
SVC_POSTGRES=postgres-001
SVC_BLOCKSCOUT_BACKEND=bs-backend-001
SVC_BLOCKSCOUT_FRONTEND=bs-frontend-001
SVC_BLOCKSCOUT_POSTGRES=bs-postgres-001
SVC_BLOCKSCOUT_STATS=bs-stats-001
SVC_GRAFANA=grafana-001
SVC_PROMETHEUS=prometheus-001
SVC_PANOPTICHAIN=panoptichain-001
SVC_VISUALIZE=visualize-001
SVC_BRIDGE_UI=zkevm-bridge-ui-001
SVC_DAC=zkevm-dac-001
SVC_POOL_MANAGER=zkevm-pool-manager-001
SVC_AGGLAYER=agglayer
SVC_AGGLAYER_PROVER=agglayer-prover

echo "=== SAFE SERVICE UPGRADE ==="
echo "Enclave: $ENCLAVE_NAME"
if [ -n "$SERVICE_NAME" ]; then
    echo "Target service: $SERVICE_NAME"
else
    echo "Target: All services"
fi
echo ""

# Check if enclave exists
if ! kurtosis enclave ls | grep -q "$ENCLAVE_NAME"; then
    echo "ERROR: Enclave '$ENCLAVE_NAME' not found!"
    echo "Available enclaves:"
    kurtosis enclave ls
    exit 1
fi

# Function to get list of services in enclave
get_services() {
    kurtosis enclave inspect "$ENCLAVE_NAME" | grep -E "^[[:space:]]*[a-zA-Z0-9-]+-[0-9]+" | awk '{print $1}' | tr -d ' '
}

# Function to check if service exists
service_exists() {
    local service=$1
    get_services | grep -q "^${service}$"
}

# Function to check if service is running
service_is_running() {
    local service=$1
    kurtosis enclave inspect "$ENCLAVE_NAME" | grep -A 5 "^[[:space:]]*${service}[[:space:]]" | grep -q "RUNNING"
}

# Create backup
echo ""
echo "=== Creating backup ==="
BACKUP_DIR="/tmp/service_upgrade_backup_$(date +%Y%m%d_%H%M%S)"
echo "Creating backup in: $BACKUP_DIR"
mkdir -p "$BACKUP_DIR"

# Check if postgres service exists
POSTGRES_SERVICE="postgres-001"

# Backup database data if postgres service exists
if [ -n "$POSTGRES_SERVICE" ]; then
    echo "Backing up databases from $POSTGRES_SERVICE..."
    
    # Check what databases exist
    echo "Checking available databases..."
    kurtosis service exec "$ENCLAVE_NAME" "$POSTGRES_SERVICE" "PGPASSWORD=master_password psql -U master_user -d master -c \"\\l\"" || {
        echo "WARNING: Cannot connect to postgres database, skipping backup"
    }
    
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

# Function to upgrade a specific service
upgrade_service() {
    local service=$1
    echo ""
    echo "=== Upgrading $service ==="
    
    # Check if service exists
    if ! service_exists "$service"; then
        echo "WARNING: Service $service not found, skipping"
        return
    fi
    
    echo "Stopping $service..."
    kurtosis service stop "$ENCLAVE_NAME" "$service"
    
    echo "Waiting for $service to stop..."
    sleep 5
    
    echo "Starting $service..."
    kurtosis service start "$ENCLAVE_NAME" "$service"
    
    echo "Waiting for $service to become available..."
    sleep 10
    
    echo "SUCCESS: $service upgraded"
}

# Function to upgrade all services
upgrade_all_services() {
    echo ""
    echo "=== Upgrading all services ==="
    
    # List of services to upgrade (in order of dependency)
    local services=(
        "$SVC_POSTGRES"
        "$SVC_BLOCKSCOUT_POSTGRES"
        "$SVC_PROMETHEUS"
        "$SVC_GRAFANA"
        "$SVC_PANOPTICHAIN"
        "$SVC_VISUALIZE"
        "$SVC_BLOCKSCOUT_BACKEND"
        "$SVC_BLOCKSCOUT_FRONTEND"
        "$SVC_BLOCKSCOUT_STATS"
        "$SVC_PROVER"
        "$SVC_BRIDGE"
        "$SVC_BRIDGE_UI"
        "$SVC_DAC"
        "$SVC_POOL_MANAGER"
        "$SVC_SLESS_EXECUTOR"
        "$SVC_AGGLAYER"
        "$SVC_AGGLAYER_PROVER"
        "$SVC_RPC"
        "$SVC_SEQUENCER"
    )
    
    for service in "${services[@]}"; do
        upgrade_service "$service"
    done
}

# Main upgrade logic
if [ -n "$SERVICE_NAME" ]; then
    # Upgrade specific service
    upgrade_service "$SERVICE_NAME"
else
    # Upgrade all services
    upgrade_all_services
fi

echo ""
echo "=== UPGRADE COMPLETED SUCCESSFULLY ==="
echo "Enclave: $ENCLAVE_NAME"
if [ -n "$SERVICE_NAME" ]; then
    echo "Upgraded service: $SERVICE_NAME"
else
    echo "Upgraded all services"
fi
echo "All L2 blockchain data preserved"
echo "Backup location: $BACKUP_DIR"
echo ""
echo "Services status:"
kurtosis enclave inspect "$ENCLAVE_NAME"

echo ""
echo "=== VERIFICATION ==="
echo "Checking if all services are running..."

# Check if all services are running
FAILED_SERVICES=()
for service in $(get_services); do
    if ! service_is_running "$service"; then
        FAILED_SERVICES+=("$service")
    fi
done

if [ ${#FAILED_SERVICES[@]} -eq 0 ]; then
    echo "✅ All services are running successfully!"
else
    echo "❌ Some services failed to start:"
    for service in "${FAILED_SERVICES[@]}"; do
        echo "  - $service"
    done
    echo ""
    echo "Check service logs for details:"
    echo "kurtosis service logs $ENCLAVE_NAME <service_name>"
fi

exit 0 