#!/bin/bash

# Simple nginx port management script for Kurtosis CDK

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Logging function
log() {
    local level="$1"
    shift
    local message="$*"
    
    case "$level" in
        "INFO")
            echo -e "${BLUE}INFO: $message${NC}"
            ;;
        "SUCCESS")
            echo -e "${GREEN}SUCCESS: $message${NC}"
            ;;
        "WARNING")
            echo -e "${YELLOW}WARNING: $message${NC}"
            ;;
        "ERROR")
            echo -e "${RED}ERROR: $message${NC}"
            ;;
    esac
}

# Show help
show_help() {
    echo ""
    echo "Nginx port management for Kurtosis CDK"
    echo "======================================"
    echo ""
    echo "COMMANDS:"
    echo "  update                   Update nginx ports now"
    echo ""
    echo "EXAMPLES:"
    echo "  $0 update                # Update ports now"
    echo ""
}

# Check script availability
check_scripts() {
    if [[ ! -f "$SCRIPT_DIR/nginx_update_ports.sh" ]]; then
        log "ERROR" "Script not found: nginx_update_ports.sh"
        exit 1
    fi   
}

# Command: update ports
cmd_update() {
    echo "Updating nginx ports..."
    echo ""
    
    chmod +x "$SCRIPT_DIR/nginx_update_ports.sh"
    sudo "$SCRIPT_DIR/nginx_update_ports.sh"
}

# Main function
main() {
    check_scripts
    
    if [[ $# -eq 0 ]]; then
        show_help
        exit 0
    fi
    
    local command="$1"
    
    case "$command" in
        update)
            cmd_update
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            log "ERROR" "Unknown command: $command"
            echo ""
            show_help
            exit 1
            ;;
    esac
}

# Run script
main "$@" 
