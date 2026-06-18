# Backup & Disaster Recovery Strategy

Having a reliable, automated database backup and restore strategy is critical for production operations. Shlink store all user configurations, custom domains, links, and click analytics in the PostgreSQL database.

---

## 1. Backup Strategy

We implement a **Grandfather-Father-Son (GFS)** backup retention policy.
- **Daily backups**: Stored for **7 days**.
- **Weekly backups**: Stored for **4 weeks** (taken on Sundays).
- **Monthly backups**: Stored for **6 months** (taken on the 1st of the month).

The script `scripts/backup.sh` handles the database dump (using PostgreSQL's custom binary format `-F c` which includes compression), names the files accordingly, and purges expired dumps automatically.

---

## 2. Automating Backups with Cron

To automate backups, set up a cron job on your VPS host to execute `backup.sh` daily.

1. Open the crontab for the root user (or a user with docker access):
   ```bash
   sudo crontab -e
   ```
2. Add the following line at the bottom of the file (runs the backup daily at 2:00 AM server time):
   ```text
   0 2 * * * /opt/shlink-production/scripts/backup.sh >> /var/log/shlink-backup.log 2>&1
   ```
   *Make sure to update `/opt/shlink-production` to your actual installation directory.*
3. Save and close the editor. The cron daemon will automatically load the new configuration.

---

## 3. Remote Cloud Storage Uploads (Disaster Recovery)

To protect against physical VPS drive failures, backups should be copied offsite to secure cloud storage.

### 3.1 Upload to AWS S3
1. Install the AWS CLI on the host:
   ```bash
   sudo apt install awscli -y
   ```
2. Configure AWS credentials:
   ```bash
   aws configure
   ```
3. Modify `scripts/backup.sh` to add the sync command near the end:
   ```bash
   # Sync all local backups to your S3 bucket
   aws s3 sync "$BACKUP_DIR" "s3://your-shlink-backups-bucket/db-dumps/" --delete
   ```

### 3.2 Upload to Backblaze B2 (using rclone)
1. Install rclone:
   ```bash
   sudo apt install rclone -y
   ```
2. Configure a new B2 remote (run `rclone config` and follow instructions).
3. Modify `scripts/backup.sh` to sync:
   ```bash
   # Sync all local backups to Backblaze B2
   rclone sync "$BACKUP_DIR" "b2:your-shlink-backups-bucket/db-dumps"
   ```

---

## 4. Database Recovery (Restoration)

If you need to recover from a backup, use the provided `scripts/restore.sh` script.

> [!CAUTION]
> **Warning**: Restoration overwrites all active database data. The script will ask for confirmation before executing.

1. Find the backup file you want to restore in the backups directory (e.g., `./postgres/backups/shlink-backup-daily-2026-06-18.dump`).
2. Run the restore script:
   ```bash
   ./scripts/restore.sh ./postgres/backups/shlink-backup-daily-2026-06-18.dump
   ```
3. Confirm the action when prompted by entering `y`.
4. The script will:
   - Temporarily stop the Shlink container (releasing locks on database tables).
   - Restore the DB structures and data.
   - Restart the Shlink container.
   - Run system health checks.
