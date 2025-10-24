FROM alpine:latest

# Install required packages
RUN apk add --no-cache \
    docker-cli \
    procps \
    grep \
    sed \
    coreutils \
    bash \
    inotify-tools

# Create app directory
WORKDIR /app

# Copy scripts
COPY scripts/ /app/scripts/
RUN chmod +x /app/scripts/*.sh

# Set environment variable defaults
ENV DOCKER_CHECK_INTERVAL=0.1
ENV SYSTEM_CHECK_INTERVAL=0.1
ENV LOG_TAIL_LINES=50
ENV ENABLE_DOCKER_MONITORING=true
ENV ENABLE_SYSTEM_MONITORING=true
ENV ENABLE_FILE_MONITORING=true

# Set the main script as entrypoint
ENTRYPOINT ["/app/scripts/main.sh"]
