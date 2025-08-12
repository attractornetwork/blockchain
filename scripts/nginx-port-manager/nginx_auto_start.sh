#!/bin/bash

# Script to enable automatic nginx port updates on system boot
# Usage: sudo ./nginx_auto_start.sh [ENCLAVE_NAME]

set -e

# Configuration
ENCLAVE_NAME="${1:-cdk}"
SERVICE_NAME="nginx-port-updater"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/nginx_update_ports.sh"

# Simple logging
log() {
    echo "$*"
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
    log "Creating systemd service for enclave '$ENCLAVE_NAME'..."
    
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

    log "Service file created: $SERVICE_FILE"
}

# Enable and start service
enable_service() {
    log "Enabling and starting service..."
    
    # Reload systemd
    systemctl daemon-reload
    
    # Enable service (start on boot)
    if systemctl enable "$SERVICE_NAME"; then
        log "Service enabled for boot startup"
    else
        log "ERROR: Failed to enable service"
        return 1
    fi
    
    # Start service now (optional)
    if systemctl start "$SERVICE_NAME"; then
        log "Service started successfully"
    else
        log "WARNING: Service started but may have failed (check logs)"
    fi
}

# Show status
show_status() {
    log "Service status:"
    systemctl status "$SERVICE_NAME" --no-pager -l || true
    
    log "Service enabled status:"
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
        log "ERROR: Script not found: $SCRIPT_PATH"
        exit 1
    fi
    
    # Make script executable
    chmod +x "$SCRIPT_PATH"
    
    log "Setting up automatic nginx port updates for enclave '$ENCLAVE_NAME'"
    
    # Create service
    create_service
    
    # Enable and start
    enable_service
    
    # Show status
    show_status
    
    log "Automatic nginx port updates enabled!"
    log "Service will run automatically on next system boot"
    log "To disable: sudo ./nginx_auto_stop.sh"
}

# Run script
main "$@"
