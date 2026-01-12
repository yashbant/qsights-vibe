# QSights Backup System

A comprehensive backup and restore system for the QSights application.

## Directory Structure

```
backups/
├── scripts/
│   ├── backup.sh          # Main backup script
│   ├── restore.sh         # Restore script
│   └── backup-config.sh   # Configuration (NOT committed to git)
├── database/              # PostgreSQL database backups
├── env-files/            # Environment file backups
├── media/                # Media/uploads backups
├── code-snapshots/       # Code snapshots
└── LAST_BACKUP_REPORT.md # Latest backup report
```

## Quick Start

### 1. First-Time Setup

```bash
# Make scripts executable
chmod +x backups/scripts/*.sh

# Create the config file (copy from template)
cp backups/scripts/backup-config.template.sh backups/scripts/backup-config.sh

# Edit with your credentials
nano backups/scripts/backup-config.sh
```

### 2. Database Backup (Requires AWS SSM)

**Terminal 1 - Start SSM Port Forward:**
```bash
aws ssm start-session --region ap-south-1 --target i-0de19fdf0bd6568b5 \
  --document-name AWS-StartPortForwardingSessionToRemoteHost \
  --parameters host="qsights-db.c0vxik9s9ktk.ap-south-1.rds.amazonaws.com",portNumber="5432",localPortNumber="7400"
```

**Terminal 2 - Run Backup:**
```bash
./backups/scripts/backup.sh database
```

### 3. Run Other Backups

```bash
# Environment files only
./backups/scripts/backup.sh env

# Code snapshot only
./backups/scripts/backup.sh code

# Media from production server
./backups/scripts/backup.sh media

# Push to GitHub
./backups/scripts/backup.sh github

# Full backup (requires SSM session running)
./backups/scripts/backup.sh all
```

### 3. Restore from Backup

```bash
# List available backups
./backups/scripts/restore.sh list

# Restore database (latest)
./backups/scripts/restore.sh database

# Restore specific database backup
./backups/scripts/restore.sh database backups/database/qsights_db_20260112.sql

# Restore code
./backups/scripts/restore.sh code

# Restore environment files
./backups/scripts/restore.sh env

# Full restore
./backups/scripts/restore.sh full
```

## Backup Components

| Component | What's Backed Up | Location |
|-----------|------------------|----------|
| Database | PostgreSQL full dump | `backups/database/` |
| Environment | .env files (frontend/backend) | `backups/env-files/` |
| Media | Uploaded files from production | `backups/media/` |
| Code | Frontend + backend (excluding node_modules) | `backups/code-snapshots/` |
| Git | Commits pushed to GitHub | `github.com/yashbant/qsights-vibe` |

## Schedule Recommendations

| Backup Type | Frequency | Command |
|-------------|-----------|---------|
| Database | Daily | `./backups/scripts/backup.sh database` |
| Full Backup | Weekly | `./backups/scripts/backup.sh all` |
| Before Deploy | Every deployment | `./backups/scripts/backup.sh database` |

## Setting Up Automated Backups (cron)

```bash
# Edit crontab
crontab -e

# Add daily database backup at 2 AM
0 2 * * * /Users/yash/Documents/Projects/QSightsOrg2.0/backups/scripts/backup.sh database >> /tmp/qsights-backup.log 2>&1

# Add weekly full backup on Sundays at 3 AM
0 3 * * 0 /Users/yash/Documents/Projects/QSightsOrg2.0/backups/scripts/backup.sh all >> /tmp/qsights-backup.log 2>&1
```

## Security Notes

⚠️ **Important**: The following are NOT committed to git:
- `backup-config.sh` (contains credentials)
- Database backups (contain data)
- Environment files (contain secrets)
- Media files (too large)

## Troubleshooting

### "Permission denied" error
```bash
chmod +x backups/scripts/*.sh
```

### "pg_dump: command not found"
```bash
# macOS
brew install postgresql

# Ubuntu
sudo apt-get install postgresql-client
```

### SSH connection failed for media backup
```bash
# Check SSH key permissions
chmod 600 /path/to/your/key.pem
```

## Recovery Scenarios

### Scenario 1: Database Corruption
```bash
./backups/scripts/restore.sh database
```

### Scenario 2: Accidental Code Deletion
```bash
./backups/scripts/restore.sh code
```

### Scenario 3: Lost Environment Variables
```bash
./backups/scripts/restore.sh env
```

### Scenario 4: Complete System Recovery
```bash
./backups/scripts/restore.sh full
# Then restore media if needed
./backups/scripts/restore.sh media
```
