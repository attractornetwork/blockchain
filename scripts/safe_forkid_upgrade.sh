#!/bin/bash

# Safe forkid upgrade script that preserves all L2 blockchain data
# Usage: ./scripts/safe_forkid_upgrade.sh <enclave_name> <source_forkid> <target_forkid>

set -e

# Check we receive 3 params
if [ "$#" -ne 3 ]; then
    echo "Usage: safe_forkid_upgrade.sh <enclave_name> <source_forkid> <target_forkid>"
    echo "Example: ./scripts/safe_forkid_upgrade.sh my-enclave 12 13"
    exit 1
elif ! [[ $2 =~ ^[0-9]+$ ]] || ! [[ $3 =~ ^[0-9]+$ ]]; then
    echo "Forkids must be integers"
    exit 1
elif [ "$2" -ge "$3" ]; then
    echo "Target forkid must be greater than source forkid"
    exit 1
fi

ENCLAVE_NAME=$1
SOURCE_FORKID=$2
TARGET_FORKID=$3

# Service names
SVC_SEQUENCER=cdk-erigon-sequencer-001
SVC_RPC=cdk-erigon-rpc-001
SVC_CONTRACTS=contracts-001
SVC_CDKNODE=cdk-node-001
SVC_PROVER=zkevm-prover-001
SVC_BRIDGE=zkevm-bridge-service-001
SVC_SLESS_EXECUTOR=zkevm-stateless-executor-001

# Determine target contract tag
if [ "$TARGET_FORKID" -eq "11" ]; then
    TAG_TARGET_FORKID=v7.0.0-fork.10-fork.11
elif [ "$TARGET_FORKID" -eq "12" ]; then
    TAG_TARGET_FORKID=v8.0.0-rc.4-fork.12
elif [ "$TARGET_FORKID" -eq "13" ]; then
    TAG_TARGET_FORKID=v8.1.0-rc.2-fork.13
else
    echo "Unsupported target forkid: $TARGET_FORKID"
    exit 1
fi

echo "=== SAFE FORKID UPGRADE ==="
echo "Enclave: $ENCLAVE_NAME"
echo "Upgrading from forkid $SOURCE_FORKID to $TARGET_FORKID"
echo "Target contract tag: $TAG_TARGET_FORKID"
echo ""

# Check if enclave exists
if ! kurtosis enclave ls | grep -q "$ENCLAVE_NAME"; then
    echo "ERROR: Enclave '$ENCLAVE_NAME' not found!"
    echo "Available enclaves:"
    kurtosis enclave ls
    exit 1
fi

# Check current forkid
echo "=== Checking current forkid ==="
CURRENT_FORKID=$(cast rpc --json --rpc-url $(kurtosis port print "$ENCLAVE_NAME" $SVC_RPC rpc) zkevm_getForkId | jq -r)
echo "Current forkid: $CURRENT_FORKID"
if [ "$CURRENT_FORKID" -ne "$SOURCE_FORKID" ]; then
    echo "WARNING: Current forkid ($CURRENT_FORKID) doesn't match expected source forkid ($SOURCE_FORKID)"
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Create backup
echo ""
echo "=== Creating backup ==="
BACKUP_DIR="/tmp/forkid_upgrade_backup_$(date +%Y%m%d_%H%M%S)"
echo "Creating backup in: $BACKUP_DIR"
mkdir -p "$BACKUP_DIR"

# Backup database data
echo "Backing up databases..."
kurtosis service exec "$ENCLAVE_NAME" postgres-001 "pg_dump -U postgres -d zkevm_node > /tmp/zkevm_node_backup.sql"
kurtosis service exec "$ENCLAVE_NAME" postgres-001 "pg_dump -U postgres -d zkevm_prover > /tmp/zkevm_prover_backup.sql"
kurtosis service exec "$ENCLAVE_NAME" postgres-001 "pg_dump -U postgres -d zkevm_aggregator > /tmp/zkevm_aggregator_backup.sql"

# Copy backups to host
kurtosis service files download "$ENCLAVE_NAME" postgres-001 /tmp/zkevm_node_backup.sql "$BACKUP_DIR/"
kurtosis service files download "$ENCLAVE_NAME" postgres-001 /tmp/zkevm_prover_backup.sql "$BACKUP_DIR/"
kurtosis service files download "$ENCLAVE_NAME" postgres-001 /tmp/zkevm_aggregator_backup.sql "$BACKUP_DIR/"

echo "Backup completed: $BACKUP_DIR"

# Halt sequencer
echo ""
echo "=== Halting sequencer ==="
echo "Stopping sequencer..."
kurtosis service stop "$ENCLAVE_NAME" $SVC_SEQUENCER

