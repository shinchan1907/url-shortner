#!/usr/bin/env bash

# ==============================================================================
# DATABASE RESTORATION SCRIPT
# ==============================================================================
# This script restores a PostgreSQL backup taken with backup.sh.
# It safely shuts down the Shlink engine container during restoration to
# prevent database state conflicts.
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

# Load environment variables
if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
else
    log_error ".env file not found. Cannot perform restore."
    exit 1
fi

DB_USER=${DB_USER:-shlink_db_user}
DB_NAME=${DB_NAME:-shlink_db}

# Check argument
if [ "$#" -lt 1 ]; then
    log_error "Usage: $0 <path-to-backup-file> [--force]"
    echo -e "Example: $0 ./postgres/backups/shlink-backup-daily-2026-06-18.dump"
    exit 1
fi

BACKUP_FILE="$1"
FORCE_RESTORE=false

if [ "${2:-}" = "--force" ] || [ "${2:-}" = "-f" ]; then
    FORCE_RESTORE=true
fi

# Validate file exists
if [ ! -f "$BACKUP_FILE" ]; then
    log_error "Backup file '$BACKUP_FILE' does not exist."
    exit 1
fi

# Confirm action
if [ "$FORCE_RESTORE" = false ]; then
    log_warn "=========================================================================="
    log_warn "WARNING: THIS ACTION WILL OVERWRITE THE CURRENT DATABASE STATE."
    log_warn "=========================================================================="
    echo -n "Are you sure you want to restore from $BACKUP_FILE? (y/N): "
    read -r CONFIRM
    if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
        log_info "Restoration aborted by operator."
        exit 0
    fi
fi

# 1. Stop Shlink container to prevent database writes during restoration
log_info "Stopping Shlink engine container..."
docker compose stop shlink

# 2. Perform restore
log_info "Restoring database from $BACKUP_FILE..."
# pg_restore options:
# -c / --clean: clean (drop) database objects before recreating
# --if-exists: use IF EXISTS when dropping objects
# -d / --dbname: target database name
if docker exec -i shlink-db pg_restore -U "$DB_USER" -d "$DB_NAME" --clean --if-exists < "$BACKUP_FILE"; then
    log_info "Database restored successfully."
else
    log_error "Database restoration failed!"
    log_info "Starting Shlink back up..."
    docker compose start shlink
    exit 1
fi

# 3. Start Shlink container
log_info "Starting Shlink engine container..."
docker compose start shlink

# 4. Perform health checks
log_info "Verifying service health..."
sleep 5
if docker compose ps --format json | grep -E '"HealthStatus":"(unhealthy|starting)"' >/dev/null; then
    log_error "Services are not healthy after restore. Check logs: ./scripts/logs.sh"
    exit 1
else
    log_info "All services are online and healthy. Restoration completed."
fi
