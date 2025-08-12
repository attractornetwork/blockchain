#!/bin/bash

# Script to enable automatic nginx port updates on system boot
# Usage: sudo ./nginx_auto_start.sh [ENCLAVE_NAME]

set -e

# Configuration
ENCLAVE_NAME="${1:-cdk}"
SERVICE_NAME="nginx-port-updater"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/nginx_update_ports.sh"

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
            ;;
        "SUCCESS")
            echo -e "${GREEN}$message${NC}"
            ;;
        "WARNING")
            echo -e "${YELLOW}$message${NC}"
            ;;
        "ERROR")
            echo -e "${RED}$message${NC}"
            ;;
    esac
}

# Show help
show_help() {
    cat << EOF
Enable automatic nginx port updates on system boot

USAGE:
    sudo $0 [ENCLAVE_NAME]

ARGUMENTS:
    ENCLAVE_NAME    Kurtosis enclave name (default: cdk)

DESCRIPTION:
    This script creates a systemd service that automatically runs
    nginx_update_ports.sh when the system boots up.

    The service will run 2 minutes after boot to ensure
    all services are fully started.

EXAMPLES:
    sudo $0                    # Enable for 'cdk' enclave
    sudo $0 my-enclave        # Enable for 'my-enclave' enclave

EOF
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log "ERROR" "This script must be run as root"
        log "INFO" "Try: sudo $0 $*"
        exit 1
    fi
}

# Create systemd service file
create_service() {
    log "INFO" "Creating systemd service for enclave '$ENCLAVE_NAME'..."
    
    cat > "$SERVICE_FILE" << EOF
[Unit]
Description=Nginx Port Updater for Kurtosis CDK
After=network.target docker.service
Wants=network.target

[Service]
Type=oneshot
ExecStart=$SCRIPT_PATH $ENCLAVE_NAME
User=root
Group=root
RemainAfterExit=yes
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

    log "SUCCESS" "Service file created: $SERVICE_FILE"
}

# Enable and start service
enable_service() {
    log "INFO" "Enabling and starting service..."
    
    # Reload systemd
    systemctl daemon-reload
    
    # Enable service (start on boot)
    if systemctl enable "$SERVICE_NAME"; then
        log "SUCCESS" "Service enabled for boot startup"
    else
        log "ERROR" "Failed to enable service"
        return 1
    fi
    
    # Start service now (optional)
    if systemctl start "$SERVICE_NAME"; then
        log "SUCCESS" "Service started successfully"
    else
        log "WARNING" "Service started but may have failed (check logs)"
    fi
}

# Show status
show_status() {
    log "INFO" "Service status:"
    systemctl status "$SERVICE_NAME" --no-pager -l || true
    
    log "INFO" "Service enabled status:"
    systemctl is-enabled "$SERVICE_NAME" || echo "Not enabled"
}

# Main function
main() {
    # Show help if requested
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        show_help
        exit 0
    fi
    
    # Check root privileges
    check_root "$@"
    
    # Check if script exists
    if [[ ! -f "$SCRIPT_PATH" ]]; then
        log "ERROR" "Script not found: $SCRIPT_PATH"
        exit 1
    fi
    
    # Make script executable
    chmod +x "$SCRIPT_PATH"
    
    log "INFO" "Setting up automatic nginx port updates for enclave '$ENCLAVE_NAME'"
    
    # Create service
    create_service
    
    # Enable and start
    enable_service
    
    # Show status
    show_status
    
    log "SUCCESS" "Automatic nginx port updates enabled!"
    log "INFO" "Service will run automatically on next system boot"
    log "INFO" "To disable: sudo ./nginx_auto_stop.sh"
}

# Run script
main "$@"
