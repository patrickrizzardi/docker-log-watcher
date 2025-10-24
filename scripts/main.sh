#!/bin/bash

# Advanced Log Watcher - Main Orchestrator
# Coordinates Docker, system, and file monitoring

set -e

# Source common functions
source /app/scripts/common.sh

# Colors and formatting
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# Function to print colored output
print_header() {
    echo -e "${BLUE}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC} ${YELLOW}🐳 ADVANCED LOG WATCHER${NC} ${BLUE}$(date '+%Y-%m-%d %H:%M:%S')${NC} ${BLUE}║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}



# Function to display configuration
show_configuration() {
    print_section "CONFIGURATION"
    echo "Docker monitoring: $ENABLE_DOCKER_MONITORING (interval: ${DOCKER_CHECK_INTERVAL}s)"
    echo "System monitoring: $ENABLE_SYSTEM_MONITORING (interval: ${SYSTEM_CHECK_INTERVAL}s)"
    echo "File monitoring: $ENABLE_FILE_MONITORING"
    echo "Log tail lines: $LOG_TAIL_LINES"
    echo ""
}

# Function to start Docker monitoring
start_docker_monitoring() {
    if [ "$ENABLE_DOCKER_MONITORING" = "true" ]; then
        print_info "Starting Docker container monitoring..."
        /app/scripts/docker-monitor.sh "$DOCKER_CHECK_INTERVAL" &
    else
        print_info "Docker monitoring disabled via ENABLE_DOCKER_MONITORING"
    fi
}

# Function to start system monitoring
start_system_monitoring() {
    if [ "$ENABLE_SYSTEM_MONITORING" = "true" ]; then
        print_info "Starting system service monitoring..."
        /app/scripts/system-monitor.sh "$SYSTEM_CHECK_INTERVAL" &
    else
        print_info "System monitoring disabled via ENABLE_SYSTEM_MONITORING"
    fi
}

# Function to start file monitoring
start_file_monitoring() {
    if [ "$ENABLE_FILE_MONITORING" = "true" ]; then
        print_info "Starting file system monitoring..."
        /app/scripts/file-monitor.sh &
    else
        print_info "File monitoring disabled via ENABLE_FILE_MONITORING"
    fi
}

# Main execution
main() {
    print_header
    
    # Show configuration
    show_configuration
    
    print_section "LIVE LOGS (Press Ctrl+C to stop)"
    echo ""
    
    # Start all monitoring services
    start_docker_monitoring
    start_system_monitoring
    start_file_monitoring
    
    # Wait for all background processes
    wait
}

# Handle cleanup on exit
cleanup() {
    print_info "Shutting down log watcher..."
    # Kill all background processes
    jobs -p | xargs -r kill
    exit 0
}

# Set up signal handlers
trap cleanup SIGINT SIGTERM

# Run main function
main "$@"