# Upgrades & Container Lifecycle Management

Updating containers is necessary to receive security patches and performance improvements. However, database schema migrations and configuration changes can occasionally break services. 

This guide details how to perform updates safely and handle major version upgrades.

---

## 1. Automated Minor/Patch Updates

We have provided an automated update script (`scripts/update.sh`) that safely handles pulling newer images and restarting services.

Run the update script:
```bash
./scripts/update.sh
```

### What this script does under the hood:
1. **Safety Backup**: Runs `scripts/backup.sh` to take a full snapshot of your current database state.
2. **Pull Images**: Pulls latest stable layers for Shlink (`shlink/shlink:stable`), Caddy (`caddy:2.7-alpine`), and PostgreSQL (`postgres:16-alpine`).
3. **Recreate Stack**: Runs `docker compose up -d` to recreate containers with the updated images.
4. **Health Validation**: Monitors the new containers for 50 seconds to verify they stabilize and return healthy HTTP responses.
5. **Rollback (on Failure)**: If the stack becomes unstable or fails health checks, it halts the stack, restores the pre-update database snapshot, and restarts the previous version.

---

## 2. Upgrading Major Versions

### 2.1 Shlink Major Upgrades (e.g., v3.x to v4.x)
Shlink database updates are backward-compatible and migrated automatically at container startup.
1. Read the Shlink Release Notes for breaking changes to environment variables.
2. Edit the `.env` file if new variables are required.
3. Run `./scripts/update.sh` to deploy.

### 2.2 PostgreSQL Major Upgrades (e.g., v15 to v16)
> [!CAUTION]
> **PostgreSQL major versions are not binary-compatible.**
> You cannot upgrade a major PostgreSQL version (e.g. 15.x to 16.x) by simply changing the tag in `docker-compose.yml`. Doing so will cause PostgreSQL to crash and fail to start due to incompatible data directories.

To upgrade PostgreSQL major versions safely:

1. **Perform a Full Backup**:
   Run the backup script to generate a clean, compressed dump:
   ```bash
   ./scripts/backup.sh
   ```
   *Note the filename generated (e.g., `./postgres/backups/shlink-backup-daily-2026-06-18.dump`).*

2. **Stop the Container Stack**:
   ```bash
   docker compose down
   ```

3. **Delete the Old Volume**:
   Delete the Docker volume that contains the incompatible binary data:
   ```bash
   docker volume rm shlink_postgres_data
   ```

4. **Edit docker-compose.yml**:
   Change the postgres image tag to the new major version (e.g., `postgres:16-alpine` to `postgres:17-alpine`):
   ```yaml
     postgres:
       image: postgres:17-alpine
   ```

5. **Start PostgreSQL Container Alone**:
   Start only the postgres container to initialize a blank database:
   ```bash
   docker compose up -d postgres
   ```
   *Wait 10 seconds for initialization.*

6. **Restore the Dump**:
   Restore your backup into the new database container:
   ```bash
   ./scripts/restore.sh ./postgres/backups/shlink-backup-daily-2026-06-18.dump --force
   ```

7. **Start the Rest of the Stack**:
   Start Shlink and Caddy containers:
   ```bash
   docker compose up -d
   ```

8. **Verify System Health**:
   ```bash
   ./scripts/health-check.sh
   ```
