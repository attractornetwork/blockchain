# Scripts

## upgrade_forkid.sh
The main purpose of this script is to test Erigon behavior when upgrading forkid, and it can be taken as example/guide of required steps to upgrade an existing network.
The script itself takes care of deploying the Kurtosis CDK stack, halt sequencer and check it's in a right status, upgrading contracts, starting sequencer again, check it process the new forkid, and then removing the whole stack.
You can not use it as is to upgrade your existing stack, but you can easily adapt it for your context.

### Usage
From the root of repo, run:
```bash
./scripts/upgrade_forkid.sh 11 13
```

This would deploy a forkid 11 stack and then upgrade it to forkid 13.

These are the tested/supported combinations so far:
- Upgrading from forkid 12 to 13
- Upgrading from forkid 11 to 12
- Upgrading from forkid 11 to 13
- Upgrading from forkid 9 to 11
- Upgrading from forkid 9 to 12
- Upgrading from forkid 9 to 13

## safe_forkid_upgrade.sh
**SAFE** forkid upgrade script that preserves all L2 blockchain data. This script upgrades an existing enclave without losing any data.

### Key Features
- ✅ **Preserves all L2 blockchain data**
- ✅ **Creates automatic backups** before upgrade
- ✅ **Works with existing enclaves** (no new deployment)
- ✅ **Validates forkid changes** on chain and services
- ✅ **Safe rollback capability** via backups

### Usage
From the root of repo, run:
```bash
./scripts/safe_forkid_upgrade.sh <enclave_name> <source_forkid> <target_forkid>
```

**Example:**
```bash
./scripts/safe_forkid_upgrade.sh my-enclave 12 13
```

This would upgrade the existing enclave `my-enclave` from forkid 12 to forkid 13 while preserving all data.

### What the script does:
1. **Validates** enclave exists and current forkid
2. **Creates backups** of all databases (zkevm_node, zkevm_prover, zkevm_aggregator)
3. **Stops sequencer** safely
4. **Updates contracts** to new forkid version
5. **Deploys new verifier** and updates rollup on-chain
6. **Updates sequencer config** to use new forkid
7. **Restarts services** and validates forkid changes
8. **Verifies** all services are running with new forkid

### Supported upgrades:
- 9 → 11, 12, 13
- 11 → 12, 13  
- 12 → 13

### Backup location:
Backups are automatically created in `/tmp/forkid_upgrade_backup_YYYYMMDD_HHMMSS/`

### Safety features:
- Automatic database backups before upgrade
- Validation of current forkid before starting
- Step-by-step progress reporting
- Error handling with clear messages
- Confirmation prompts for unexpected states

## safe_service_upgrade.sh
**SAFE** service upgrade script that updates services with new configurations without changing forkid. This script is perfect for applying configuration changes, updating service images, or restarting services with new settings.

### Key Features
- ✅ **Preserves all L2 blockchain data**
- ✅ **Creates automatic backups** before upgrade
- ✅ **Updates specific service or all services**
- ✅ **No forkid changes** - only service restarts
- ✅ **Safe rollback capability** via backups
- ✅ **Dependency-aware** upgrade order

### Usage
From the root of repo, run:
```bash
# Upgrade all services
./scripts/safe_service_upgrade.sh <enclave_name>

# Upgrade specific service (e.g., blockscout)
./scripts/safe_service_upgrade.sh <enclave_name> <service_name>
```

**Examples:**
```bash
# Upgrade all services in enclave 'cdk'
./scripts/safe_service_upgrade.sh cdk

# Upgrade only blockscout backend service
./scripts/safe_service_upgrade.sh cdk bs-backend-001

# Upgrade only blockscout frontend service
./scripts/safe_service_upgrade.sh cdk bs-frontend-001

# Upgrade only grafana service
./scripts/safe_service_upgrade.sh cdk grafana-001
```

### What the script does:
1. **Validates** enclave exists
2. **Creates backups** of all databases
3. **Stops services** safely (in dependency order)
4. **Starts services** with new configurations
5. **Verifies** all services are running
6. **Reports** any failed services

### Perfect for:
- Updating blockscout configuration
- Applying new grafana dashboards
- Updating service images
- Restarting services with new settings
- Applying configuration changes from git

### Service upgrade order:
1. postgres-001 (main database)
2. bs-postgres-001 (blockscout database)
3. prometheus-001 (monitoring)
4. grafana-001 (dashboards)
5. panoptichain-001 (monitoring)
6. visualize-001 (visualization)
7. bs-backend-001 (blockscout backend)
8. bs-frontend-001 (blockscout frontend)
9. bs-stats-001 (blockscout stats)
10. zkevm-prover-001 (prover)
11. zkevm-bridge-service-001 (bridge)
12. zkevm-bridge-ui-001 (bridge UI)
13. zkevm-dac-001 (DAC)
14. zkevm-pool-manager-001 (pool manager)
15. zkevm-stateless-executor-001 (executor)
16. agglayer (aggregation layer)
17. agglayer-prover (aggregation prover)
18. cdk-erigon-rpc-001 (RPC)
19. cdk-erigon-sequencer-001 (sequencer)

### Backup location:
Backups are automatically created in `/tmp/service_upgrade_backup_YYYYMMDD_HHMMSS/`
