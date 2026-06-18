#!/usr/bin/env bash

# ==============================================================================
# DATABASE BACKUP SCRIPT WITH RETENTION POLICY
# ==============================================================================
# This script executes a pg_dump backup on the Postgres container, compresses
# it, and enforces a Grandfather-Father-Son (daily/weekly/monthly) retention:
# - Keep 7 daily backups
# - Keep 4 weekly backups
# - Keep 6 monthly backups
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

log_error() {
    echo -e "${RED}[ERROR]$(date +'%Y-%m-%d %H:%M:%S')${NC} $1" >&2
}

# Navigate to project root
cd "$(dirname "$0")/.."

# Load environment variables
if [ -f .env ]; then
    # Filter lines that start with variables and export them
    export $(grep -v '^#' .env | xargs)
else
    log_error ".env file not found. Cannot perform backup."
    exit 1
fi

# Configuration variables
BACKUP_DIR=${BACKUP_DIR:-./postgres/backups}
DB_USER=${DB_USER:-shlink_db_user}
DB_NAME=${DB_NAME:-shlink_db}
DATE=$(date +'%Y-%m-%d')
DAY_OF_WEEK=$(date +'%u')  # 1 (Monday) to 7 (Sunday)
DAY_OF_MONTH=$(date +'%d') # 01 to 31

# Ensure backup directory exists
mkdir -p "$BACKUP_DIR"

log_info "Starting database backup..."

# Verify database container is running
if ! docker ps --format '{{.Names}}' | grep -q 'shlink-db'; then
    log_error "PostgreSQL container (shlink-db) is not running! Cannot take backup."
    exit 1
fi

DAILY_FILE="$BACKUP_DIR/shlink-backup-daily-$DATE.dump"

# Run pg_dump inside the container (using Custom format -F c, which is compressed)
log_info "Creating pg_dump archive..."
if docker exec -t shlink-db pg_dump -U "$DB_USER" -d "$DB_NAME" -F c > "$DAILY_FILE"; then
    log_info "Daily backup created successfully: $DAILY_FILE"
else
    log_error "Database dump failed!"
    exit 1
fi

# Weekly backup on Sundays (day 7)
if [ "$DAY_OF_WEEK" -eq 7 ]; then
    WEEKLY_FILE="$BACKUP_DIR/shlink-backup-weekly-$DATE.dump"
    log_info "Today is Sunday. Copying to weekly backup..."
    cp "$DAILY_FILE" "$WEEKLY_FILE"
fi

# Monthly backup on 1st of month (day 01)
if [ "$DAY_OF_MONTH" = "01" ]; then
    MONTHLY_FILE="$BACKUP_DIR/shlink-backup-monthly-$DATE.dump"
    log_info "Today is the 1st of the month. Copying to monthly backup..."
    cp "$DAILY_FILE" "$MONTHLY_FILE"
fi

# --- RETENTION POLICY ---
log_info "Enforcing retention policy..."

# Keep 7 daily backups (mtime +7 means older than 7 days)
log_info "Purging daily backups older than 7 days..."
find "$BACKUP_DIR" -name "shlink-backup-daily-*" -type f -mtime +7 -exec rm -v {} \;

# Keep 4 weekly backups (mtime +28 means older than 28 days)
log_info "Purging weekly backups older than 28 days..."
find "$BACKUP_DIR" -name "shlink-backup-weekly-*" -type f -mtime +28 -exec rm -v {} \;

# Keep 6 monthly backups (mtime +180 means older than 180 days)
log_info "Purging monthly backups older than 180 days..."
find "$BACKUP_DIR" -name "shlink-backup-monthly-*" -type f -mtime +180 -exec rm -v {} \;

log_info "Backup and rotation completed successfully."

# --- CLOUD UPLOADS (OPTIONAL EXPLANATION) ---
# To upload to AWS S3, install the AWS CLI and uncomment below:
# aws s3 cp "$DAILY_FILE" "s3://your-bucket-name/shlink/daily/$(basename "$DAILY_FILE")"
#
# To upload to Backblaze B2, install the B2 CLI or rclone and uncomment below:
# rclone copy "$DAILY_FILE" "b2:your-bucket-name/shlink/daily"