# Wait for sequencer to stop
echo "Waiting for sequencer to stop..."
sleep 10

# Update contracts
echo ""
echo "=== Updating contracts ==="
echo "Updating to contract tag: $TAG_TARGET_FORKID"
kurtosis service exec "$ENCLAVE_NAME" $SVC_CONTRACTS "cd /opt/zkevm-contracts && git stash && git checkout main && git pull && git checkout $TAG_TARGET_FORKID"

# Create environment script for contract operations
echo "Creating environment script..."
kurtosis service exec "$ENCLAVE_NAME" $SVC_CONTRACTS "echo 'cd /opt' > /opt/upgrade_commands.sh"
kurtosis service exec "$ENCLAVE_NAME" $SVC_CONTRACTS "echo 'export ETH_RPC_URL=http://el-1-geth-lighthouse:8545' >> /opt/upgrade_commands.sh"
kurtosis service exec "$ENCLAVE_NAME" $SVC_CONTRACTS "echo 'ROLLUP_MAN=\$(cat zkevm/combined.json  | jq -r .polygonRollupManagerAddress)' >> /opt/upgrade_commands.sh"
kurtosis service exec "$ENCLAVE_NAME" $SVC_CONTRACTS "echo 'ROLLUP=\$(cat zkevm/combined.json | jq -r .rollupAddress)' >> /opt/upgrade_commands.sh"
kurtosis service exec "$ENCLAVE_NAME" $SVC_CONTRACTS "echo 'GENESIS=\$(cat zkevm/combined.json  | jq -r .genesis)' >> /opt/upgrade_commands.sh"
kurtosis service exec "$ENCLAVE_NAME" $SVC_CONTRACTS "echo \"CONSENSUS=\\\$(cast call \\\$ROLLUP_MAN 'rollupTypeMap(uint32)(address,address,uint64,uint8,bool,bytes32)' 1 | head -1)\" >> /opt/upgrade_commands.sh"
kurtosis service exec "$ENCLAVE_NAME" $SVC_CONTRACTS "echo PRIV_KEY=0x12d7de8621a77640c9241b2595ba78ce443d05e94090365ab3bb5e19df82c625 >> /opt/upgrade_commands.sh"
kurtosis service exec "$ENCLAVE_NAME" $SVC_CONTRACTS "chmod +x /opt/upgrade_commands.sh"

# Deploy new verifier
echo ""
echo "=== Deploying new verifier ==="
kurtosis service exec "$ENCLAVE_NAME" $SVC_CONTRACTS \
    ". /opt/upgrade_commands.sh && \
    forge create \
    --broadcast \
    --json \
    --private-key \$PRIV_KEY \
    /opt/zkevm-contracts/contracts/mocks/VerifierRollupHelperMock.sol:VerifierRollupHelperMock > /opt/verifier-out.json"

# Add new rollup type
echo ""
echo "=== Adding new rollup type ==="
kurtosis service exec "$ENCLAVE_NAME" $SVC_CONTRACTS \
    ". /opt/upgrade_commands.sh && \
    cast send \
    --json \
    --private-key \$PRIV_KEY \
    \$ROLLUP_MAN \
    'addNewRollupType(address,address,uint64,uint8,bytes32,string)' \
    \$CONSENSUS \
    \"\$(jq -r '.deployedTo' /opt/verifier-out.json)\" \
    $TARGET_FORKID 0 \$GENESIS 'new_forkid_$TARGET_FORKID' > /opt/add-rollup-type-out.json"

# Update rollup
echo ""
echo "=== Updating rollup ==="
kurtosis service exec "$ENCLAVE_NAME" $SVC_CONTRACTS \
    ". /opt/upgrade_commands.sh && \
    cast send \
    --json \
    --private-key \$PRIV_KEY \
    \$ROLLUP_MAN \
    'updateRollup(address,uint32,bytes)' \
    \$ROLLUP \
    \$(printf \"%d\\n\" \$(jq -r '.logs[0].topics[1]' /opt/add-rollup-type-out.json)) \
    0x > /opt/update-rollup-type-out.json"

# Verify forkid on chain
echo ""
echo "=== Verifying forkid on chain ==="
FORKID_ON_CHAIN=$(kurtosis service exec "$ENCLAVE_NAME" $SVC_CONTRACTS ". /opt/upgrade_commands.sh && cast call \$ROLLUP_MAN \"rollupIDToRollupData(uint32)(address,uint64,address,uint64,bytes32,uint64,uint64,uint64,uint64,uint64,uint64,uint8)\" 1 | head -4 | tail -1" | tail -2 | head -1)
if [ "$FORKID_ON_CHAIN" -ne "$TARGET_FORKID" ]; then
    echo "ERROR: Forkid not updated on chain! Expected: $TARGET_FORKID, Got: $FORKID_ON_CHAIN"
    exit 1
