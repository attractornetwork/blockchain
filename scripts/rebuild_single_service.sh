#!/bin/bash

# Safe single service rebuild script
# Usage: ./scripts/rebuild_single_service.sh <enclave_name> <service_name>

set -e

# Check we receive 2 params
if [ "$#" -ne 2 ]; then
    echo "Usage: rebuild_single_service.sh <enclave_name> <service_name>"
    echo "Example: ./scripts/rebuild_single_service.sh cdk grafana-001"
    echo "Example: ./scripts/rebuild_single_service.sh cdk bs-backend-001"
    exit 1
fi

ENCLAVE_NAME=$1
SERVICE_NAME=$2

echo "=== SAFE SINGLE SERVICE REBUILD ==="
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
echo "⚠️  WARNING: This will rebuild ONLY the service '$SERVICE_NAME'!"
echo "The service will be removed and re-added with new configurations."
echo "All other services will remain unchanged."
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

# Create a temporary Starlark file for rebuilding the specific service
echo "Creating temporary Starlark file for $SERVICE_NAME..."

# Create temporary directory
TEMP_DIR="/tmp/kurtosis_rebuild_$(date +%s)"
mkdir -p "$TEMP_DIR"

# Copy the main kurtosis.yml file
cp kurtosis.yml "$TEMP_DIR/"

# Create temporary main.star file
cat > "$TEMP_DIR/main.star" << 'EOF'
def run(plan, args):
    # Import the specific service module based on service name
    service_name = args.get("service_to_rebuild", "")
    
    if service_name == "grafana-001":
        import_module("./src/additional_services/grafana.star").run(plan, args)
    elif service_name == "bs-backend-001" or service_name == "bs-frontend-001" or service_name == "bs-stats-001":
        import_module("./src/additional_services/blockscout.star").run(plan, args)
    elif service_name == "prometheus-001":
        import_module("./src/additional_services/prometheus.star").run(plan, args)
    elif service_name == "panoptichain-001":
        import_module("./src/additional_services/panoptichain.star").run(plan, args)
    else:
        print("Unknown service:", service_name)
        return
EOF

# Create temporary params file with only the service to rebuild
cat > "$TEMP_DIR/rebuild_params.yml" << EOF
args:
  service_to_rebuild: "$SERVICE_NAME"
  deployment_suffix: "-001"
  verbosity: "info"
  global_log_level: "info"
  sequencer_type: "erigon"
  consensus_contract_type: "cdk-validium"
  additional_services: []
EOF

# Copy necessary files to temp directory
echo "Copying necessary files..."
cp -r src "$TEMP_DIR/"
cp -r static_files "$TEMP_DIR/"
cp -r templates "$TEMP_DIR/"
cp -r lib "$TEMP_DIR/"

# Change to temp directory and run kurtosis
echo "Running kurtosis to rebuild $SERVICE_NAME..."
cd "$TEMP_DIR"
kurtosis run --enclave "$ENCLAVE_NAME" --args-file rebuild_params.yml --image-download always .

# Clean up
cd - > /dev/null
rm -rf "$TEMP_DIR"

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