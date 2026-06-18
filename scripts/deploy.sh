#!/usr/bin/env bash

# ==============================================================================
# DEPLOYMENT SCRIPT FOR SHLINK INFRASTRUCTURE
# ==============================================================================
# This script handles the startup, validation, and initialization of the
# Shlink Production environment. It ensures everything is running and healthy.
# ==============================================================================

set -o errexit
set -o pipefail
set -o nounset

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0;37m'

log_info() {
    echo -e "${GREEN}[INFO]$(date +'%Y-%m-%d %H:%M:%S')${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]$(date +'%Y-%m-%d %H:%M:%S')${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]$(date +'%Y-%m-%d %H:%M:%S')${NC} $1" >&2
}

# Navigate to project root
cd "$(dirname "$0")/.."

log_info "Initializing deployment sequence..."

# 1. Check if .env file exists
if [ ! -f .env ]; then
    log_error "The '.env' file was not found!"
    echo -e "Please run the following commands to configure your environment:"
    echo -e "  cp .env.example .env"
    echo -e "  nano .env  # Update with your custom configuration"
    exit 1
fi

# 2. Check if Docker and Compose are installed
if ! command -v docker &> /dev/null; then
    log_error "Docker is not installed. Please run: sudo ./scripts/install-docker.sh"
    exit 1
fi

# 3. Create required local directories if they don't exist
log_info "Creating required folders..."
mkdir -p caddy/configs
mkdir -p postgres/backups

# Ensure permissions on backups directory
chmod 750 postgres/backups

# 4. Validate Docker Compose syntax
log_info "Validating docker-compose configuration..."
docker compose config > /dev/null

# 5. Pull latest container images
log_info "Pulling container images..."
docker compose pull

# 6. Start the stack
log_info "Starting Docker Compose services..."
docker compose up -d

# 7. Monitor health checks
log_info "Waiting for services to become healthy..."
MAX_ATTEMPTS=20
ATTEMPT=1
ALL_HEALTHY=false

while [ $ATTEMPT -le $MAX_ATTEMPTS ]; do
    log_info "Health check attempt $ATTEMPT/$MAX_ATTEMPTS..."
    
    # Check if all containers are healthy or running
    UNHEALTHY_SERVICES=$(docker compose ps --format json | grep -E '"HealthStatus":"(unhealthy|starting)"' || true)
    RUNNING_SERVICES=$(docker compose ps --format json | grep -E '"State":"running"' || true)
    
    # Count total expected services (should be 3: caddy, shlink, postgres)
    TOTAL_RUNNING=$(docker compose ps --format json | grep -c '"State":"running"' || true)
    
    if [ -z "$UNHEALTHY_SERVICES" ] && [ "$TOTAL_RUNNING" -eq 3 ]; then
        log_info "All containers (Postgres, Shlink, Caddy) are healthy!"
        ALL_HEALTHY=true
        break
    fi
    
    sleep 5
    ATTEMPT=$((ATTEMPT + 1))
done

if [ "$ALL_HEALTHY" = false ]; then
    log_error "Some services failed to start or pass health checks."
    log_warn "Current container status:"
    docker compose ps
    log_warn "Check container logs with: ./scripts/logs.sh"
    exit 1
fi

# 8. Post-deployment initialization: Generate Shlink API key if needed
log_info "Configuring Shlink system..."

# Check if there are already active API keys in the database.
# We run the command inside the container.
# If shlink api-key:list returns no keys, we generate the first one.
API_KEYS=$(docker exec -t shlink-engine shlink api-key:list 2>/dev/null || true)

if echo "$API_KEYS" | grep -q "No API keys found"; then
    log_info "No API keys found. Generating first admin API key..."
    ADMIN_KEY=$(docker exec -t shlink-engine shlink api-key:generate)
    echo -e "\n=========================================================================="
    echo -e "${GREEN}INITIALIZATION SUCCESSFUL!${NC}"
    echo -e "=========================================================================="
    echo -e "Your primary Shlink Admin API key is:"
    echo -e "${BLUE}${ADMIN_KEY}${NC}"
    echo -e "Save this key securely! You will need it to connect to the Web Client."
    echo -e "==========================================================================\n"
else
    log_info "Existing API keys found. Skipping automatic key generation."
    echo -e "\n=========================================================================="
    echo -e "${GREEN}DEPLOYMENT COMPLETED SUCCESSFULLY!${NC}"
    echo -e "To view your API keys, run:"
    echo -e "  docker exec -it shlink-engine shlink api-key:list"
    echo -e "==========================================================================\n"
fi
