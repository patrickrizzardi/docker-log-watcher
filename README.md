# 🐳 Docker Log Watcher

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

**Universal Real-time Log Monitoring for Docker Containers & System Services**

A comprehensive Docker Compose setup that monitors both Docker containers and system services with real-time log streaming, intelligent service detection, and automatic log rotation handling.

## 🚀 Features

### Docker Container Monitoring

- **Live streaming** of all Docker container logs using `docker logs -f`
- **Auto-detection** of new containers (configurable interval, default: 0.1s)
- **Smart service classification** based on container names
- **Prevents infinite loops** by excluding itself from monitoring
- **Clean container lifecycle** management with automatic cleanup

### System Service Monitoring

- **Pre-configured services**: nginx, apache2, httpd, mysql, postgresql, redis, mongodb, ssh, system logs
- **Auto-detection** of running services and their log files
- **Real-time monitoring** with configurable intervals
- **Service-specific log paths** for each application

### File System Monitoring

- **Auto-detection** of log directories from mounted volumes
- **Real-time updates** using `inotify` with polling fallback
- **Log rotation handling** with automatic restart
- **Recursive scanning** of subdirectories
- **Only monitors `.log` files** for performance

### Intelligent Service Detection

- **Docker containers** are classified by name patterns:

  - `web` - nginx, web, http containers
  - `api` - api, backend, service containers
  - `database` - db, mysql, postgres, redis, mongo containers
  - `worker` - worker, queue, job containers
  - `cache` - cache, memcache, redis containers
  - `proxy` - proxy, gateway, router containers
  - `monitor` - monitor, metrics, stats containers
  - `frontend` - frontend, ui, client containers
  - `container` - fallback for unknown containers

- **System services** are detected by log file paths:
  - `nginx` - nginx logs
  - `apache` - apache2/httpd logs
  - `mysql` - mysql logs
  - `postgresql` - postgresql logs
  - `redis` - redis logs
  - `auth` - authentication logs
  - `syslog` - system logs
  - `kernel` - kernel logs
  - And many more...

## 📋 Output Format

- **Docker logs**: `[DOCKER:service-type] log message`
- **System logs**: `[SYSTEM:service-name] log message`
- **File logs**: `[FILE:service-name] log message`

## 🛠️ Configuration

### Environment Variables

All configuration is done through environment variables with sensible defaults:

| Variable                   | Default | Description                             |
| -------------------------- | ------- | --------------------------------------- |
| `DOCKER_CHECK_INTERVAL`    | `0.1`   | Seconds between Docker container checks |
| `SYSTEM_CHECK_INTERVAL`    | `0.1`   | Seconds between system service checks   |
| `LOG_TAIL_LINES`           | `50`    | Number of historical log lines to show  |
| `ENABLE_DOCKER_MONITORING` | `true`  | Enable Docker container monitoring      |
| `ENABLE_SYSTEM_MONITORING` | `true`  | Enable system service monitoring        |
| `ENABLE_FILE_MONITORING`   | `true`  | Enable file system monitoring           |

### Usage

#### Basic Usage (with defaults)

```bash
docker compose up --build
```

#### Custom Configuration

```bash
# Using environment variables
ENABLE_DOCKER_MONITORING=false docker compose up

# Using .env file
echo "ENABLE_DOCKER_MONITORING=false" > .env
echo "DOCKER_CHECK_INTERVAL=1.0" >> .env
docker compose up
```

#### Background Mode

```bash
docker compose up -d
```

## 📁 File Structure

```
docker-log-watcher/
├── docker-compose.yml          # Main compose file
├── Dockerfile                  # Custom Alpine image
├── env.example                 # Configuration template
├── scripts/
│   ├── main.sh                # Main orchestrator script
│   ├── common.sh              # Shared utilities and functions
│   └── unified-monitor.sh     # System + file monitoring
└── README.md                  # This file
```

## 🔧 Advanced Configuration

### Custom Log Directories

Mount additional volumes to monitor custom log directories:

```yaml
# docker-compose.yml
volumes:
  - /var/log:/var/log:ro
  - /your/custom/logs:/your/custom/logs:ro
  - /app/logs:/app/logs:ro
```

### Adding New System Services

Edit the `SYSTEM_SERVICES` array in `scripts/unified-monitor.sh`:

