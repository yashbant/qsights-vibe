#!/bin/bash
# =============================================================================
# QSights Full Backup Script
# =============================================================================
# This script creates a complete backup of:
# - Frontend code
# - Backend code
# - Database (PostgreSQL)
# - Environment files
# - Media/uploads
# - Pushes to GitHub repository
# =============================================================================

set -e  # Exit on error

# Load configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/backup-config.sh"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Create backup directories
setup_backup_dirs() {
    log_info "Setting up backup directories..."
    mkdir -p "${BACKUP_DIR}/database"
    mkdir -p "${BACKUP_DIR}/media"
    mkdir -p "${BACKUP_DIR}/env-files"
    mkdir -p "${BACKUP_DIR}/code-snapshots"
    log_success "Backup directories created"
}

# Backup Database
backup_database() {
    log_info "Backing up PostgreSQL database..."
    
    local SQL_BACKUP_FILE="${BACKUP_DIR}/database/qsights_db_${TIMESTAMP}.plain.sql"
    
    # Check if SSM port forward is already running on LOCAL_DB_PORT
    if ! lsof -i:${LOCAL_DB_PORT} >/dev/null 2>&1; then
        log_warning "AWS SSM port forward not running on port ${LOCAL_DB_PORT}"
        log_info "Please start the SSM session first with:"
        echo ""
        echo "  aws ssm start-session --region ${AWS_REGION} --target ${EC2_INSTANCE_ID} \\"
        echo "    --document-name AWS-StartPortForwardingSessionToRemoteHost \\"
        echo "    --parameters host=\"${DB_HOST}\",portNumber=\"${DB_PORT}\",localPortNumber=\"${LOCAL_DB_PORT}\""
        echo ""
        log_info "Then run this backup again in another terminal."
        return 1
    fi
    
    log_info "SSM port forward detected on port ${LOCAL_DB_PORT}"
    
    # Use PostgreSQL 17 pg_dump to match server version
    local PG_DUMP="/opt/homebrew/opt/postgresql@17/bin/pg_dump"
    if [ ! -f "${PG_DUMP}" ]; then
        PG_DUMP="pg_dump"  # Fallback to system pg_dump
    fi
    
    # Set password for pg_dump
    export PGPASSWORD="${DB_PASSWORD}"
    
    # Dump database through the SSM tunnel
    if "${PG_DUMP}" -h localhost -p "${LOCAL_DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" --no-owner --no-acl -f "${SQL_BACKUP_FILE}" 2>/dev/null; then
        
        # Check if backup file has content
        if [ -s "${SQL_BACKUP_FILE}" ]; then
            log_success "Database backed up to: ${SQL_BACKUP_FILE}"
            
            # Get file size
            local SIZE=$(ls -lh "${SQL_BACKUP_FILE}" | awk '{print $5}')
            log_info "Backup size: ${SIZE}"
        else
            log_error "Database backup file is empty!"
            rm -f "${SQL_BACKUP_FILE}"
            unset PGPASSWORD
            return 1
        fi
    else
        log_error "Database backup failed!"
        unset PGPASSWORD
        return 1
    fi
    
    unset PGPASSWORD
    
    # Keep only last N backups
    log_info "Cleaning old database backups (keeping last ${KEEP_BACKUPS})..."
    ls -t "${BACKUP_DIR}/database/"*.sql 2>/dev/null | tail -n +$((KEEP_BACKUPS + 1)) | xargs -r rm -f
}

# Backup Environment Files
backup_env_files() {
    log_info "Backing up environment files..."
    
    # Frontend .env files
    if [ -f "${FRONTEND_DIR}/.env" ]; then
        cp "${FRONTEND_DIR}/.env" "${BACKUP_DIR}/env-files/frontend.env"
        log_success "Frontend .env backed up"
    fi
    
    if [ -f "${FRONTEND_DIR}/.env.local" ]; then
        cp "${FRONTEND_DIR}/.env.local" "${BACKUP_DIR}/env-files/frontend.env.local"
        log_success "Frontend .env.local backed up"
    fi
    
    if [ -f "${FRONTEND_DIR}/.env.production" ]; then
        cp "${FRONTEND_DIR}/.env.production" "${BACKUP_DIR}/env-files/frontend.env.production"
        log_success "Frontend .env.production backed up"
    fi
    
    # Backend .env files
    if [ -f "${BACKEND_DIR}/.env" ]; then
        cp "${BACKEND_DIR}/.env" "${BACKUP_DIR}/env-files/backend.env"
        log_success "Backend .env backed up"
    fi
    
    # Backup from production server
    log_info "Backing up production environment files..."
    ssh -i "${SSH_KEY}" "${PROD_SERVER}" "cat ${PROD_BACKEND}/.env 2>/dev/null" > "${BACKUP_DIR}/env-files/production-backend.env" 2>/dev/null || log_warning "Could not backup production backend .env"
}

# Backup Media/Uploads from Production
backup_media() {
    log_info "Backing up media/uploads from production server..."
    
    # Create media backup directory with timestamp
    local MEDIA_BACKUP="${BACKUP_DIR}/media/uploads_${TIMESTAMP}"
    mkdir -p "${MEDIA_BACKUP}"
    
    # Sync uploads from production
    if scp -i "${SSH_KEY}" -r "${PROD_SERVER}:${PROD_BACKEND}/storage/app/public/*" "${MEDIA_BACKUP}/" 2>/dev/null; then
        log_success "Media files backed up to: ${MEDIA_BACKUP}"
    else
        log_warning "No media files found or backup failed"
    fi
}

