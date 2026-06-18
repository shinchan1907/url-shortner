# Shlink Installation & Deployment Guide

This guide covers the initial deployment of a production-grade self-hosted Shlink URL shortener on a clean Ubuntu 24.04 LTS VPS (such as AWS Lightsail, EC2, DigitalOcean, or Linode).

---

## 1. Prerequisites & Host System Setup

Log into your fresh VPS instance as `root` (or a user with `sudo` access).

### 1.1 Update the OS Packages
First, update the package repository index and upgrade all installed packages to ensure security patches are applied:
```bash
sudo apt update && sudo apt upgrade -y
```

### 1.2 Configure Host Firewall (UFW)
For security, only SSH (port 22) and Web traffic (ports 80 & 443) should be allowed into the host. Run the following commands:
```bash
# Allow SSH
sudo ufw allow 22/tcp

# Allow HTTP and HTTPS
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw allow 443/udp # Required for HTTP/3

# Enable Firewall
sudo ufw enable
```
*Type `y` and press Enter when prompted to enable the firewall.*

Check UFW status:
```bash
sudo ufw status verbose
```

---

## 2. Install Docker & Docker Compose

We have provided a automated installation script that sets up the official Docker repository and installs Docker Engine and the Docker Compose plugin.

1. Clone or copy this repository into your target folder on the server (e.g., `/opt/shlink-production`).
2. Make scripts executable:
   ```bash
   chmod +x scripts/*.sh
   ```
3. Run the installer:
   ```bash
   sudo ./scripts/install-docker.sh
   ```
4. Log out of your terminal and log back in, or run the following command to apply the docker group changes to your current terminal session:
   ```bash
   newgrp docker
   ```

---

## 3. Configuration Setup (.env)

Shlink reads all database secrets, credentials, and settings from a `.env` file at the project root.

1. Copy the example configuration file:
   ```bash
   cp .env.example .env
   ```
2. Open the `.env` file with a text editor (e.g., `nano`):
   ```bash
   nano .env
   ```
3. Generate a strong password for your database:
   ```bash
   openssl rand -hex 24
   ```
   *Copy this output and set it as `DB_PASSWORD`.*
4. Generate a secure secret key for Shlink:
   ```bash
   openssl rand -base64 48
   ```
   *Copy this output and set it as `SHLINK_SECRET_KEY`.*
5. Set `SHLINK_DOMAIN` to your short URL domain (e.g. `arogy.am`).
6. Set `LETSENCRYPT_EMAIL` to your administrative email address (crucial for certificate warnings).
7. Save the file (`Ctrl + O`, then `Enter`, then `Ctrl + X` to exit nano).

---

## 4. Deploying the Stack

Once the `.env` configuration is complete, run the deployment script:
```bash
./scripts/deploy.sh
```

This script will:
1. Validate the syntax of the `docker-compose.yml` file.
2. Pull the required image tags (`shlinkio/shlink:stable`, `postgres:16-alpine`, `caddy:2.7-alpine`).
3. Start the containers.
4. Wait for containers to pass health checks.
5. **Automatically generate your first administrative Shlink API Key** and display it in the console.

> [!IMPORTANT]
> Save the API Key displayed in the terminal! You will need it to connect to the Shlink Web Client to manage your URLs.

---

## 5. Verification & Post-Installation Checks

1. Verify that all 3 containers are running and healthy:
   ```bash
   ./scripts/health-check.sh
   ```
2. Inspect logs if any errors are reported:
   ```bash
   ./scripts/logs.sh --lines 50
   ```
3. Check that your domain resolves and SSL is working by navigating to:
   `https://<your-short-domain>/rest/health` in your browser. It should return a JSON response stating status `ok`.
