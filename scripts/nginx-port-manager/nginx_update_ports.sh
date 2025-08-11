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
            echo -e "${BLUE}$message${NC}"
            echo "$timestamp [INFO] $message" >> "$LOG_FILE"
            ;;
        "SUCCESS")
            echo -e "${GREEN}$message${NC}"
            echo "$timestamp [SUCCESS] $message" >> "$LOG_FILE"
            ;;
        "WARNING")
            echo -e "${YELLOW}$message${NC}"
            echo "$timestamp [WARNING] $message" >> "$LOG_FILE"
            ;;
        "ERROR")
            echo -e "${RED}$message${NC}"
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

ENVIRONMENT VARIABLES:
    NGINX_CONF_DIR  Path to nginx configurations (default: /opt/attractor/nginx/conf.d)
    BACKUP_DIR      Path for backups (default: /opt/attractor/nginx/conf.d/backup)
    LOG_FILE        Log file (default: /var/log/nginx-port-updater.log)

EXAMPLES:
    sudo $0                         # Update ports for 'cdk' enclave
    sudo $0 my-enclave             # Update ports for 'my-enclave' enclave

EOF
}

# Parse arguments

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
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

    
    log "INFO" "Creating nginx configuration backup..."
    

    
    mkdir -p "$BACKUP_DIR"
    cp "$NGINX_CONF_DIR"/*.conf "$BACKUP_DIR/" 2>/dev/null || true
    log "SUCCESS" "Backup created in $BACKUP_DIR"
}

# Function to get ports from Kurtosis
get_service_ports() {
    local service_name="$1"
    local port_type="$2"
    

    
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
    
    # Show found ports
    log "SUCCESS" "Found ports:"
    echo "  RPC HTTP: ${RPC_HTTP_PORT:-not found}"
    echo "  RPC WebSocket: ${RPC_WS_PORT:-not found}"
    echo "  Explorer Frontend: ${EXPLORER_FRONTEND_PORT:-not found}"
    echo "  Explorer API: ${EXPLORER_API_PORT:-not found}"
    echo "  Explorer Stats: ${EXPLORER_STATS_PORT:-not found}"
}

# Function to create configuration
create_config() {
    local service_name="$1"
    local config_file="$2"
    local template="$3"
    

    
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

# Function to test nginx configuration
test_nginx_config() {
    log "INFO" "Testing nginx configuration..."
    

    
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

    
    log "WARNING" "Restoring configurations from backup..."
    

    
    cp "$BACKUP_DIR"/*.conf "$NGINX_CONF_DIR/" 2>/dev/null || true
    cd "/opt/attractor" && docker compose up -d
    log "SUCCESS" "Configurations restored from backup"
}

# Main function
main() {
    log "INFO" "Starting nginx port update for enclave '$ENCLAVE_NAME'"
    

    
    # Check root privileges
    if [[ $EUID -ne 0 ]]; then
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
