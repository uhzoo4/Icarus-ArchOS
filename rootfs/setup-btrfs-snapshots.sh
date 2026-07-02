#!/bin/bash
# ------------------------------------------------------------------
# Icarus Btrfs Snapshot Setup
# Creates subvolumes for root and persistent overlay, then configures
# snapper to take hourly snapshots of the overlay.
# Run once after formatting root partition as btrfs.
# ------------------------------------------------------------------
set -euo pipefail

ROOT_MNT="/mnt"
BTRFS_DEV="${1:-/dev/sda2}"   # adjust as needed

mount "$BTRFS_DEV" "$ROOT_MNT"

# Create subvolumes
btrfs subvolume create "$ROOT_MNT/@root"
btrfs subvolume create "$ROOT_MNT/@overlay"

# Unmount and remount properly
umount "$ROOT_MNT"
mount -o subvol=@root "$BTRFS_DEV" "$ROOT_MNT"
mkdir -p "$ROOT_MNT/overlay"
mount -o subvol=@overlay "$BTRFS_DEV" "$ROOT_MNT/overlay"

# Install snapper and configure
pacman -S --noconfirm snapper
snapper -c overlay create-config "$ROOT_MNT/overlay"
# Set hourly snapshots, keep 24 hourly, 7 daily, 4 weekly
sed -i 's/^TIMELINE_CREATE=.*/TIMELINE_CREATE="yes"/' /etc/snapper/configs/overlay
sed -i 's/^HOURLY_CLEANUP=.*/HOURLY_CLEANUP="yes"/' /etc/snapper/configs/overlay
sed -i 's/^TIMELINE_HOURLY=.*/TIMELINE_HOURLY="24"/' /etc/snapper/configs/overlay
sed -i 's/^TIMELINE_DAILY=.*/TIMELINE_DAILY="7"/' /etc/snapper/configs/overlay
sed -i 's/^TIMELINE_WEEKLY=.*/TIMELINE_WEEKLY="4"/' /etc/snapper/configs/overlay
systemctl enable snapper-timeline.timer snapper-cleanup.timer