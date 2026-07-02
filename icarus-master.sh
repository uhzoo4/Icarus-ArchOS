#!/bin/bash
# ------------------------------------------------------------------
# Icarus Master Assembly - One command to rule them all.
# Run this on a fresh Arch installation (live ISO, root mounted at /mnt).
# Usage: bash icarus-master.sh /dev/sdX
# ------------------------------------------------------------------
set -euo pipefail

TARGET_DEV="${1:-}"
if [ -z "$TARGET_DEV" ] || [ ! -b "$TARGET_DEV" ]; then
    echo "Usage: $0 /dev/sdX"
    exit 1
fi

echo "=== ICARUS MASTER ASSEMBLY ==="
echo "This process is irreversible and will consume the target disk."
read -p "Are you certain? (yes/no): " CONFIRM
if [ "$CONFIRM" != "yes" ]; then
    echo "Aborted."
    exit 1
fi

# 1. Bootstrap base system
bash icarus-bootstrap.sh "$TARGET_DEV"

# 2. Chroot and complete setup
mount "${TARGET_DEV}2" /mnt
mount "${TARGET_DEV}1" /mnt/boot

arch-chroot /mnt /bin/bash << 'ENDCHROOT'
set -e
cd /home/icarus/icarus-linux

# Build and install kernel
cd kernel
sudo -u icarus makepkg -sf --noconfirm
pacman -U --noconfirm *.pkg.tar.zst
cd ..

# Deploy ram-root and regenerate initramfs
cp initramfs/ram-root-hook /etc/initcpio/hooks/
cp initramfs/ram-root-install /etc/initcpio/install/
sed -i 's/^HOOKS=(.*)/HOOKS=(base udev autodetect modconf block filesystems keyboard fsck ram-root)/' /etc/mkinitcpio.conf
mkinitcpio -p linux-icarus

# Install all configs and services
make install-configs

# Deploy daemons
cp rootfs/icarus-grimoire-keeper.sh rootfs/icarus-tune.sh rootfs/icarus-sentinel.sh \
   rootfs/icarus-memtierd.sh rootfs/icarus-stealth.sh rootfs/icarus-exporter.sh \
   rootfs/icarus-welcome.sh rootfs/icarus-backup.sh /usr/local/bin/

cp rootfs/*.service rootfs/*.timer /etc/systemd/system/
systemctl enable icarus-grimoire.timer icarus-tune.service icarus-sentinel.service \
                 icarus-memtierd.service icarus-stealth.service icarus-exporter.service \
                 icarus-welcome.service

# Plymouth
cd plymouth && bash install-icarus-theme.sh && cd ..

# Python & NumPy optimized build
bash rootfs/build-python-numpy.sh

# Rust kernel module (if rust toolchain installed)
if command -v rustc &>/dev/null; then
    cd kernel/rust-icarus && make && make install && cd ../..
fi

# Sign modules for Secure Boot (optional)
if [ -f /etc/efi-keys/MOK.priv ]; then
    bash kernel/sign-modules.sh
fi

# Final grimoire commit
git add -A && git commit -m "Master assembly completed." || true

arch-chroot /mnt /bin/bash << 'ENDCHROOT'
set -e
cd /home/icarus/icarus-linux

# Build and install kernel
cd kernel
sudo -u icarus makepkg -sf --noconfirm
pacman -U --noconfirm *.pkg.tar.zst
cd ..

# Deploy ram-root and regenerate initramfs
cp initramfs/ram-root-hook /etc/initcpio/hooks/
cp initramfs/ram-root-install /etc/initcpio/install/
sed -i 's/^HOOKS=(.*)/HOOKS=(base udev autodetect modconf block filesystems keyboard fsck ram-root)/' /etc/mkinitcpio.conf
mkinitcpio -p linux-icarus

# Install all configs and services
make install-configs

# Deploy daemons
cp rootfs/icarus-grimoire-keeper.sh rootfs/icarus-tune.sh rootfs/icarus-sentinel.sh \
   rootfs/icarus-memtierd.sh rootfs/icarus-stealth.sh rootfs/icarus-exporter.sh \
   rootfs/icarus-welcome.sh rootfs/icarus-backup.sh /usr/local/bin/

cp rootfs/*.service rootfs/*.timer /etc/systemd/system/
systemctl enable icarus-grimoire.timer icarus-tune.service icarus-sentinel.service \
                 icarus-memtierd.service icarus-stealth.service icarus-exporter.service \
                 icarus-welcome.service

# ---- NETWORK HARDENING (embedded from void) ----
mkdir -p /etc/iwd /etc/systemd /etc/nftables
cp rootfs/network/iwd-main.conf /etc/iwd/main.conf
cp rootfs/network/resolved.conf /etc/systemd/resolved.conf
cp rootfs/network/nftables.conf /etc/nftables.conf
systemctl enable nftables
systemctl enable systemd-resolved
systemctl enable iwd
# ------------------------------------------------

# Plymouth
cd plymouth && bash install-icarus-theme.sh && cd ..

# Python & NumPy optimized build
bash rootfs/build-python-numpy.sh

# Rust kernel module (if rust toolchain installed)
if command -v rustc &>/dev/null; then
    cd kernel/rust-icarus && make && make install && cd ../..
fi

# Sign modules for Secure Boot (optional)
if [ -f /etc/efi-keys/MOK.priv ]; then
    bash kernel/sign-modules.sh
fi

# Final grimoire commit
git add -A && git commit -m "Master assembly completed." || true

ENDCHROOT

umount -R /mnt
echo "=== Icarus Master Assembly complete. Reboot. ==="