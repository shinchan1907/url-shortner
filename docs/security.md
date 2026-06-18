# Security Hardening & Best Practices

This guide outlines security practices applied to this Shlink infrastructure and steps to secure your host server.

---

## 1. Stack-Level Security (Automated)

### 1.1 Network Isolation
Containers are separated into two distinct networks:
- **`shlink_public_net`**: Only Caddy and Shlink are connected. Caddy can receive public requests on ports 80/443 and proxy them to Shlink.
- **`shlink_private_net`**: Only Shlink and Postgres are connected. It is configured as `internal: true`, which blocks all external incoming/outgoing internet access. The database is isolated from direct access.

### 1.2 Minimizing Exposed Ports
Only Caddy publishes ports to the host interface (`80:80` and `443:443`). PostgreSQL and Shlink ports are kept entirely internal within Docker networks, protecting them from automated scanner bots.

### 1.3 Security Headers
The Caddy proxy automatically appends strict headers to all HTTP responses:
- `Strict-Transport-Security` (forces HTTPS connection)
- `X-Frame-Options: DENY` (prevents clickjacking)
- `X-Content-Type-Options: nosniff` (mitigates MIME-type sniffing)
- Obfuscation: Strips standard headers like `Server` and `X-Powered-By`.

---

## 2. SSH Server Hardening

To secure the Ubuntu VPS host from unauthorized entry, harden the SSH configuration.

### 2.1 Use SSH Key Authentication (Mandatory)
Ensure you can log in using SSH keys before turning off password logins.
On your local computer, generate a key pair:
```bash
ssh-keygen -t ed25519 -C "admin@shlink-server"
```
Copy it to the server:
```bash
ssh-copy-id -i ~/.ssh/id_ed25519.pub user@your_server_ip
```

### 2.2 Disable Password Authentication and Root Login
Edit the SSH configuration file:
```bash
sudo nano /etc/ssh/sshd_config
```
Modify or add the following lines:
```text
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
```
Save and exit. Restart the SSH service:
```bash
sudo systemctl restart sshd
```

> [!WARNING]
> Keep your current SSH terminal window open while testing your connection in a new terminal window to avoid locking yourself out.

---

## 3. Fail2Ban Installation & Configuration

Fail2Ban monitors log files and automatically bans IPs that show malicious behavior (e.g. brute forcing).

### 3.1 Install Fail2Ban
```bash
sudo apt install fail2ban -y
```

### 3.2 Configure SSH Jail
Create a local jail configuration:
```bash
sudo cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
sudo systemctl start fail2ban
sudo systemctl enable fail2ban
```

### 3.3 Configure Caddy Jail (Optional)
To block IPs brute-forcing API endpoints, configure Caddy logs to write to the host, and set up a custom Fail2Ban filter to monitor `/var/log/caddy/shlink_access.log`.

Create a filter rule:
```bash
sudo nano /etc/fail2ban/filter.d/caddy-auth.conf
```
Add:
```text
[Definition]
failregex = ^.*"request":\{"method":"[A-Z]+","uri":"/rest/v2/.*".*"status":401.*"remote_ip":"<HOST>".*$
```
Enable the jail in `/etc/fail2ban/jail.local`:
```text
[caddy-auth]
enabled = true
port = http,https
filter = caddy-auth
logpath = /opt/shlink-production/caddy/logs/shlink_access.log
maxretry = 5
findtime = 600
bantime = 3600
```
Restart Fail2Ban:
```bash
sudo systemctl restart fail2ban
```
