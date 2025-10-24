#!/bin/bash

# Docker Container Monitor
# Handles monitoring of Docker containers

# Source common functions
source /app/scripts/common.sh

# Function to start monitoring a Docker container
start_docker_monitoring() {
    local container_id="$1"
    local container_name="$2"
    
    if [ "$container_name" != "docker-log-watcher" ]; then
        print_info "Starting Docker log stream for: $container_name"
        # Use docker logs -f with --follow for better reliability
        docker logs -f --tail=0 --follow "$container_id" 2>&1 | while IFS= read -r line; do
            echo -e "${CYAN}[DOCKER:$container_name]${NC} $line"
        done &
    fi
}

# Function to monitor Docker containers lifecycle
monitor_docker_containers() {
    local check_interval="$1"
    
    # Track monitored containers
    MONITORED_CONTAINERS=""
    
    # Start monitoring existing Docker containers
    for container in $(docker ps -q); do
        container_name=$(docker inspect --format='{{.Name}}' "$container" | cut -c2-)
        if [ "$container_name" != "docker-log-watcher" ]; then
            start_docker_monitoring "$container" "$container_name"
            MONITORED_CONTAINERS="$MONITORED_CONTAINERS $container"
        fi
    done
    
    # Monitor for new/stopped containers
    while true; do
        sleep "$check_interval"
        
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
    done
}

# Function to check Docker access and show container status
check_docker_access() {
    if ! docker ps > /dev/null 2>&1; then
        print_error "Cannot access Docker daemon. Make sure Docker socket is mounted."
        exit 1
    fi
}

# Function to display container status
show_container_status() {
    print_section "CONTAINER STATUS"
    docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'
    echo ""
}

# Main function
main() {
    local check_interval="$1"
    
    print_info "Starting Docker container monitoring..."
    
    # Check Docker access and show status
    check_docker_access
    show_container_status
    
    # Start Docker monitoring
    monitor_docker_containers "$check_interval"
}

# Run main function
main "$@"
