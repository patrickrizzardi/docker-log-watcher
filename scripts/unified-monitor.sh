#!/bin/bash

# Unified Log Monitor
# Handles both system services and file system monitoring with inotify

# Source common functions
source /app/scripts/common.sh

# Configuration from environment variables (set in Dockerfile)
# SYSTEM_CHECK_INTERVAL, ENABLE_SYSTEM_MONITORING, ENABLE_FILE_MONITORING
CHECK_INTERVAL=$SYSTEM_CHECK_INTERVAL
ENABLE_SYSTEM_SERVICES=$ENABLE_SYSTEM_MONITORING
ENABLE_FILE_SYSTEM=$ENABLE_FILE_MONITORING

# Auto-detect log directories from mounted volumes
detect_log_directories() {
    local log_dirs=()
    
    # Check common log directories that might be mounted
    for dir in "/var/log" "/opt/logs" "/app/logs" "/custom/logs" "/monitoring/logs"; do
        if [ -d "$dir" ] && [ -r "$dir" ]; then
            log_dirs+=("$dir")
        fi
    done
    
    # If no directories found, use defaults
    if [ ${#log_dirs[@]} -eq 0 ]; then
        log_dirs=("/var/log")
    fi
    
    echo "${log_dirs[@]}"
}

# Get log directories
LOG_DIRS=($(detect_log_directories))

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

# Function to start file system monitoring with inotify
start_file_monitoring() {
    print_info "Starting file system monitoring with inotify..."
    
    # Start monitoring existing log files
    scan_log_directories "FILE" "${LOG_DIRS[@]}"
    
    # Use inotify for instant detection
    if command -v inotifywait > /dev/null 2>&1; then
        for log_dir in "${LOG_DIRS[@]}"; do
            if [ -d "$log_dir" ]; then
                inotifywait -m -r -e create,modify,moved_to,delete "$log_dir" 2>/dev/null | while read -r directory events filename; do
                    if [[ "$filename" == *.log ]]; then
                        log_file="$directory$filename"
                        
                        case "$events" in
                            "CREATE"|"MOVED_TO")
                                print_info "New log file detected: $log_file"
                                start_log_monitoring "$log_file" "FILE"
                                ;;
                            "MODIFY")
                                if ! is_monitoring "tail -[fF].*$log_file"; then
                                    print_info "Log file modified (possible rotation): $log_file"
                                    start_log_monitoring "$log_file" "FILE"
                                fi
                                ;;
                            "DELETE")
                                print_info "Log file deleted: $log_file"
                                pkill -f "tail -[fF].*$log_file" 2>/dev/null || true
                                ;;
                        esac
                    fi
                done &
            fi
        done
    else
        print_warning "inotify not available, using fast polling fallback"
        start_polling_monitoring
    fi
}

# Function for polling-based monitoring (fallback)
start_polling_monitoring() {
    while true; do
        sleep "$CHECK_INTERVAL"
        
        # Check for new log files
        scan_log_directories "FILE" "${LOG_DIRS[@]}"
        
        # Check for log rotation on existing files
        for log_dir in "${LOG_DIRS[@]}"; do
            if [ -d "$log_dir" ]; then
                find "$log_dir" -name "*.log" -type f 2>/dev/null | while read -r log_file; do
                    if [ -f "$log_file" ] && ! is_monitoring "tail -[fF].*$log_file"; then
                        print_info "New log file detected (polling): $log_file"
                        start_log_monitoring "$log_file" "FILE"
                    fi
                done
            fi
        done
    done
}

# Function to monitor for new system services
monitor_system_services() {
    while true; do
        sleep "$CHECK_INTERVAL"
        
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
    print_info "Starting unified log monitoring..."
    print_info "Detected log directories: ${LOG_DIRS[*]}"
    
    # Start system service monitoring (if enabled)
    if [ "$ENABLE_SYSTEM_SERVICES" = "true" ]; then
        start_system_services
    else
        print_info "System service monitoring disabled via ENABLE_SYSTEM_MONITORING"
    fi
    
    # Start file system monitoring (if enabled)
    if [ "$ENABLE_FILE_SYSTEM" = "true" ]; then
        start_file_monitoring
    else
        print_info "File system monitoring disabled via ENABLE_FILE_MONITORING"
    fi
    
    # Monitor for new system services in background (if enabled)
    if [ "$ENABLE_SYSTEM_SERVICES" = "true" ]; then
        monitor_system_services &
    fi
    
    # Wait for all background processes
    wait
}

# Run main function
main "$@"
