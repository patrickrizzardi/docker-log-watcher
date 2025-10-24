#!/bin/bash

# Common functions and utilities for log monitoring

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_section() {
    echo -e "${CYAN}📊 $1${NC}"
}

# Function to check if a process is already running
is_monitoring() {
    local pattern="$1"
    pgrep -f "$pattern" > /dev/null 2>&1
}

# Function to detect service name from log file path
detect_service_name() {
    local log_file="$1"
    local filename=$(basename "$log_file")
    local dirname=$(dirname "$log_file")
    
    # Extract service name from common patterns
    case "$log_file" in
        */nginx/*)
            echo "nginx"
            ;;
        */apache2/*|*/httpd/*)
            echo "apache"
            ;;
        */mysql/*)
            echo "mysql"
            ;;
        */postgresql/*)
            echo "postgresql"
            ;;
        */redis/*)
            echo "redis"
            ;;
        */mongodb/*)
            echo "mongodb"
            ;;
        */auth.log|*/secure)
            echo "auth"
            ;;
        */syslog)
            echo "syslog"
            ;;
        */kern.log)
            echo "kernel"
            ;;
        */cron.log)
            echo "cron"
            ;;
        */mail.log|*/maillog)
            echo "mail"
            ;;
        */daemon.log)
            echo "daemon"
            ;;
        */messages)
            echo "messages"
            ;;
        */bootstrap*)
            echo "bootstrap"
            ;;
        */install*)
            echo "install"
            ;;
        */dpkg*)
            echo "dpkg"
            ;;
        */apt*)
            echo "apt"
            ;;
        */systemd*)
            echo "systemd"
            ;;
        */app/*|*/application/*)
            # Try to extract from directory structure
            local app_dir=$(echo "$dirname" | sed 's|.*/\([^/]*\)/.*|\1|')
            echo "$app_dir"
            ;;
        *)
            # For unknown files, try to be more descriptive
            if [[ "$filename" =~ ^[a-z]+$ ]]; then
                # Single word filenames - use as is
                echo "${filename%.*}"
            else
                # Multi-word or complex filenames - use a generic prefix
                echo "log"
            fi
            ;;
    esac
}

# Function to start monitoring any log file
start_log_monitoring() {
    local log_file="$1"
    local prefix="$2"
    local service_name=$(detect_service_name "$log_file")
    
    if [ -f "$log_file" ] && ! is_monitoring "tail -[fF].*$log_file"; then
        print_info "Starting log stream for: $service_name ($prefix)"
        
        # Choose color based on prefix
        case "$prefix" in
            "SYSTEM")
                color="$GREEN"
                ;;
            "FILE")
                color="$PURPLE"
                ;;
            *)
                color="$WHITE"
                ;;
        esac
        
        tail -F "$log_file" 2>/dev/null | while IFS= read -r line; do
            echo -e "${color}[$prefix:$service_name]${NC} $line"
        done &
        return 0
    else
        return 1
    fi
}

# Function to restart monitoring after log rotation
restart_log_monitoring() {
    local log_file="$1"
    local prefix="$2"
    local service_name=$(detect_service_name "$log_file")
    
    # Kill existing monitoring
    pkill -f "tail -[fF].*$log_file" 2>/dev/null || true
    
    # Start fresh
    if [ -f "$log_file" ]; then
        print_info "Restarting log stream for: $service_name (rotation detected)"
        
        # Choose color based on prefix
        case "$prefix" in
            "SYSTEM")
                color="$GREEN"
                ;;
            "FILE")
                color="$PURPLE"
                ;;
            *)
                color="$WHITE"
                ;;
        esac
        
        tail -F "$log_file" 2>/dev/null | while IFS= read -r line; do
            echo -e "${color}[$prefix:$service_name]${NC} $line"
        done &
        return 0
    else
        return 1
    fi
}

# Function to check if a service is running
is_service_running() {
    local service_name="$1"
    pgrep "$service_name" > /dev/null 2>&1
}


# Function to scan directories for log files
scan_log_directories() {
    local prefix="$1"
    local directories=("${@:2}")
    
    for log_dir in "${directories[@]}"; do
        if [ -d "$log_dir" ]; then
            find "$log_dir" -name "*.log" -type f 2>/dev/null | while read -r log_file; do
                start_log_monitoring "$log_file" "$prefix"
            done
        fi
    done
}

# Function to handle cleanup on exit
cleanup() {
    print_info "Shutting down monitoring..."
    jobs -p | xargs -r kill 2>/dev/null || true
    exit 0
}