# Create code snapshot
create_code_snapshot() {
    log_info "Creating code snapshot..."
    
    local SNAPSHOT_FILE="${BACKUP_DIR}/code-snapshots/qsights_code_${TIMESTAMP}.tar.gz"
    
    # Create tarball excluding node_modules, vendor, .next, etc.
    tar -czf "${SNAPSHOT_FILE}" \
        --exclude='node_modules' \
        --exclude='vendor' \
        --exclude='.next' \
        --exclude='.git' \
        --exclude='*.log' \
        --exclude='backups/database' \
        --exclude='backups/media' \
        --exclude='backups/code-snapshots' \
        -C "${PROJECT_ROOT}" \
        frontend backend 2>/dev/null
    
    log_success "Code snapshot created: ${SNAPSHOT_FILE}"
    
    # Keep only last N snapshots
    log_info "Cleaning old code snapshots (keeping last ${KEEP_BACKUPS})..."
    ls -t "${BACKUP_DIR}/code-snapshots/"*.tar.gz 2>/dev/null | tail -n +$((KEEP_BACKUPS + 1)) | xargs -r rm -f
}

# Push to GitHub
push_to_github() {
    log_info "Pushing to GitHub repository..."
    
    cd "${PROJECT_ROOT}"
    
    # Configure git with token
    git remote set-url origin "https://${GITHUB_TOKEN}@github.com/${GITHUB_USER}/${GITHUB_REPO}.git" 2>/dev/null || \
    git remote add origin "https://${GITHUB_TOKEN}@github.com/${GITHUB_USER}/${GITHUB_REPO}.git" 2>/dev/null || true
    
    # Add all changes
    git add -A
    
    # Commit with timestamp
    git commit -m "Backup: ${TIMESTAMP} - Auto backup of QSights application" 2>/dev/null || log_warning "Nothing to commit"
    
    # Push to GitHub
    if git push -u origin main 2>/dev/null || git push -u origin master 2>/dev/null; then
        log_success "Successfully pushed to GitHub: https://github.com/${GITHUB_USER}/${GITHUB_REPO}"
    else
        log_warning "Push failed - trying to set up repository..."
        git branch -M main
        git push -u origin main 2>/dev/null || log_error "Failed to push to GitHub"
    fi
}

# Generate backup report
generate_report() {
    local REPORT_FILE="${BACKUP_DIR}/LAST_BACKUP_REPORT.md"
    
    cat > "${REPORT_FILE}" << EOF
# QSights Backup Report

**Backup Date:** $(date '+%Y-%m-%d %H:%M:%S')
**Backup ID:** ${TIMESTAMP}

## Backup Contents

### Database
- Location: \`backups/database/qsights_db_${TIMESTAMP}.sql\`
- Format: PostgreSQL custom format + Plain SQL

### Environment Files
- Location: \`backups/env-files/\`
- Frontend: .env, .env.local, .env.production
- Backend: .env
- Production: production-backend.env

### Media/Uploads
- Location: \`backups/media/uploads_${TIMESTAMP}/\`

### Code Snapshot
- Location: \`backups/code-snapshots/qsights_code_${TIMESTAMP}.tar.gz\`

## Database Connection Details
- Host: ${DB_HOST}
- Port: ${DB_PORT}
- Database: ${DB_NAME}
- User: ${DB_USER}

## Production Server
- Server: ${PROD_SERVER}
- Frontend: ${PROD_FRONTEND}
- Backend: ${PROD_BACKEND}

## GitHub Repository
- URL: https://github.com/${GITHUB_USER}/${GITHUB_REPO}

## How to Restore

### Restore Database:
\`\`\`bash
./backups/scripts/restore.sh database backups/database/qsights_db_${TIMESTAMP}.sql
\`\`\`

### Restore Code:
\`\`\`bash
./backups/scripts/restore.sh code backups/code-snapshots/qsights_code_${TIMESTAMP}.tar.gz
\`\`\`

### Full Restore:
\`\`\`bash
./backups/scripts/restore.sh full
\`\`\`
EOF
    
    log_success "Backup report generated: ${REPORT_FILE}"
}

# Main execution
main() {
    echo ""
    echo "=============================================="
    echo "       QSights Full Backup System"
    echo "=============================================="
    echo "Timestamp: ${TIMESTAMP}"
    echo ""
    
    setup_backup_dirs
    
    # Parse arguments
    case "${1:-all}" in
        database|db)
            backup_database
            ;;
        env)
            backup_env_files
            ;;
        media)
            backup_media
            ;;
        code)
            create_code_snapshot
            ;;
        github|git)
            push_to_github
            ;;
        all)
            backup_database
            backup_env_files
            backup_media
            create_code_snapshot
            generate_report
            push_to_github
            ;;
        *)
            echo "Usage: $0 [database|env|media|code|github|all]"
            echo ""
            echo "Options:"
            echo "  database  - Backup PostgreSQL database only"
            echo "  env       - Backup environment files only"
            echo "  media     - Backup media/uploads only"
            echo "  code      - Create code snapshot only"
            echo "  github    - Push to GitHub only"
            echo "  all       - Full backup (default)"
            exit 1
            ;;
    esac
    
    echo ""
    echo "=============================================="
    log_success "Backup completed successfully!"
    echo "=============================================="
}

main "$@"
