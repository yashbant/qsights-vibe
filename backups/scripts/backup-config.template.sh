#!/bin/bash
# =============================================================================
# QSights Backup Configuration Template
# =============================================================================
# Copy this file to backup-config.sh and fill in your credentials
# The backup-config.sh file is gitignored and won't be committed
# =============================================================================

# Project paths
export PROJECT_ROOT="/Users/yash/Documents/Projects/QSightsOrg2.0"
export FRONTEND_DIR="${PROJECT_ROOT}/frontend"
export BACKEND_DIR="${PROJECT_ROOT}/backend"
export BACKUP_DIR="${PROJECT_ROOT}/backups"

# Production server
export SSH_KEY="/path/to/your/key.pem"
export PROD_SERVER="ubuntu@your-server-ip"
export PROD_FRONTEND="/var/www/qsights/frontend"
export PROD_BACKEND="/var/www/qsights/backend"

# Database credentials (AWS RDS PostgreSQL)
export DB_HOST="your-db-host.rds.amazonaws.com"
export DB_PORT="5432"
export DB_NAME="your-database"
export DB_USER="your-username"
export DB_PASSWORD="your-password"

# GitHub credentials
export GITHUB_TOKEN="your-github-pat"
export GITHUB_USER="your-github-username"
export GITHUB_REPO="your-repo-name"

# Backup settings
export BACKUP_RETENTION_DAYS=30  # How many days to keep old backups
export COMPRESS_BACKUPS=true     # Whether to compress backups
