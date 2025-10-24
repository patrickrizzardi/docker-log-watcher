#!/bin/bash

# Advanced Log Watcher - Main Script
# Monitors both Docker containers and system services

set -e

# Colors and formatting
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# Configuration from environment variables (set in Dockerfile)
# DOCKER_CHECK_INTERVAL, SYSTEM_CHECK_INTERVAL, LOG_TAIL_LINES
# ENABLE_DOCKER_MONITORING, ENABLE_SYSTEM_MONITORING, ENABLE_FILE_MONITORING

# Function to print colored output
print_header() {
    echo -e "${BLUE}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC} ${YELLOW}🐳 ADVANCED LOG WATCHER${NC} ${BLUE}$(date '+%Y-%m-%d %H:%M:%S')${NC} ${BLUE}║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_section() {
    echo -e "${CYAN}📊 $1${NC}"
}

print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to detect Docker service type from container name
detect_docker_service() {
    local container_name="$1"
    
    # Convert container name to lowercase for pattern matching
    local name_lower=$(echo "$container_name" | tr '[:upper:]' '[:lower:]')
    
    case "$name_lower" in
        *nginx*|*web*|*http*)
            echo "web"
            ;;
        *api*|*backend*|*service*)
            echo "api"
            ;;
        *db*|*database*|*mysql*|*postgres*|*redis*|*mongo*)
            echo "database"
            ;;
        *worker*|*queue*|*job*)
            echo "worker"
            ;;
        *cache*|*memcache*|*redis*)
            echo "cache"
            ;;
        *proxy*|*gateway*|*router*)
            echo "proxy"
            ;;
        *monitor*|*metrics*|*stats*)
            echo "monitor"
            ;;
        *frontend*|*ui*|*client*)
            echo "frontend"
            ;;
        *)
            echo "container"
            ;;
    esac
}

# Function to start monitoring a Docker container
start_docker_monitoring() {
    local container_id="$1"
    local container_name="$2"
    
    if [ "$container_name" != "docker-log-watcher" ]; then
        local service_type=$(detect_docker_service "$container_name")
        print_info "Starting Docker log stream for: $container_name ($service_type)"
        # Use docker logs -f with --follow for better reliability
        docker logs -f --tail=0 --follow "$container_id" 2>&1 | sed "s/^/[DOCKER:$service_type] /" &
    fi
}

# Function to start monitoring a system service
start_system_monitoring() {
    local service_name="$1"
    local log_path="$2"
    
    if [ -f "$log_path" ]; then
        print_info "Starting system log stream for: $service_name"
        tail -f "$log_path" 2>/dev/null | sed "s/^/[SYSTEM:$service_name] /" &
    else
        print_warning "Log file not found for $service_name: $log_path"
    fi
}

# Function to check if a process is already running
is_monitoring() {
    local pattern="$1"
    pgrep -f "$pattern" > /dev/null 2>&1
}

# Main execution
main() {
    print_header
    
    # Check if we have Docker access
    if ! docker ps > /dev/null 2>&1; then
        print_error "Cannot access Docker daemon. Make sure Docker socket is mounted."
        exit 1
    fi
    
    print_section "CONTAINER STATUS"
    docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'
    echo ""
    
    # Show configuration
    print_section "CONFIGURATION"
    echo "Docker monitoring: $ENABLE_DOCKER_MONITORING (interval: ${DOCKER_CHECK_INTERVAL}s)"
    echo "System monitoring: $ENABLE_SYSTEM_MONITORING (interval: ${SYSTEM_CHECK_INTERVAL}s)"
    echo "File monitoring: $ENABLE_FILE_MONITORING"
    echo "Log tail lines: $LOG_TAIL_LINES"
    echo ""
    
    print_section "LIVE LOGS (Press Ctrl+C to stop)"
    echo ""
    
    # Track monitored containers
    MONITORED_CONTAINERS=""
    
    # Start monitoring existing Docker containers (if enabled)
    if [ "$ENABLE_DOCKER_MONITORING" = "true" ]; then
        for container in $(docker ps -q); do
            container_name=$(docker inspect --format='{{.Name}}' "$container" | cut -c2-)
            if [ "$container_name" != "docker-log-watcher" ]; then
                start_docker_monitoring "$container" "$container_name"
                MONITORED_CONTAINERS="$MONITORED_CONTAINERS $container"
            fi
        done
    else
        print_info "Docker monitoring disabled via ENABLE_DOCKER_MONITORING"
    fi
    
    # Start unified monitoring (system services + file system) if enabled
    if [ "$ENABLE_SYSTEM_MONITORING" = "true" ] || [ "$ENABLE_FILE_MONITORING" = "true" ]; then
        /app/scripts/unified-monitor.sh &
    else
        print_info "System monitoring disabled via ENABLE_SYSTEM_MONITORING and ENABLE_FILE_MONITORING"
    fi
    
    # Monitor for new Docker containers (if enabled)
    if [ "$ENABLE_DOCKER_MONITORING" = "true" ]; then
        while true; do
            sleep "$DOCKER_CHECK_INTERVAL"
            
            # Get currently running containers
            current_containers=$(docker ps -q)
            
            # Check for new containers
            for container in $current_containers; do
                container_name=$(docker inspect --format='{{.Name}}' "$container" | cut -c2-)
                if [ "$container_name" != "docker-log-watcher" ]; then
                    if ! echo "$MONITORED_CONTAINERS" | grep -q " $container "; then
                        print_info "New Docker container detected: $container_name"
                        start_docker_monitoring "$container" "$container_name"
                        MONITORED_CONTAINERS="$MONITORED_CONTAINERS $container"
                    fi
                fi
            done
            
            # Check for stopped containers and clean up
            new_monitored=""
            for container in $MONITORED_CONTAINERS; do
                if echo "$current_containers" | grep -q "^$container$"; then
                    # Container is still running
                    new_monitored="$new_monitored $container"
                else
                    # Container stopped, kill its monitoring process
                    print_info "Container stopped, cleaning up monitoring for: $container"
                    pkill -f "docker logs -f $container" 2>/dev/null || true
                fi
            done
            MONITORED_CONTAINERS="$new_monitored"
        done &
    fi
    
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
