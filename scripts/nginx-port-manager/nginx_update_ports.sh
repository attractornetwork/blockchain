#!/bin/bash

# Script for one-time nginx configuration update with ports from Kurtosis enclave
# Usage: sudo ./nginx_update_ports.sh [ENCLAVE_NAME]

set -e

# Configuration
ENCLAVE_NAME="${1:-${ENCLAVE_NAME:-cdk}}"
NGINX_CONF_DIR="${NGINX_CONF_DIR:-/opt/attractor/nginx/conf.d}"
BACKUP_DIR="${BACKUP_DIR:-/opt/attractor/nginx/conf.d/backup}"
LOG_FILE="${LOG_FILE:-/var/log/nginx-port-updater.log}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp="[$(date '+%Y-%m-%d %H:%M:%S')]"
    
    case "$level" in
        "INFO")
            echo -e "${BLUE}ℹ️  $message${NC}"
            echo "$timestamp [INFO] $message" >> "$LOG_FILE"
            ;;
        "SUCCESS")
            echo -e "${GREEN}✅ $message${NC}"
            echo "$timestamp [SUCCESS] $message" >> "$LOG_FILE"
            ;;
        "WARNING")
            echo -e "${YELLOW}⚠️  $message${NC}"
            echo "$timestamp [WARNING] $message" >> "$LOG_FILE"
            ;;
        "ERROR")
            echo -e "${RED}❌ $message${NC}"
            echo "$timestamp [ERROR] $message" >> "$LOG_FILE"
            ;;
    esac
}

# Show help
show_help() {
    cat << EOF
Nginx port update for Kurtosis CDK

USAGE:
    sudo $0 [OPTIONS] [ENCLAVE_NAME]

ARGUMENTS:
    ENCLAVE_NAME    Kurtosis enclave name (default: cdk)

OPTIONS:
    -h, --help      Show this help
    -v, --verbose   Verbose output
    -d, --dry-run   Show what would be done without applying changes
    --no-backup     Do not create backup (not recommended)

ENVIRONMENT VARIABLES:
    NGINX_CONF_DIR  Path to nginx configurations (default: /opt/attractor/nginx/conf.d)
    BACKUP_DIR      Path for backups (default: /opt/attractor/nginx/conf.d/backup)
    LOG_FILE        Log file (default: /var/log/nginx-port-updater.log)

EXAMPLES:
    sudo $0                         # Update ports for 'cdk' enclave
    sudo $0 my-enclave             # Update ports for 'my-enclave' enclave
    sudo $0 --dry-run              # Show what would be done
    sudo $0 --verbose cdk          # Verbose output for 'cdk' enclave

EOF
}

# Parse arguments
VERBOSE=false
DRY_RUN=false
NO_BACKUP=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -d|--dry-run)
            DRY_RUN=true
            shift
            ;;
        --no-backup)
            NO_BACKUP=true
            shift
            ;;
        -*)
            log "ERROR" "Unknown option: $1"
            exit 1
            ;;
        *)
            ENCLAVE_NAME="$1"
            shift
            ;;
    esac
done