```bash
declare -A SYSTEM_SERVICES=(
    ["your-service"]="/path/to/your/logfile.log"
    ["another-service"]="/path/to/another/*.log"
)
```

### Custom Docker Service Detection

Modify the `detect_docker_service()` function in `scripts/main.sh` to add new patterns:

```bash
case "$name_lower" in
    *your-pattern*)
        echo "your-service-type"
        ;;
    # ... existing patterns
esac
```

## 🎯 Use Cases

### Development Environment

```bash
# Fast monitoring with all features enabled
DOCKER_CHECK_INTERVAL=0.1
SYSTEM_CHECK_INTERVAL=0.1
ENABLE_DOCKER_MONITORING=true
ENABLE_SYSTEM_MONITORING=true
ENABLE_FILE_MONITORING=true
```

### Production Environment

```bash
# Slower monitoring, Docker only
DOCKER_CHECK_INTERVAL=1.0
SYSTEM_CHECK_INTERVAL=5.0
ENABLE_DOCKER_MONITORING=true
ENABLE_SYSTEM_MONITORING=false
ENABLE_FILE_MONITORING=false
```

### System Monitoring Only

```bash
# No Docker, just system services
ENABLE_DOCKER_MONITORING=false
ENABLE_SYSTEM_MONITORING=true
ENABLE_FILE_MONITORING=true
```

## 🔍 Monitoring Behavior

### Docker Container Monitoring

- **Real-time streaming** using `docker logs -f --follow`
- **Container lifecycle** - automatically starts/stops monitoring
- **Service classification** - intelligent naming based on container names
- **Self-exclusion** - never monitors itself

### System Service Monitoring

- **Process detection** - checks if services are actually running
- **Log file validation** - only monitors existing, readable files
- **Service-specific paths** - each service has predefined log locations
- **Auto-restart** - handles log rotation automatically

### File System Monitoring

- **Volume-based detection** - scans mounted volumes automatically
- **Real-time updates** - uses `inotify` for instant detection
- **Polling fallback** - 0.1s intervals if `inotify` unavailable
- **Log rotation** - automatically handles rotated files
- **Recursive scanning** - monitors subdirectories

## 🚨 Troubleshooting

### No Docker Access

```
[ERROR] Cannot access Docker daemon. Make sure Docker socket is mounted.
```

**Solution**: Ensure `/var/run/docker.sock` is properly mounted

### Missing Log Files

```
[WARN] Log file not found for service-name: /path/to/logfile.log
```

**Solution**: This is normal - the watcher will continue monitoring available files

### Performance Issues

- Increase `DOCKER_CHECK_INTERVAL` and `SYSTEM_CHECK_INTERVAL`
- Disable unused monitoring types
- Use specific log directories instead of broad monitoring

## 🔒 Security Notes

- **Read-only mounts** - All system directories mounted read-only
- **Docker socket** - Mounted read-only for safety
- **Process isolation** - Runs in containerized environment
- **Minimal permissions** - Only reads logs, never modifies

## 📊 Example Output

```
╔══════════════════════════════════════════════════════════════════════════════╗
║ 🐳 DOCKER LOG WATCHER 2024-01-15 10:30:15 ║
╚══════════════════════════════════════════════════════════════════════════════╝

📊 CONTAINER STATUS
NAMES                    STATUS              PORTS
example-api-1       Up 10 minutes       0.0.0.0:5000->5000/tcp
example-db-1        Up 10 minutes       0.0.0.0:3306->3306/tcp

📊 CONFIGURATION
Docker monitoring: true (interval: 0.1s)
System monitoring: true (interval: 0.1s)
File monitoring: true
Log tail lines: 50

📊 LIVE LOGS (Press Ctrl+C to stop)

[DOCKER:api] Processing request...
[DOCKER:database] Connection established
[SYSTEM:nginx] 192.168.1.100 - GET /api/data
[SYSTEM:mysql] [Note] Server ready for connections
[FILE:redis] Redis server started
```

## 🎉 Getting Started

1. **Clone or download** this repository
2. **Run with defaults**: `docker compose up --build`
3. **Customize** by creating a `.env` file (see `env.example`)
4. **Monitor your logs** in real-time!

The log watcher will automatically detect and start monitoring all your Docker containers and system services. No configuration needed to get started!
