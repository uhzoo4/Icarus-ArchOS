#!/bin/bash
# ------------------------------------------------------------------
# Icarus Memory Tiering Daemon
# Tiers: Hot (RAM) -> Warm (zram) -> Cold (zswap+SSD)
# Uses zram recompression and swap priority to move pages.
# This script relies on existing zram device (zram0) and a small
# SSD swap partition (/dev/disk/by-label/COLD_SWAP).
# ------------------------------------------------------------------
set -u

# --- Configuration ---
COLD_SWAP_LABEL="COLD_SWAP"   # Label of the SSD swap partition
ZRAM_DEV="/dev/zram0"
ZRAM_SYSFS="/sys/block/zram0"
POLL_INTERVAL=10               # seconds

# Priority: zram high (32767), SSD low (0)
ZRAM_PRIO=32767
SSD_PRIO=0

# Watermarks (percentage of total compressed pages)
PROMOTE_THRESHOLD=30           # if zram usage < 30%, move from cold to zram
DEMOTE_THRESHOLD=70            # if zram usage > 70%, move from zram to cold

# --- Helper functions ---
log() { echo "[MemTierd] $(date '+%H:%M:%S') $*"; }

get_zram_compressed_pages() {
    # Number of pages currently stored in zram (compressed)
    local pages=$(cat "$ZRAM_SYSFS/mm_stat" 2>/dev/null | awk '{print $2}')
    echo "${pages:-0}"
}

get_zram_max_pages() {
    # Maximum number of pages zram can hold (based on disk size)
    local disksize=$(cat "$ZRAM_SYSFS/disksize" 2>/dev/null)
    # 4096 bytes per page
    echo $(( disksize / 4096 ))
}

get_swap_usage() {
    # For a given swap device, return used pages
    local dev="$1"
    awk -v dev="$dev" '$1 == dev {print $4}' /proc/swaps
}

# --- Core actions ---
enable_zram() {
    # Assumes zram0 already exists; just set priority
    if swapon --show | grep -q "$ZRAM_DEV"; then
        log "zram already active."
    else
        log "Activating zram as hot swap with priority $ZRAM_PRIO."
        mkswap "$ZRAM_DEV" && swapon -p "$ZRAM_PRIO" "$ZRAM_DEV"
    fi
}

enable_cold_swap() {
    local part=$(blkid -L "$COLD_SWAP_LABEL")
    if [ -z "$part" ]; then
        log "Cold swap partition not found. Skipping cold tier."
        return 1
    fi
    if swapon --show | grep -q "$part"; then
        log "Cold swap already active."
    else
        log "Activating cold swap on $part with priority $SSD_PRIO."
        swapon -p "$SSD_PRIO" "$part"
    fi
}

rebalance_tiers() {
    local zram_used=$(get_zram_compressed_pages)
    local zram_max=$(get_zram_max_pages)
    if [ "$zram_max" -eq 0 ]; then
        return
    fi
    local usage_pct=$(( zram_used * 100 / zram_max ))

    if [ "$usage_pct" -gt "$DEMOTE_THRESHOLD" ]; then
        log "zram usage ${usage_pct}% > ${DEMOTE_THRESHOLD}%. Demoting pages to cold swap."
        # echo 1 > "$ZRAM_SYSFS/writeback" triggers writeback of idle pages
        echo 1 > "$ZRAM_SYSFS/writeback" 2>/dev/null || true
    elif [ "$usage_pct" -lt "$PROMOTE_THRESHOLD" ]; then
        log "zram usage ${usage_pct}% < ${PROMOTE_THRESHOLD}%. Promoting cold pages if any."
        # Swapoff/on cold device to force pages back to RAM, then zram will recompress
        local cold_part=$(blkid -L "$COLD_SWAP_LABEL")
        if [ -n "$cold_part" ] && swapon --show | grep -q "$cold_part"; then
            swapoff "$cold_part" && swapon -p "$SSD_PRIO" "$cold_part"
        fi
    fi
}

# --- Main loop ---
log "Memory Tiering Daemon starting."

# Ensure zram is active (the generator should have created it)
enable_zram
enable_cold_swap

while true; do
    rebalance_tiers
    sleep "$POLL_INTERVAL"
done
