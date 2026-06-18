#!/usr/bin/env bash

# ==============================================================================
# INSTALL DOCKER ENGINE & DOCKER COMPOSE ON UBUNTU 24.04 LTS
# ==============================================================================
# This script automates the installation of Docker Engine, containerd, and the
# Docker Compose plugin from official Docker repositories.
# ==============================================================================

set -o errexit
set -o pipefail
set -o nounset

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0;37m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]$(date +'%Y-%m-%d %H:%M:%S')${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]$(date +'%Y-%m-%d %H:%M:%S')${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]$(date +'%Y-%m-%d %H:%M:%S')${NC} $1" >&2
}

# Verify running as root
if [ "$EUID" -ne 0 ]; then
    log_error "This script must be run as root. Please run: sudo ./install-docker.sh"
    exit 1
fi

log_info "Starting Docker installation on Ubuntu 24.04..."

# 1. Update package list and install prerequisites
log_info "Updating system packages..."
apt-get update -y
apt-get install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    software-properties-common

# 2. Add Docker's official GPG key
log_info "Adding Docker official GPG key..."
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -y -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

# 3. Set up the repository
log_info "Setting up Docker stable repository..."
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  tee /etc/apt/sources.list.d/docker.list > /dev/null

# 4. Install Docker Engine, containerd, and Docker Compose
log_info "Installing Docker Engine and Docker Compose..."
apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# 5. Start and enable services
log_info "Enabling and starting Docker service..."
systemctl enable docker
systemctl start docker

# 6. Verify installation
log_info "Verifying installations..."
DOCKER_VER=$(docker --version)
COMPOSE_VER=$(docker compose version)

log_info "Installed: $DOCKER_VER"
log_info "Installed: $COMPOSE_VER"

# 7. Post-installation steps (User group addition)
SUDO_USER_NAME=${SUDO_USER:-}
if [ -n "$SUDO_USER_NAME" ] && [ "$SUDO_USER_NAME" != "root" ]; then
    log_info "Adding user '$SUDO_USER_NAME' to the 'docker' group to run commands without sudo..."
    usermod -aG docker "$SUDO_USER_NAME"
    log_warn "You must log out and log back in (or run 'newgrp docker') for group changes to take effect."
fi

log_info "Docker Engine and Docker Compose installation completed successfully!"
