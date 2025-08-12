#!/bin/bash

# Script to disable automatic nginx port updates on system boot
# Usage: sudo ./nginx_auto_stop.sh [--remove-all]

set -e

# Configuration
SERVICE_NAME="nginx-port-updater"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
REMOVE_ALL=false

# Simple logging
log() {
    echo "$*"
}

# Show help
show_help() {
    cat << EOF
Disable automatic nginx port updates on system boot

USAGE:
    sudo $0 [OPTIONS]

OPTIONS:
    -h, --help          Show this help
    --remove-all        Remove all service files completely

DESCRIPTION:
    This script stops and disables the systemd service that
    automatically runs nginx_update_ports.sh on system boot.

    By default, it only stops and disables the service.
    Use --remove-all to completely remove all files.

EXAMPLES:
    sudo $0                    # Stop and disable service
    sudo $0 --remove-all      # Remove all files completely

EOF
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        --remove-all)
            REMOVE_ALL=true
            shift
            ;;
        *)
            log "ERROR: Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log "ERROR: This script must be run as root"
        log "Try: sudo $0 $*"
        exit 1
    fi
}

# Stop and disable service
stop_service() {
    log "Stopping and disabling service..."
    
    # Stop service if running
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        if systemctl stop "$SERVICE_NAME"; then
            log "Service stopped"
        else
            log "WARNING: Failed to stop service"
        fi
    else
        log "Service is not running"
    fi
    
    # Disable service
    if systemctl is-enabled --quiet "$SERVICE_NAME"; then
        if systemctl disable "$SERVICE_NAME"; then
            log "Service disabled"
        else
            log "ERROR: Failed to disable service"
            return 1
        fi
    else
        log "Service is not enabled"
    fi
    
    # Reload systemd
    systemctl daemon-reload
}

# Remove service files
remove_files() {
    if [[ "$REMOVE_ALL" == "true" ]]; then
        log "Removing all service files..."
        
        # Remove service file
        if [[ -f "$SERVICE_FILE" ]]; then
            if rm "$SERVICE_FILE"; then
                log "Service file removed: $SERVICE_FILE"
            else
                log "ERROR: Failed to remove service file"
                return 1
            fi
        else
            log "Service file not found: $SERVICE_FILE"
        fi
        
        # Reload systemd
        systemctl daemon-reload
        
        log "All service files removed"
    fi
}

# Show status
show_status() {
    log "Current service status:"
    
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        log "WARNING: Service is still running"
    else
        log "Service is stopped"
    fi
    
    if systemctl is-enabled --quiet "$SERVICE_NAME"; then
        log "WARNING: Service is still enabled"
    else
        log "Service is disabled"
    fi
}

# Main function
main() {
    # Check root privileges
    check_root "$@"
    
    log "Disabling automatic nginx port updates..."
    
    # Stop and disable service
    stop_service
    
    # Remove files if requested
    remove_files
    
    # Show final status
    show_status
    
    if [[ "$REMOVE_ALL" == "true" ]]; then
        log "Automatic nginx port updates completely removed!"
        log "To re-enable: sudo ./nginx_auto_start.sh"
    else
        log "Automatic nginx port updates disabled!"
        log "Service will not start on next boot"
        log "To re-enable: sudo ./nginx_auto_start.sh"
        log "To remove completely: sudo $0 --remove-all"
    fi
}

# Run script
main "$@"
