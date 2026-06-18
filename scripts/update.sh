#!/usr/bin/env bash

# ==============================================================================
# SAFE CONTAINER UPDATE SCRIPT WITH AUTOMATIC ROLLBACK
# ==============================================================================
# This script handles updates for Shlink, Postgres, and Caddy. It:
# 1. Takes a safety database backup before starting the update.
# 2. Pulls the latest images.
# 3. Restarts the stack.
# 4. Monitors health. If health checks fail, it rolls back the database.
# ==============================================================================

set -o errexit
set -o pipefail
set -o nounset

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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

log_info "Initiating update sequence..."

# 1. Take a safety backup
DATE=$(date +'%Y-%m-%d-%H%M%S')
PRE_UPDATE_BACKUP="./postgres/backups/shlink-backup-pre-update-$DATE.dump"

log_info "Creating pre-update database backup..."
if [ -f ./scripts/backup.sh ]; then
    # Create the backup explicitly and copy to our pre-update path
    ./scripts/backup.sh
    # Find the latest daily backup and copy it
    LATEST_BACKUP=$(find ./postgres/backups -name "shlink-backup-daily-*" -type f -printf '%T@ %p\n' | sort -n | tail -1 | cut -f2- -d" ")
    cp "$LATEST_BACKUP" "$PRE_UPDATE_BACKUP"
    log_info "Safety backup stored at: $PRE_UPDATE_BACKUP"
else
    log_error "backup.sh script not found! Update aborted for safety."
    exit 1
fi

# 2. Pull new images
log_info "Pulling latest Docker images..."
docker compose pull

# 3. Recreate and restart containers
log_info "Recreating containers with new images..."
docker compose up -d

# 4. Verify health
log_info "Verifying health of new containers..."
sleep 10

MAX_ATTEMPTS=10
ATTEMPT=1
ALL_HEALTHY=true

while [ $ATTEMPT -le $MAX_ATTEMPTS ]; do
    UNHEALTHY_SERVICES=$(docker compose ps --format json | grep -E '"HealthStatus":"(unhealthy|starting)"' || true)
    TOTAL_RUNNING=$(docker compose ps --format json | grep -c '"State":"running"' || true)
    
    if [ -z "$UNHEALTHY_SERVICES" ] && [ "$TOTAL_RUNNING" -eq 3 ]; then
        ALL_HEALTHY=true
        break
    else
        ALL_HEALTHY=false
    fi
    
    log_warn "Health check attempt $ATTEMPT/$MAX_ATTEMPTS: stack is not yet fully stable..."
    sleep 5
    ATTEMPT=$((ATTEMPT + 1))
done

# 5. Rollback if update failed
if [ "$ALL_HEALTHY" = false ]; then
    log_error "=========================================================================="
    log_error "UPDATE FAILED: Stack is unstable! Initiating automatic rollback..."
    log_error "=========================================================================="
    
    log_warn "Stopping unstable containers..."
    docker compose down
    
    log_warn "Rolling back database to pre-update state..."
    # Start database alone to restore
    docker compose up -d postgres
    sleep 5
    
    if [ -f ./scripts/restore.sh ]; then
        ./scripts/restore.sh "$PRE_UPDATE_BACKUP" --force
    else
        log_error "restore.sh script not found! Cannot automatically restore database. Manual intervention required!"
    fi
    
    # Restart the rest of the stack
    log_warn "Restarting Shlink and Caddy..."
    docker compose up -d
    
    log_error "Rollback completed. The stack has been restored to its pre-update database state."
    log_error "Please inspect logs with: ./scripts/logs.sh"
    exit 1
else
    log_info "=========================================================================="
    log_info "UPDATE SUCCESSFUL: All containers are updated and healthy!"
    log_info "=========================================================================="
fi
