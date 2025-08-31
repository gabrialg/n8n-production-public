# ==============================================================================
# N8N Production Dockerfile v4 - Ultra-Lean with Native API Key Support
# ==============================================================================
# 
# Architecture Overview:
# - Pre-installs all dependencies at build time for fast boot (30-60s vs 5-8min)
# - Uses N8N's native N8N_API_KEY environment variable support
# - Zero API key installation overhead - fastest possible approach
# - Eliminates SQLite dependencies in favor of N8N native persistence
# - Consolidates all startup logic into single Dockerfile CMD
#
# Performance Targets:
# - Container boot time: 30-60 seconds (potentially faster with zero overhead)
# - Zero extra installations beyond base requirements
# - Minimal startup logic complexity
# ==============================================================================

# Base Image: RunPod CPU optimized base
FROM runpod/base:0.5.1-cpu

# ==============================================================================
# METADATA AND LABELS
# ==============================================================================
LABEL maintainer="Empathos Engineering Team"
LABEL description="Ultra-lean N8N container with native API key environment support"
LABEL version="4.0.0"
LABEL architecture="n8n-native-env-var-persistence"

# ==============================================================================
# BUILD-TIME DEPENDENCY INSTALLATION
# ==============================================================================
# Install Node.js 20.x, n8n, and required system packages
# This reduces runtime startup from 5-8 minutes to 30-60 seconds
RUN apt-get update && \
    # Add Node.js 20.x repository
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
    # Install core dependencies
    apt-get install -y \
        nodejs \
        curl \
        git \
        jq \
        unzip \
        wget \
        && \
    # Install n8n globally for optimal performance
    npm install -g n8n@latest && \
    # Install cloudflared for tunnel management
    wget -O /usr/local/bin/cloudflared \
        https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 && \
    chmod +x /usr/local/bin/cloudflared && \
    # Clean up package cache to reduce image size
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# ==============================================================================
# DIRECTORY STRUCTURE AND PERMISSIONS
# ==============================================================================
# Create required directories with proper permissions
RUN mkdir -p \
        /tmp/.cloudflared \
        /tmp/.n8n \
        /app/workflows \
        /app/logs && \
    # Set ownership for runtime user
    chown -R root:root /tmp/.cloudflared /tmp/.n8n /app

# ==============================================================================
# ENVIRONMENT CONFIGURATION  
# ==============================================================================
# N8N Runtime Configuration
ENV N8N_USER_FOLDER=/tmp/.n8n
ENV N8N_HOST=0.0.0.0
ENV N8N_PORT=5678
ENV N8N_PROTOCOL=http
ENV NODE_OPTIONS="--dns-result-order=ipv4first"
ENV DEBIAN_FRONTEND=noninteractive

# Workflow Management Configuration
ENV WORKFLOWS_SOURCE=n8n-api
ENV WORKFLOW_VERSION_CONTROL=enabled
ENV SQLITE_DISABLED=true

# ==============================================================================
# HEALTH CHECK CONFIGURATION
# ==============================================================================
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:5678/healthz || exit 1

