#!/bin/bash
# SQLite database backup script to S3
# Usage: bin/backup/s3_backup.sh

set -e

# Configuration
BACKUP_BUCKET="${S3_BACKUP_BUCKET:-castme-backups}"
BACKUP_PREFIX="${S3_BACKUP_PREFIX:-database}"
DB_PATH="/rails/db/production.sqlite3"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="castme_backup_${TIMESTAMP}.sqlite3"
TEMP_BACKUP="/tmp/${BACKUP_FILE}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

echo "Starting SQLite backup to S3..."

# Check if database exists
if [ ! -f "$DB_PATH" ]; then
    echo -e "${RED}Error: Database file not found at ${DB_PATH}${NC}"
    exit 1
fi

# Create backup using SQLite's online backup API
echo "Creating backup..."
sqlite3 "$DB_PATH" ".backup '$TEMP_BACKUP'"

# Compress the backup
echo "Compressing backup..."
gzip "$TEMP_BACKUP"

# Upload to S3
echo "Uploading to S3..."
aws s3 cp "${TEMP_BACKUP}.gz" "s3://${BACKUP_BUCKET}/${BACKUP_PREFIX}/${BACKUP_FILE}.gz"

# Cleanup
rm -f "${TEMP_BACKUP}.gz"

echo -e "${GREEN}Backup completed successfully!${NC}"
echo "Backup location: s3://${BACKUP_BUCKET}/${BACKUP_PREFIX}/${BACKUP_FILE}.gz"

# Remove backups older than 30 days
echo "Cleaning up old backups..."
aws s3 ls "s3://${BACKUP_BUCKET}/${BACKUP_PREFIX}/" | while read -r line; do
    file_date=$(echo "$line" | awk '{print $1}')
    file_name=$(echo "$line" | awk '{print $4}')

    if [ -n "$file_date" ] && [ -n "$file_name" ]; then
        file_timestamp=$(date -d "$file_date" +%s 2>/dev/null || echo 0)
        cutoff_timestamp=$(date -d "30 days ago" +%s 2>/dev/null || echo 0)

        if [ "$file_timestamp" -lt "$cutoff_timestamp" ] && [ "$file_timestamp" -gt 0 ]; then
            echo "Removing old backup: $file_name"
            aws s3 rm "s3://${BACKUP_BUCKET}/${BACKUP_PREFIX}/${file_name}"
        fi
    fi
done

echo "Backup process completed."
