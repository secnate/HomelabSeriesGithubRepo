# Homelab #18 — Disaster Recovery Runbook

**Last Updated:** March 2026  
**Author:** Nathan Pavlovsky  
**Setup:** Three-VM homelab — **haproxy1** (192.168.253.101), 
**haproxy2** (192.168.253.102), **web1** (192.168.253.103)

---

## Overview

Backups are taken daily at 2AM via systemd timer on web1.
Data is encrypted client-side by restic before leaving the machine.
The data backups are stored in AWS S3 primary bucket (us-east-1) and automatically 
replicated to DR bucket (us-east-2) via cross-region replication.

---

## Recovery Metrics

| Metric | Value |
|--------|-------|
| RPO | 24 hours (daily systemd timer) |
| RTO (single file) | < 5 minutes (estimated) |
| RTO (full directory) | < 5 minutes (estimated) |
| Restore integrity | 100% (sha256sum verified) |

---

## Prerequisites

Before attempting any restore you will need:
- AWS credentials for the restic-backup-agent IAM user
- The restic repository password
- Primary S3 bucket: nathan-homelab-18-primary-bucket (us-east-1)
- DR S3 bucket: nathan-homelab-18-secondary-bucket (us-east-2)

Set up the credentials file on the recovery machine:
```bash
sudo nano /etc/restic-env
# Add the following:
# export AWS_DEFAULT_REGION="us-east-1"
# export AWS_ACCESS_KEY_ID="<restic-backup-agent access key>"
# export AWS_SECRET_ACCESS_KEY="<restic-backup-agent secret key>"
# export RESTIC_REPOSITORY="s3:https://s3.amazonaws.com/nathan-homelab-18-primary-bucket"
# export RESTIC_PASSWORD="<repository password>"

sudo chown root:root /etc/restic-env
sudo chmod 600 /etc/restic-env
```

---

## Step 1 — Verify The Repository Is Accessible

Always run this first before attempting any restore:
```bash
source /etc/restic-env && restic snapshots
```

You should see a list of available snapshots.
If this fails, check credentials and network connectivity to S3.

If the primary bucket is unreachable, switch to the DR bucket:
```bash
sudo nano /etc/restic-env
# Change RESTIC_REPOSITORY to:
# s3:https://s3.amazonaws.com/nathan-homelab-18-secondary-bucket
# Change AWS_DEFAULT_REGION to us-east-2
```

---

## Step 2 — Identify The Correct Snapshot
```
source /etc/restic-env && restic snapshots
```

Use `latest` to restore from the most recent snapshot.
Use a specific snapshot ID for point-in-time recovery.
Snapshot IDs are the short alphanumeric strings in the first column.

---

## Restore Procedure 1: Single File
```bash
# Create a staging directory
sudo mkdir -p /restore/staging

# Restore the specific file
source /etc/restic-env && restic restore latest \
    --target /restore/staging \
    --include "/path/to/file"

# Verify hash matches original
sha256sum /restore/staging/path/to/file

# If verified, move into place
sudo mv /restore/staging/path/to/file /path/to/file

# Clean up
sudo rm -rf /restore/staging
```

---

## Restore Procedure 2: Full Directory
```bash
# Restore the directory directly to its original location
source /etc/restic-env && restic restore latest \
    --target / \
    --include "/path/to/directory"

# Verify a representative sample of files
sha256sum /path/to/directory/file1
sha256sum /path/to/directory/file2
```

---

## Restore Procedure 3: Database Backup Files (web1)

The SQLite database on web1 is dumped to 
/home/nathan/database_backups before each backup by the 
resticprofile pre-backup hook. To restore it:
```bash
# Restore the database backups directory
source /etc/restic-env && restic restore latest \
    --target / \
    --include "/home/nathan/database_backups"

# Verify the database is intact and queryable
sqlite3 /home/nathan/database_backups/*.db "SELECT * FROM addresses;"
```

---

## Restore Procedure 4: Failover To DR Bucket

If the primary S3 bucket in us-east-1 is unavailable:
```bash
sudo nano /etc/restic-env
# Change these two lines:
# RESTIC_REPOSITORY=s3:https://s3.amazonaws.com/nathan-homelab-18-secondary-bucket
# AWS_DEFAULT_REGION=us-east-2
```

Then follow any of the restore procedures above as normal.
The DR bucket is a complete replica of the primary bucket
updated automatically via S3 cross-region replication.

---

## Checking Backup Logs

To see the full history of every backup run:
```bash
journalctl -u restic-backup.service --no-pager | more
```

To filter for failures only:
```bash
journalctl -u restic-backup.service --no-pager | grep -i "failed|error"
```

---

## Checking Backup Alerts

Backup success and failure is monitored via **healthchecks.io**.
A failure alert will fire if the backup service does not 
successfully ping healthchecks.io within the expected window.
Log in to healthchecks.io to check the status dashboard.

---

## Restore Test Log

Update this table every time a restore test is performed:

| Test | Date | Snapshot Used | Result |
|------|------|---------------|--------|
| Single file restore | March 2026 | 8e65ace0 | Pass ✓ |
| Directory restore | March 2026 | 8e65ace0 | Pass ✓ |
| Database queryability | March 2026 | 8e65ace0 | Pass ✓ |
| DR bucket failover | — | — | Not Tested |