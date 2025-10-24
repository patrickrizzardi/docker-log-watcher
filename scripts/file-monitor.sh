#!/bin/bash

# File System Monitor
# Handles monitoring of log files in mounted directories

# Source common functions
source /app/scripts/common.sh

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

# Function to start file system monitoring with inotify
start_file_monitoring() {
    local log_dirs=("$@")
    
    print_info "Starting file system monitoring with inotify..."
    print_info "Detected log directories: ${log_dirs[*]}"
    
    # Start monitoring existing log files
    scan_log_directories "FILE" "${log_dirs[@]}"
    
    # Use inotify for instant detection
    if command -v inotifywait > /dev/null 2>&1; then
        for log_dir in "${log_dirs[@]}"; do
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
        start_polling_monitoring "${log_dirs[@]}"
    fi
}

# Function for polling-based monitoring (fallback)
start_polling_monitoring() {
    local log_dirs=("$@")
    local check_interval="$SYSTEM_CHECK_INTERVAL"
    
    while true; do
        sleep "$check_interval"
        
        # Check for new log files
        scan_log_directories "FILE" "${log_dirs[@]}"
        
        # Check for log rotation on existing files
        for log_dir in "${log_dirs[@]}"; do
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

# Main function
main() {
    print_info "Starting file system monitoring..."
    
    # Get log directories
    local log_dirs=($(detect_log_directories))
    
    # Start file system monitoring
    start_file_monitoring "${log_dirs[@]}"
    
    # Wait for all background processes
    wait
}

# Run main function
main "$@"
