#!/usr/bin/env bash

# ==============================================================================
# LOGS INSPECTION SCRIPT
# ==============================================================================
# This script simplifies viewing and tailing logs from the Docker Compose stack.
# Usage: ./scripts/logs.sh [caddy|shlink|postgres|all] [-f|--follow] [--lines <N>]
# ==============================================================================

set -o errexit
set -o pipefail
set -o nounset

# Colors for output
RED='\033[0;31m'
NC='\033[0;37m'

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

# Navigate to project root
cd "$(dirname "$0")/.."

# Check if Docker Compose is running in this directory
if [ ! -f docker-compose.yml ]; then
    log_error "docker-compose.yml not found. Please run this from the project root."
    exit 1
fi

SERVICE=""
FOLLOW=""
LINES="100"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        caddy|shlink|postgres|all)
            if [ "$1" != "all" ]; then
                SERVICE="$1"
            fi
            shift
            ;;
        -f|--follow)
            FOLLOW="--follow"
            shift
            ;;
        --lines)
            LINES="$2"
            shift 2
            ;;
        *)
            log_error "Unknown argument: $1"
            echo "Usage: $0 [caddy|shlink|postgres|all] [-f|--follow] [--lines <N>]"
            exit 1
            ;;
    esac
done

# Run docker compose logs
docker compose logs --tail="$LINES" $FOLLOW $SERVICE
