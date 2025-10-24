#!/bin/bash

# System Service Monitor
# Handles monitoring of system services (nginx, apache, mysql, etc.)

# Source common functions
source /app/scripts/common.sh

# Define known system services and their log paths
declare -A SYSTEM_SERVICES=(
    ["nginx"]="/var/log/nginx/access.log /var/log/nginx/error.log"
    ["apache2"]="/var/log/apache2/access.log /var/log/apache2/error.log"
    ["httpd"]="/var/log/httpd/access_log /var/log/httpd/error_log"
    ["ssh"]="/var/log/auth.log"
    ["system"]="/var/log/syslog"
    ["kern"]="/var/log/kern.log"
    ["mysql"]="/var/log/mysql/error.log"
    ["postgresql"]="/var/log/postgresql/postgresql-*.log"
    ["redis"]="/var/log/redis/redis-server.log"
    ["mongodb"]="/var/log/mongodb/mongod.log"
)

# Function to start monitoring system services
start_system_services() {
    print_info "Starting system service monitoring..."
    
    for service in "${!SYSTEM_SERVICES[@]}"; do
        if is_service_running "$service"; then
            log_paths="${SYSTEM_SERVICES[$service]}"
            for log_path in $log_paths; do
                start_log_monitoring "$log_path" "SYSTEM"
            done
        fi
    done
}

# Function to monitor for new system services
monitor_system_services() {
    local check_interval="$1"
    
    while true; do
        sleep "$check_interval"
        
        for service in "${!SYSTEM_SERVICES[@]}"; do
            if is_service_running "$service"; then
                log_paths="${SYSTEM_SERVICES[$service]}"
                for log_path in $log_paths; do
                    if [ -f "$log_path" ] && ! is_monitoring "tail -[fF].*$log_path"; then
                        print_info "New system service detected: $service"
                        start_log_monitoring "$log_path" "SYSTEM"
                    fi
                done
            fi
        done
    done
}

# Main function
main() {
    local check_interval="$1"
    
    print_info "Starting system service monitoring..."
    
    # Start system service monitoring
    start_system_services
    
    # Monitor for new system services in background
    monitor_system_services "$check_interval" &
    
    # Wait for all background processes
    wait
}

# Run main function
main "$@"