else
    echo "OK: Forkid on chain: $FORKID_ON_CHAIN"
fi

# Update sequencer configuration
echo ""
echo "=== Updating sequencer configuration ==="
echo "Updating sequencer config to use new forkid..."
kurtosis service exec "$ENCLAVE_NAME" $SVC_SEQUENCER \
    "sed -i 's/fork_id: $SOURCE_FORKID/fork_id: $TARGET_FORKID/' /etc/cdk-erigon/config.yaml"

# Start sequencer
echo ""
echo "=== Starting sequencer ==="
echo "Starting sequencer with new forkid..."
kurtosis service start "$ENCLAVE_NAME" $SVC_SEQUENCER

# Wait for sequencer to become responsive
echo "Waiting for sequencer to become available..."
until cast rpc --json --rpc-url $(kurtosis port print "$ENCLAVE_NAME" "$SVC_SEQUENCER" rpc) zkevm_getForkId &>/dev/null; do
    printf '.'
    sleep 3
done
echo

# Check forkid on sequencer
echo ""
echo "=== Checking sequencer forkid ==="
FORKID=$SOURCE_FORKID
COUNTER=0
MAX_RETRIES=30
while [ "$FORKID" -ne "$TARGET_FORKID" ] && [ $COUNTER -lt $MAX_RETRIES ]; do
    ((COUNTER++))
    FORKID=$(printf "%d" $(cast rpc --json --rpc-url $(kurtosis port print "$ENCLAVE_NAME" "$SVC_SEQUENCER" rpc) zkevm_getForkId | jq -r))
    echo "Current sequencer forkid: $FORKID (attempt $COUNTER/$MAX_RETRIES)"
    if [ "$FORKID" -ne "$TARGET_FORKID" ]; then
        sleep 5
    fi
done

if [ "$FORKID" -eq "$TARGET_FORKID" ]; then
    echo "SUCCESS: Sequencer upgraded to forkid $TARGET_FORKID"
else
    echo "ERROR: Sequencer failed to upgrade to forkid $TARGET_FORKID"
    exit 1
fi

# Start RPC
echo ""
echo "=== Starting RPC ==="
kurtosis service start "$ENCLAVE_NAME" $SVC_RPC

# Wait for RPC to become responsive
echo "Waiting for RPC to become available..."
until cast rpc --json --rpc-url $(kurtosis port print "$ENCLAVE_NAME" "$SVC_RPC" rpc) zkevm_getForkId &>/dev/null; do
    printf '.'
    sleep 3
done
echo

# Check forkid on RPC
echo ""
echo "=== Checking RPC forkid ==="
FORKID=$SOURCE_FORKID
COUNTER=0
MAX_RETRIES=30
while [ "$FORKID" -ne "$TARGET_FORKID" ] && [ $COUNTER -lt $MAX_RETRIES ]; do
    ((COUNTER++))
    FORKID=$(printf "%d" $(cast rpc --json --rpc-url $(kurtosis port print "$ENCLAVE_NAME" "$SVC_RPC" rpc) zkevm_getForkId | jq -r))
    echo "Current RPC forkid: $FORKID (attempt $COUNTER/$MAX_RETRIES)"
    if [ "$FORKID" -ne "$TARGET_FORKID" ]; then
        sleep 5
    fi
done

if [ "$FORKID" -eq "$TARGET_FORKID" ]; then
    echo "SUCCESS: RPC upgraded to forkid $TARGET_FORKID"
else
    echo "ERROR: RPC failed to upgrade to forkid $TARGET_FORKID"
    exit 1
fi

# Start other services
echo ""
echo "=== Starting other services ==="
kurtosis service start "$ENCLAVE_NAME" $SVC_CDKNODE
kurtosis service start "$ENCLAVE_NAME" $SVC_PROVER
kurtosis service start "$ENCLAVE_NAME" $SVC_BRIDGE
kurtosis service start "$ENCLAVE_NAME" $SVC_SLESS_EXECUTOR

echo ""
echo "=== UPGRADE COMPLETED SUCCESSFULLY ==="
echo "Enclave: $ENCLAVE_NAME"
echo "Upgraded from forkid $SOURCE_FORKID to $TARGET_FORKID"
echo "All L2 blockchain data preserved"
echo "Backup location: $BACKUP_DIR"
echo ""
echo "Services status:"
kurtosis service ls "$ENCLAVE_NAME"

exit 0 