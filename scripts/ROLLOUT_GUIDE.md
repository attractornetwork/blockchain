# Service Rollout Guide

## Safe Service Rollout Process

This guide describes the step-by-step process for safely rolling out/updating Kurtosis enclave services while maintaining data integrity and minimizing downtime.

## IMPORTANT: Read before starting!

- **Expected downtime:** 10-30 minutes depending on data size
- **Service availability:** RPC and WebSocket will be unavailable during the procedure
- **Data safety:** All data is backed up before any changes

## Step-by-Step Rollout Process

### Step 1: Block Access to RPC/WS (nginx down)

Block external access to RPC and WebSocket endpoints by stopping nginx services:

```bash
# Navigate to nginx directory
cd /opt/attractor

# Stop nginx services to block external access
docker compose down nginx

# Verify nginx is stopped
docker ps | grep nginx
# Should return empty - no nginx containers running
```

**Result:** RPC and WebSocket are inaccessible from outside, no new requests are accepted.

### Step 2: Create Data Backup

Create a complete backup of all service data before making changes:

```bash
# Create full backup of all services
./scripts/database/create_backup.sh cdk /tmp/rollout_backup_$(date +%Y%m%d_%H%M%S)

# Wait for completion and verify result
ls -la /tmp/rollout_backup_*
echo "Backup created successfully"
```

**Result:** All databases and blockchain data are safely stored in a backup location.

**Important** Dont create backup dir files in the kurtosis dir. You should to create new backup dir inside.

### Step 3: Stop Kurtosis Enclave (or skip this step if kurtosis services are empty)

Stop the entire enclave to safely make changes:

```bash
# Stop the entire enclave
kurtosis enclave stop cdk

# Verify enclave is stopped
kurtosis enclave ls
# Should show that cdk is not running
```

**Result:** All services are stopped, safe to make changes.

### Step 4: Perform Required Changes

Execute your necessary changes, for example:

```bash
# Option A: Reinstall enclave
kurtosis enclave remove cdk
kurtosis enclave start cdk

# Option B: Just update everything
sed -i 's/"salt": "0x.*",/"salt": "0x'$(xxd -p < /dev/random  | tr -d "\n" | head -c 64)'",/' templates/contract-deploy/deploy_parameters.json && sudo kurtosis clean --all && ./return-script.sh && sudo docker stop $(sudo docker ps -q) && sudo docker rm $(sudo docker ps -a -q) && sudo kurtosis run --enclave cdk --args-file params.yml --image-download always . --production

# Option C: Restart with new parameters
kurtosis enclave start cdk --enclave-params-file new_params.json
```

**Result:** Enclave is updated/reinstalled according to your requirements.

### Step 5: Restore Data from Backup

Restore all data after the enclave is running:

```bash
# Wait for enclave to fully start
kurtosis enclave inspect cdk

# Restore all data
./scripts/database/restore_service_data.sh cdk /tmp/rollout_backup_*

# Verify restoration was successful
echo "Data restored successfully"
```

**Result:** All services are running with restored data.

### Step 6: Restore Access (nginx up)

Restart nginx services to restore external access:

```bash
# Start nginx services back
cd /opt/attractor
docker compose up -d

# Verify nginx is running
docker ps | grep nginx
# Should show running nginx containers

# Test RPC availability
curl -X POST -H "Content-Type: application/json" \
  --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
  http://<your_rpc_url>
```

**Result:** RPC and WebSocket are accessible again, services are running with updated data.

## Service Verification

### Check overall service status:
```bash
# General enclave status
kurtosis enclave inspect cdk

# Check logs of main services
kurtosis service logs cdk erigon-sequencer-001 --follow=false
kurtosis service logs cdk postgres-001 --follow=false
```

or check it with `docker logs <containers_id>`

## Best Practices

1. **Always create backup** before any changes
2. **Test on dev environment** before production
3. **Plan downtime** and notify users
4. **Monitor logs** during the process
5. **Have rollback plan** in case of issues

## Expected Timeline

| Step | Duration | Description |
|------|----------|-------------|
| 1. Block access | 1-2 min | Stop nginx services |
| 2. Create backup | 5-15 min | Backup databases and blockchain data |
| 3. Stop enclave | 1-2 min | Stop all services |
| 4. Make changes | ~ min | Your modifications |
| 5. Restore data | 5-15 min | Restore from backup |
| 6. Restore access | 1-2 min | Start nginx services |

**Total expected time:** up to 1 hour
