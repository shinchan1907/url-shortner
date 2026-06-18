#!/usr/bin/env bash

# ==============================================================================
# INFRASTRUCTURE HEALTH & MONITORING SCRIPT
# ==============================================================================
# This script monitors host resource usage (CPU, Memory, Disk) and inspects the
# running states, health status, and API responsiveness of the Shlink containers.
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
    echo -e "${GREEN}[OK]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[FAIL]${NC} $1" >&2
}

# Navigate to project root
cd "$(dirname "$0")/.."

# Load environment variables
if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
else
    log_error ".env file not found. Cannot resolve configuration."
    exit 1
fi

SHLINK_DOMAIN=${SHLINK_DOMAIN:-arogy.am}

echo -e "=========================================================================="
echo -e "${BLUE}SHLINK INFRASTRUCTURE HEALTH REPORT - $(date)${NC}"
echo -e "==========================================================================\n"

# ------------------------------------------------------------------------------
# 1. HOST SYSTEM HEALTH
# ------------------------------------------------------------------------------
echo -e "${BLUE}[1/3] Host System Resources:${NC}"

# CPU Load
CPU_LOAD=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}')
if (( $(echo "$CPU_LOAD < 80.0" | bc -l) )); then
    log_info "CPU Usage: $CPU_LOAD% (Healthy)"
else
    log_warn "CPU Usage is high: $CPU_LOAD% (Over 80%)"
fi

# RAM Usage
RAM_TOTAL=$(free -m | awk '/^Mem:/{print $2}')
RAM_USED=$(free -m | awk '/^Mem:/{print $3}')
RAM_FREE=$(free -m | awk '/^Mem:/{print $4}')
RAM_PERCENT=$(awk "BEGIN {print ($RAM_USED/$RAM_TOTAL)*100}")
if (( $(echo "$RAM_PERCENT < 85.0" | bc -l) )); then
    log_info "RAM Usage: $RAM_USED MB / $RAM_TOTAL MB (${RAM_PERCENT:.1f}%)"
else
    log_warn "RAM Usage is high: $RAM_USED MB / $RAM_TOTAL MB (${RAM_PERCENT:.1f}%)"
fi

# SSD Disk Space
DISK_PERCENT=$(df -h / | awk 'NR==2 {print $5}' | sed 's/%//')
DISK_FREE=$(df -h / | awk 'NR==2 {print $4}')
if [ "$DISK_PERCENT" -lt 80 ]; then
    log_info "SSD Storage: $DISK_PERCENT% used ($DISK_FREE free)"
else
    log_error "SSD Storage is critical: $DISK_PERCENT% used ($DISK_FREE free)"
fi

echo -e ""

# ------------------------------------------------------------------------------
# 2. DOCKER CONTAINER STATUSES
# ------------------------------------------------------------------------------
echo -e "${BLUE}[2/3] Docker Stack Status:${NC}"

CONTAINERS=("shlink-db" "shlink-engine" "shlink-caddy")
ALL_CONTAINERS_HEALTHY=true

for CONTAINER in "${CONTAINERS[@]}"; do
    # Check if container exists and get status
    if ! docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER}$"; then
        log_error "Container '$CONTAINER' is NOT created!"
        ALL_CONTAINERS_HEALTHY=false
        continue
    fi
    
    STATE=$(docker inspect --format='{{.State.Status}}' "$CONTAINER")
    HEALTH=$(docker inspect --format='{{if .State.Health}}{{.State.Health.Status}}{{else}}no-healthcheck{{end}}' "$CONTAINER")
    
    if [ "$STATE" = "running" ]; then
        if [ "$HEALTH" = "healthy" ] || [ "$HEALTH" = "no-healthcheck" ]; then
            log_info "Container '$CONTAINER': Running ($HEALTH)"
        else
            log_error "Container '$CONTAINER': Running ($HEALTH)"
            ALL_CONTAINERS_HEALTHY=false
        fi
    else
        log_error "Container '$CONTAINER': State is '$STATE' (Not Running)"
        ALL_CONTAINERS_HEALTHY=false
    fi
done

echo -e ""

# ------------------------------------------------------------------------------
# 3. HTTP / ENDPOINT ACCESSIBILITY
# ------------------------------------------------------------------------------
echo -e "${BLUE}[3/3] Shlink Endpoint Accessibility:${NC}"

# Test internal Shlink REST health endpoint
log_info "Testing internal engine rest API endpoint..."
INTERNAL_HEALTH_CODE=$(docker exec -t shlink-engine wget --spider --server-response http://localhost:8080/rest/health 2>&1 | awk '/HTTP\// {print $2}' | tail -n1 || true)
if [ "$INTERNAL_HEALTH_CODE" = "200" ]; then
    log_info "Internal Engine API Health: HTTP $INTERNAL_HEALTH_CODE (Healthy)"
else
    log_error "Internal Engine API Health: HTTP $INTERNAL_HEALTH_CODE (Unresponsive)"
    ALL_CONTAINERS_HEALTHY=false
fi

# Test external domain HTTPS endpoint (if domain is not arogy.am)
if [ "$SHLINK_DOMAIN" != "arogy.am" ]; then
    log_info "Testing external HTTPS Shlink endpoint (https://$SHLINK_DOMAIN/rest/health)..."
    EXTERNAL_HTTP_CODE=$(curl -o /dev/null -s -w "%{http_code}" --connect-timeout 5 "https://$SHLINK_DOMAIN/rest/health" || true)
    
    if [ "$EXTERNAL_HTTP_CODE" = "200" ]; then
        log_info "External HTTPS API Health: HTTP $EXTERNAL_HTTP_CODE (Online)"
    else
        log_warn "External HTTPS API Health: HTTP $EXTERNAL_HTTP_CODE (Could be dns propagation or firewall issue)"
    fi
else
    log_warn "External HTTP check skipped (default arogy.am is in use)"
fi

echo -e "\n=========================================================================="
if [ "$ALL_CONTAINERS_HEALTHY" = true ]; then
    echo -e "${GREEN}SYSTEM HEALTH STATUS: EXCELLENT${NC}"
else
    echo -e "${RED}SYSTEM HEALTH STATUS: DEGRADED / ISSUES DETECTED${NC}"
    exit 1
fi
echo -e "=========================================================================="
