#!/bin/bash
# ------------------------------------------------------------------
# Icarus Backup - Encrypted backup of persistent overlay.
# Usage: icarus-backup.sh /dev/sdX1  (external backup partition)
# ------------------------------------------------------------------
set -euo pipefail

BACKUP_DEV="${1:-}"
if [ -z "$BACKUP_DEV" ] || [ ! -b "$BACKUP_DEV" ]; then
    echo "Usage: $0 /dev/sdX1"
    exit 1
fi

BACKUP_MNT="/mnt/backup"
SOURCE_DIR="/overlay_upper"        # persistent overlay upper directory
SNAPSHOT_NAME="icarus-backup-$(date +%Y%m%d-%H%M%S).tar.gz.gpg"

mount "$BACKUP_DEV" "$BACKUP_MNT"

echo "Creating encrypted backup..."
tar -czf - -C "$SOURCE_DIR" . | gpg --symmetric --cipher-algo AES256 \
    --output "$BACKUP_MNT/$SNAPSHOT_NAME"

echo "Backup saved to $BACKUP_MNT/$SNAPSHOT_NAME"
umount "$BACKUP_MNT"