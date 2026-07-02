#!/bin/bash
# ------------------------------------------------------------------
# Icarus Secure Boot Setup via sbctl
# Prerequisites: UEFI firmware in Setup Mode (no keys enrolled).
# Run this after the kernel and bootloader are installed.
# ------------------------------------------------------------------
set -euo pipefail

log() { echo "[SecureBoot] $*"; }

# Install sbctl if missing
if ! command -v sbctl &>/dev/null; then
    pacman -S --noconfirm sbctl
fi

# 1. Create custom keys
log "Creating Platform Key and Key Exchange Key..."
sbctl create-keys

# 2. Enroll keys into UEFI firmware (requires Setup Mode)
log "Enrolling keys into UEFI firmware..."
sbctl enroll-keys

# 3. Sign the kernel, initramfs, and bootloader EFI binary
log "Signing kernel and bootloader..."
sbctl sign /boot/vmlinuz-linux-icarus
sbctl sign /boot/intel-ucode.img
sbctl sign /boot/initramfs-linux-icarus.img
sbctl sign /usr/lib/systemd/boot/efi/systemd-bootx64.efi
# If using UKI, sign that instead

# 4. Create a Unified Kernel Image (UKI) that bundles everything
log "Generating Unified Kernel Image..."
mkdir -p /efi/EFI/Linux
sbctl bundle --save \
    --kernel /boot/vmlinuz-linux-icarus \
    --initrd /boot/intel-ucode.img \
    --initrd /boot/initramfs-linux-icarus.img \
    --cmdline "root=UUID=$(blkid -s UUID -o value /dev/disk/by-label/ROOT) rw mitigations=off quiet loglevel=0 isolcpus=2,3 nohz_full=2,3 rcu_nocbs=2,3" \
    --output /efi/EFI/Linux/icarus.efi

# 5. Add a boot entry for the UKI
efibootmgr --create --disk /dev/sda --part 1 --label "Icarus Secure" --loader /EFI/Linux/icarus.efi

# 6. Verify signing
log "Verification:"
sbctl verify