# Function to create config backup
backup_configs() {
    if [[ "$NO_BACKUP" == "true" ]]; then
        log "WARNING" "Skipping backup creation (--no-backup)"
        return 0
    fi
    
    log "INFO" "Creating nginx configuration backup..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log "INFO" "[DRY-RUN] Would create backup in: $BACKUP_DIR"
        return 0
    fi
    
    mkdir -p "$BACKUP_DIR"
    cp "$NGINX_CONF_DIR"/*.conf "$BACKUP_DIR/" 2>/dev/null || true
    log "SUCCESS" "Backup created in $BACKUP_DIR"
}

# Function to get ports from Kurtosis
get_service_ports() {
    local service_name="$1"
    local port_type="$2"
    
    if [[ "$VERBOSE" == "true" ]]; then
        log "INFO" "Searching port for service: $service_name, type: $port_type"
    fi
    
    local port=$(kurtosis enclave inspect "$ENCLAVE_NAME" 2>/dev/null | \
        grep -A 10 "$service_name" | \
        grep "$port_type" | \
        grep -o '127\.0\.0\.1:[0-9]\+' | \
        cut -d':' -f2 | \
        head -1)
    
    echo "$port"
}

# Function to extract all ports
extract_ports() {
    log "INFO" "Extracting ports from enclave '$ENCLAVE_NAME'..."
    
    # RPC service (cdk-erigon-sequencer)
    RPC_HTTP_PORT=$(get_service_ports "cdk-erigon-sequencer" "rpc")
    RPC_WS_PORT=$(get_service_ports "cdk-erigon-sequencer" "ws-rpc")
    
    # Explorer services
    EXPLORER_FRONTEND_PORT=$(get_service_ports "bs-frontend" "frontend")
    EXPLORER_API_PORT=$(get_service_ports "bs-backend" "backend")
    EXPLORER_STATS_PORT=$(get_service_ports "bs-stats" "stats")
    EXPLORER_SOCKET_PORT="$RPC_WS_PORT"  # Use same WS port
    
    # Bridge UI
    BRIDGE_UI_PORT=$(get_service_ports "zkevm-bridge-ui" "web-ui")
    
    # DAC service
    DAC_PORT=$(get_service_ports "zkevm-dac" "dac")
    
    # Faucet (if available)
    FAUCET_PORT=$(get_service_ports "faucet" "web")
    
    # Show found ports
    log "SUCCESS" "Found ports:"
    echo "  RPC HTTP: ${RPC_HTTP_PORT:-not found}"
    echo "  RPC WebSocket: ${RPC_WS_PORT:-not found}"
    echo "  Explorer Frontend: ${EXPLORER_FRONTEND_PORT:-not found}"
    echo "  Explorer API: ${EXPLORER_API_PORT:-not found}"
    echo "  Explorer Stats: ${EXPLORER_STATS_PORT:-not found}"
    echo "  Bridge UI: ${BRIDGE_UI_PORT:-not found}"
    echo "  DAC: ${DAC_PORT:-not found}"
    echo "  Faucet: ${FAUCET_PORT:-not found}"
}

# Function to create configuration
create_config() {
    local service_name="$1"
    local config_file="$2"
    local template="$3"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log "INFO" "[DRY-RUN] Would create configuration: $config_file"
        return 0
    fi
    
    echo "$template" > "$config_file.tmp"
    mv "$config_file.tmp" "$config_file"
    log "SUCCESS" "$service_name configuration updated"
}

# Function to update RPC configuration
update_rpc_config() {
    local config_file="$NGINX_CONF_DIR/rpc.testnet.attra.me.conf"
    
    if [[ -z "$RPC_HTTP_PORT" || -z "$RPC_WS_PORT" ]]; then
        log "ERROR" "Failed to find ports for RPC service"
        return 1
    fi
    
    log "INFO" "Updating RPC configuration (HTTP: $RPC_HTTP_PORT, WS: $RPC_WS_PORT)..."
    
    local template="map \$http_upgrade \$connection_upgrade {
    default   Upgrade;
    ''        close;
}

map \$http_upgrade \$backend {
    default              http://127.0.0.1:$RPC_HTTP_PORT;
    websocket            http://127.0.0.1:$RPC_WS_PORT;
}

server {
    listen 443 ssl http2;
    server_name rpc.testnet.attra.me;

    ssl_certificate     /etc/letsencrypt/live/da.testnet.attra.me/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/da.testnet.attra.me/privkey.pem;

    location / {
        proxy_pass              \$backend;
        proxy_set_header        Host               \$host;
        proxy_set_header        X-Real-IP          \$remote_addr;
        proxy_set_header        X-Forwarded-For    \$proxy_add_x_forwarded_for;
        proxy_set_header        X-Forwarded-Proto  \$scheme;
        proxy_http_version      1.1;
        proxy_set_header        Upgrade            \$http_upgrade;
        proxy_set_header        Connection         \$connection_upgrade;
        proxy_read_timeout      300s;
        proxy_send_timeout      300s;
        proxy_connect_timeout   75s;
    }
}

server {
    listen 80;
    server_name rpc.testnet.attra.me;
    
    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }

    location / {
        proxy_pass              \$backend;
        proxy_set_header        Host               \$host;
        proxy_set_header        X-Real-IP          \$remote_addr;
        proxy_set_header        X-Forwarded-For    \$proxy_add_x_forwarded_for;
        proxy_set_header        X-Forwarded-Proto  \$scheme;
        proxy_http_version      1.1;
        proxy_set_header        Upgrade            \$http_upgrade;
        proxy_set_header        Connection         \$connection_upgrade;
        proxy_read_timeout      300s;
        proxy_send_timeout      300s;
        proxy_connect_timeout   75s;
    }
}"

    create_config "RPC" "$config_file" "$template"
}

# Function to update Explorer configuration
update_explorer_config() {
    local config_file="$NGINX_CONF_DIR/explorer.testnet.attra.me.conf"
    
    if [[ -z "$EXPLORER_FRONTEND_PORT" || -z "$EXPLORER_API_PORT" || -z "$EXPLORER_STATS_PORT" ]]; then
        log "ERROR" "Failed to find ports for Explorer service"
        return 1
    fi
    
    log "INFO" "Updating Explorer configuration (Frontend: $EXPLORER_FRONTEND_PORT, API: $EXPLORER_API_PORT, Stats: $EXPLORER_STATS_PORT)..."
    
    local template="map \$request_uri \$explorer_backend_port {
    ~^/api/            $EXPLORER_API_PORT;
    ~^/stats-api/      $EXPLORER_STATS_PORT;
    ~^/socket/         $EXPLORER_SOCKET_PORT;
    default            $EXPLORER_FRONTEND_PORT;
}

map \$http_upgrade \$connection_upgrade {
    default   Upgrade;
    ''        close;
}

server {
    listen 443 ssl http2;
    server_name explorer.testnet.attra.me;

    ssl_certificate     /etc/letsencrypt/live/da.testnet.attra.me/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/da.testnet.attra.me/privkey.pem;

    location / {
        proxy_pass              http://127.0.0.1:\$explorer_backend_port\$request_uri;
        proxy_set_header        Host               \$host;
        proxy_set_header        X-Real-IP          \$remote_addr;
        proxy_set_header        X-Forwarded-For    \$proxy_add_x_forwarded_for;
        proxy_set_header        X-Forwarded-Proto  \$scheme;
        proxy_http_version      1.1;
        proxy_set_header        Upgrade            \$http_upgrade;
        proxy_set_header        Connection         \$connection_upgrade;
    }
}

server {
    listen 80;
    server_name explorer.testnet.attra.me;

    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }

    location / {
        proxy_pass              http://127.0.0.1:\$explorer_backend_port\$request_uri;
        proxy_set_header        Host               \$host;
        proxy_set_header        X-Real-IP          \$remote_addr;
        proxy_set_header        X-Forwarded-For    \$proxy_add_x_forwarded_for;
        proxy_set_header        X-Forwarded-Proto  \$scheme;
        proxy_http_version      1.1;
        proxy_set_header        Upgrade            \$http_upgrade;
        proxy_set_header        Connection         \$connection_upgrade;
    }
}"

    create_config "Explorer" "$config_file" "$template"
}

# Function to update Bridge configuration
update_bridge_config() {
    local config_file="$NGINX_CONF_DIR/bridge.testnet.attra.me.conf"
    
    if [[ -z "$BRIDGE_UI_PORT" ]]; then
        log "WARNING" "Failed to find port for Bridge UI, skipping"
        return 0
    fi
    
    log "INFO" "Updating Bridge configuration (Port: $BRIDGE_UI_PORT)..."
    
    local template="server {
    listen 443 ssl http2;
    server_name bridge.testnet.attra.me;

    ssl_certificate     /etc/letsencrypt/live/da.testnet.attra.me/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/da.testnet.attra.me/privkey.pem;

    location / {
        proxy_pass              http://127.0.0.1:$BRIDGE_UI_PORT;
        proxy_set_header        Host               \$host;
        proxy_set_header        X-Real-IP          \$remote_addr;
        proxy_set_header        X-Forwarded-For    \$proxy_add_x_forwarded_for;
        proxy_set_header        X-Forwarded-Proto  \$scheme;
        proxy_http_version      1.1;
        proxy_set_header        Upgrade            \$http_upgrade;
        proxy_set_header        Connection         \"upgrade\";
    }
}

server {
    listen 80;
    server_name bridge.testnet.attra.me;

    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }

    location / {
        proxy_pass              http://127.0.0.1:$BRIDGE_UI_PORT;
        proxy_set_header        Host               \$host;
        proxy_set_header        X-Real-IP          \$remote_addr;
        proxy_set_header        X-Forwarded-For    \$proxy_add_x_forwarded_for;
        proxy_set_header        X-Forwarded-Proto  \$scheme;
        proxy_http_version      1.1;
        proxy_set_header        Upgrade            \$http_upgrade;
        proxy_set_header        Connection         \"upgrade\";
    }
}"

    create_config "Bridge" "$config_file" "$template"
}

# Function to update DAC configuration
update_dac_config() {
    local config_file="$NGINX_CONF_DIR/da.testnet.attra.me.conf"
    
    if [[ -z "$DAC_PORT" ]]; then
        log "WARNING" "Failed to find port for DAC service, skipping"
        return 0
    fi
    
    log "INFO" "Updating DAC configuration (Port: $DAC_PORT)..."
    
    local template="server {
    listen 443 ssl http2;
    server_name da.testnet.attra.me;

    ssl_certificate     /etc/letsencrypt/live/da.testnet.attra.me/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/da.testnet.attra.me/privkey.pem;

    location / {
        proxy_pass              http://127.0.0.1:$DAC_PORT;
        proxy_set_header        Host               \$host;
        proxy_set_header        X-Real-IP          \$remote_addr;
        proxy_set_header        X-Forwarded-For    \$proxy_add_x_forwarded_for;
        proxy_set_header        X-Forwarded-Proto  \$scheme;
        proxy_http_version      1.1;
    }
}

server {
    listen 80;
    server_name da.testnet.attra.me;

    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }

    location / {
        proxy_pass              http://127.0.0.1:$DAC_PORT;
        proxy_set_header        Host               \$host;
        proxy_set_header        X-Real-IP          \$remote_addr;
        proxy_set_header        X-Forwarded-For    \$proxy_add_x_forwarded_for;
        proxy_set_header        X-Forwarded-Proto  \$scheme;
        proxy_http_version      1.1;
    }
}"

    create_config "DAC" "$config_file" "$template"
}

# Function to update Faucet configuration
update_faucet_config() {
    local config_file="$NGINX_CONF_DIR/faucet.testnet.attra.me.conf"
    
    if [[ -z "$FAUCET_PORT" ]]; then
        log "INFO" "Faucet service not found, skipping"
        return 0
    fi
    
    log "INFO" "Updating Faucet configuration (Port: $FAUCET_PORT)..."
    
    local template="server {
    listen 443 ssl http2;
    server_name faucet.testnet.attra.me;

    ssl_certificate     /etc/letsencrypt/live/da.testnet.attra.me/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/da.testnet.attra.me/privkey.pem;

    location / {
        proxy_pass              http://127.0.0.1:$FAUCET_PORT;
        proxy_set_header        Host               \$host;
        proxy_set_header        X-Real-IP          \$remote_addr;
        proxy_set_header        X-Forwarded-For    \$proxy_add_x_forwarded_for;
        proxy_set_header        X-Forwarded-Proto  \$scheme;
        proxy_http_version      1.1;
    }
}

server {
    listen 80;
    server_name faucet.testnet.attra.me;

    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }

    location / {
        proxy_pass              http://127.0.0.1:$FAUCET_PORT;
        proxy_set_header        Host               \$host;
        proxy_set_header        X-Real-IP          \$remote_addr;
        proxy_set_header        X-Forwarded-For    \$proxy_add_x_forwarded_for;
        proxy_set_header        X-Forwarded-Proto  \$scheme;
        proxy_http_version      1.1;
    }
}"

    create_config "Faucet" "$config_file" "$template"
}

# Function to test nginx configuration
test_nginx_config() {
    log "INFO" "Testing nginx configuration..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log "INFO" "[DRY-RUN] Would check nginx configuration"
        return 0
    fi
    
    # Test nginx configuration using docker
    if docker exec attractor-nginx nginx -t >/dev/null 2>&1; then
        log "SUCCESS" "Nginx configuration is valid"
        return 0
    else
        log "ERROR" "Nginx configuration contains errors:"
        docker exec attractor-nginx nginx -t
        return 1
    fi
}

# Function to reload nginx via docker compose
reload_nginx() {
    log "INFO" "Reloading nginx via docker compose..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log "INFO" "[DRY-RUN] Would reload nginx via docker compose"
        return 0
    fi
    
    local docker_compose_dir="/opt/attractor"
    
    if [[ ! -f "$docker_compose_dir/docker-compose.yml" ]]; then
        log "ERROR" "Docker compose file not found: $docker_compose_dir/docker-compose.yml"
        return 1
    fi
    
    cd "$docker_compose_dir"
    if docker compose up -d; then
        log "SUCCESS" "Nginx reloaded successfully via docker compose"
        return 0
    else
        log "ERROR" "Failed to reload nginx via docker compose"
        return 1
    fi
}

# Function to restore from backup
restore_from_backup() {
    if [[ "$NO_BACKUP" == "true" ]]; then
        log "ERROR" "Backup was not created (--no-backup), restore impossible"
        return 1
    fi
    
    log "WARNING" "Restoring configurations from backup..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log "INFO" "[DRY-RUN] Would restore configurations from backup"
        return 0
    fi
    
    cp "$BACKUP_DIR"/*.conf "$NGINX_CONF_DIR/" 2>/dev/null || true
    cd "/opt/attractor" && docker compose up -d
    log "SUCCESS" "Configurations restored from backup"
}

# Main function
main() {
    log "INFO" "Starting nginx port update for enclave '$ENCLAVE_NAME'"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log "INFO" "DRY-RUN mode: changes will not be applied"
    fi
    
    # Check root privileges
    if [[ $EUID -ne 0 && "$DRY_RUN" == "false" ]]; then
        log "ERROR" "Root privileges required for nginx configuration changes"
        log "INFO" "Try: sudo $0 $*"
        exit 1
    fi
    
    # Check that enclave is running
    if ! kurtosis enclave inspect "$ENCLAVE_NAME" >/dev/null 2>&1; then
        log "ERROR" "Enclave '$ENCLAVE_NAME' not found or not running"
        log "INFO" "Available enclaves:"
        kurtosis enclave ls 2>/dev/null || log "ERROR" "Error getting enclave list"
        exit 1
    fi
    
    # Create log file if needed
    mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true
    
    # Create backup
    backup_configs
    
    # Extract ports
    extract_ports
    
    # Update configurations
    local configs_updated=0
    
    if update_rpc_config; then
        ((configs_updated++))
    fi
    
    if update_explorer_config; then
        ((configs_updated++))
    fi
    
    if update_bridge_config; then
        ((configs_updated++))
    fi
    
    if update_dac_config; then
        ((configs_updated++))
    fi
    
    if update_faucet_config; then
        ((configs_updated++))
    fi
    
    if [[ $configs_updated -eq 0 ]]; then
        log "WARNING" "No configurations were updated"
        exit 1
    fi
    
    # Check configuration
    if test_nginx_config; then
        # Reload nginx
        if reload_nginx; then
            log "SUCCESS" "Port update completed successfully! Updated configurations: $configs_updated"
        else
            restore_from_backup
            exit 1
        fi
    else
        restore_from_backup
        exit 1
    fi
}

# Run script
main "$@" 