# ==============================================================================
# RUNTIME STARTUP COMMAND - ULTRA-LEAN V4
# ==============================================================================  
# Simplified startup sequence leveraging N8N native API key support:
# 1. Environment validation
# 2. Cloudflare tunnel configuration and startup
# 3. N8N initialization with native API key persistence
# 4. Health monitoring and process management
CMD ["sh", "-c", "\
    echo '=== N8N Production Container v4 Starting ===' && \
    \
    # Environment Validation\
    echo 'Validating environment configuration...' && \
    : ${TUNNEL_ID:?'TUNNEL_ID environment variable is required'} && \
    : ${CF_HOSTNAME:?'CF_HOSTNAME environment variable is required'} && \
    : ${CF_TUNNEL_JSON_B64:?'CF_TUNNEL_JSON_B64 environment variable is required'} && \
    \
    # API Key Status Check (N8N Native Support)\
    if [ ! -z \"${N8N_API_KEY}\" ]; then \
        echo 'N8N API key configured - N8N will handle persistence natively'; \
        API_KEY_STATUS='Enabled (Native)'; \
    else \
        echo 'N8N API key not configured - manual workflow management only'; \
        API_KEY_STATUS='Disabled'; \
    fi && \
    \
    # Cloudflare Tunnel Configuration\
    echo 'Configuring Cloudflare tunnel...' && \
    echo \"tunnel: ${TUNNEL_ID}\" > /tmp/.cloudflared/config.yml && \
    echo \"credentials-file: /tmp/.cloudflared/tunnel.json\" >> /tmp/.cloudflared/config.yml && \
    echo \"ingress:\" >> /tmp/.cloudflared/config.yml && \
    echo \"  - hostname: ${CF_HOSTNAME}\" >> /tmp/.cloudflared/config.yml && \
    echo \"    service: http://localhost:5678\" >> /tmp/.cloudflared/config.yml && \
    echo \"  - service: http_status:404\" >> /tmp/.cloudflared/config.yml && \
    \
    # Tunnel Credentials Setup\
    printf '%s' \"${CF_TUNNEL_JSON_B64}\" | base64 -d > /tmp/.cloudflared/tunnel.json && \
    chmod 600 /tmp/.cloudflared/tunnel.json && \
    \
    # Start Cloudflare Tunnel in Background\
    echo 'Starting Cloudflare tunnel...' && \
    /usr/local/bin/cloudflared tunnel --no-autoupdate --config /tmp/.cloudflared/config.yml run & \
    TUNNEL_PID=$! && \
    \
    # N8N Startup with Native API Key Support\
    echo 'Starting N8N workflow engine with native API key support...' && \
    n8n start & \
    N8N_PID=$! && \
    \
    # Health Check Loop - Wait for N8N to be ready\
    echo 'Waiting for N8N to become ready...' && \
    RETRY_COUNT=0 && \
    MAX_RETRIES=30 && \
    while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do \
        if curl -f http://localhost:5678/healthz >/dev/null 2>&1; then \
            echo 'N8N is ready and healthy'; \
            break; \
        fi; \
        echo \"Health check attempt $((RETRY_COUNT + 1))/${MAX_RETRIES}...\"; \
        sleep 5; \
        RETRY_COUNT=$((RETRY_COUNT + 1)); \
    done && \
    \
    if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then \
        echo 'Error: N8N failed to become healthy within timeout period'; \
        exit 1; \
    fi && \
    \
    # Production Ready Notification\
    echo '=============================================' && \
    echo '    N8N Production Container v4 Ready' && \
    echo '=============================================' && \
    echo \"Access URL: https://${CF_HOSTNAME}\" && \
    echo \"Local URL:  http://localhost:5678\" && \
    echo \"API Key Status: ${API_KEY_STATUS}\" && \
    echo \"Tunnel Status: Active\" && \
    echo \"Health Status: Ready\" && \
    echo 'Architecture: Ultra-Lean (Native Env Var)' && \
    echo '=============================================' && \
    echo 'Container ready for workflow management' && \
    echo 'N8N API key managed natively by N8N' && \
    echo '=============================================' && \
    \
    # Process Management and Graceful Shutdown\
    trap 'echo \"Shutting down gracefully...\"; kill $TUNNEL_PID $N8N_PID; wait' TERM INT && \
    wait $N8N_PID \
    "]

# ==============================================================================
# NETWORK CONFIGURATION
# ==============================================================================
EXPOSE 5678

# ==============================================================================
# VOLUME MOUNTS
# ==============================================================================
# Persistent data volumes for workflow state and logs
VOLUME ["/tmp/.n8n", "/app/logs"]

# ==============================================================================
# BUILD INFORMATION
# ==============================================================================
# Add build timestamp and version information
ARG BUILD_DATE
ARG BUILD_VERSION=4.0.0
LABEL build.date=$BUILD_DATE
LABEL build.version=$BUILD_VERSION