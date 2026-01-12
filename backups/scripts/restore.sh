#!/bin/bash
# =============================================================================
# QSights Restore Script
# =============================================================================
# This script restores from backups:
# - Database (PostgreSQL)
# - Code from snapshots
# - Environment files
# - Media/uploads
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

# List available backups
list_backups() {
    echo ""
    echo "=== Available Database Backups ==="
    ls -lh "${BACKUP_DIR}/database/"*.sql 2>/dev/null | awk '{print $9, $5, $6, $7, $8}' || echo "No database backups found"
    
    echo ""
    echo "=== Available Code Snapshots ==="
    ls -lh "${BACKUP_DIR}/code-snapshots/"*.tar.gz 2>/dev/null | awk '{print $9, $5, $6, $7, $8}' || echo "No code snapshots found"
    
    echo ""
    echo "=== Available Media Backups ==="
    ls -d "${BACKUP_DIR}/media/"*/ 2>/dev/null || echo "No media backups found"
}

# Restore database
restore_database() {
    local BACKUP_FILE="$1"
    
    if [ -z "${BACKUP_FILE}" ]; then
        # Find the latest backup
        BACKUP_FILE=$(ls -t "${BACKUP_DIR}/database/"*.sql 2>/dev/null | head -1)
        if [ -z "${BACKUP_FILE}" ]; then
            log_error "No database backup found!"
            exit 1
        fi
    fi
    
    log_info "Restoring database from: ${BACKUP_FILE}"
    
    echo -e "${YELLOW}WARNING: This will overwrite the current database!${NC}"
    read -p "Are you sure you want to continue? (yes/no): " confirm
    
    if [ "${confirm}" != "yes" ]; then
        log_info "Restore cancelled"
        exit 0
    fi
    
    export PGPASSWORD="${DB_PASSWORD}"
    
    # Check if it's a custom format or plain SQL
    if [[ "${BACKUP_FILE}" == *.plain.sql ]]; then
        # Plain SQL restore
        psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" -f "${BACKUP_FILE}"
    else
        # Custom format restore
        pg_restore -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" -c --if-exists "${BACKUP_FILE}" 2>/dev/null || true
    fi
    
    unset PGPASSWORD
    
    log_success "Database restored successfully!"
}

# Restore code from snapshot
restore_code() {
    local BACKUP_FILE="$1"
    
    if [ -z "${BACKUP_FILE}" ]; then
        BACKUP_FILE=$(ls -t "${BACKUP_DIR}/code-snapshots/"*.tar.gz 2>/dev/null | head -1)
        if [ -z "${BACKUP_FILE}" ]; then
            log_error "No code snapshot found!"
            exit 1
        fi
    fi
    
    log_info "Restoring code from: ${BACKUP_FILE}"
    
    echo -e "${YELLOW}WARNING: This will overwrite the current code!${NC}"
    read -p "Are you sure you want to continue? (yes/no): " confirm
    
    if [ "${confirm}" != "yes" ]; then
        log_info "Restore cancelled"
        exit 0
    fi
    
    # Extract to project root
    tar -xzf "${BACKUP_FILE}" -C "${PROJECT_ROOT}"
    
    log_success "Code restored successfully!"
    log_info "Remember to run 'npm install' in frontend and 'composer install' in backend"
}

# Restore environment files
restore_env() {
    log_info "Restoring environment files..."
    
    if [ -f "${BACKUP_DIR}/env-files/frontend.env" ]; then
        cp "${BACKUP_DIR}/env-files/frontend.env" "${FRONTEND_DIR}/.env"
        log_success "Frontend .env restored"
    fi
    
    if [ -f "${BACKUP_DIR}/env-files/frontend.env.local" ]; then
        cp "${BACKUP_DIR}/env-files/frontend.env.local" "${FRONTEND_DIR}/.env.local"
        log_success "Frontend .env.local restored"
    fi
    
    if [ -f "${BACKUP_DIR}/env-files/backend.env" ]; then
        cp "${BACKUP_DIR}/env-files/backend.env" "${BACKEND_DIR}/.env"
        log_success "Backend .env restored"
    fi
    
    log_success "Environment files restored!"
}

# Restore media to production
restore_media() {
    local MEDIA_DIR="$1"
    
    if [ -z "${MEDIA_DIR}" ]; then
        MEDIA_DIR=$(ls -td "${BACKUP_DIR}/media/"*/ 2>/dev/null | head -1)
        if [ -z "${MEDIA_DIR}" ]; then
            log_error "No media backup found!"
            exit 1
        fi
    fi
    
    log_info "Restoring media from: ${MEDIA_DIR}"
    
    echo -e "${YELLOW}WARNING: This will upload media to production server!${NC}"
    read -p "Are you sure you want to continue? (yes/no): " confirm
    
    if [ "${confirm}" != "yes" ]; then
        log_info "Restore cancelled"
        exit 0
    fi
    
    scp -i "${SSH_KEY}" -r "${MEDIA_DIR}"/* "${PROD_SERVER}:${PROD_BACKEND}/storage/app/public/"
    
    log_success "Media restored to production!"
}

# Full restore
full_restore() {
    log_warning "This will perform a FULL restore of database, code, and environment files!"
    read -p "Are you absolutely sure? Type 'RESTORE' to confirm: " confirm
    
    if [ "${confirm}" != "RESTORE" ]; then
        log_info "Full restore cancelled"
        exit 0
    fi
    
    restore_database
    restore_code
    restore_env
    
    log_success "Full restore completed!"
}

# Main
main() {
    echo ""
    echo "=============================================="
    echo "       QSights Restore System"
    echo "=============================================="
    echo ""
    
    case "${1:-help}" in
        database|db)
            restore_database "$2"
            ;;
        code)
            restore_code "$2"
            ;;
        env)
            restore_env
            ;;
        media)
            restore_media "$2"
            ;;
        full)
            full_restore
            ;;
        list)
            list_backups
            ;;
        *)
            echo "Usage: $0 [command] [backup_file]"
            echo ""
            echo "Commands:"
            echo "  database [file]  - Restore PostgreSQL database"
            echo "  code [file]      - Restore code from snapshot"
            echo "  env              - Restore environment files"
            echo "  media [dir]      - Restore media to production"
            echo "  full             - Full restore (database + code + env)"
            echo "  list             - List available backups"
            echo ""
            echo "Examples:"
            echo "  $0 list"
            echo "  $0 database"
            echo "  $0 database backups/database/qsights_db_20260112.sql"
            exit 1
            ;;
    esac
}

main "$@"
