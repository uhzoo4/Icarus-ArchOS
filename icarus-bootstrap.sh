#!/bin/bash
# ------------------------------------------------------------------
# Icarus Bootstrap Installer
# Transforms a fresh Arch Linux install into Icarus OS.
# Run from the Arch live environment after mounting target at /mnt.
# Usage: bash icarus-bootstrap.sh /dev/sdX (where sdX is target disk)
# ------------------------------------------------------------------
set -euo pipefail

TARGET_DEV="${1:-}"
if [ -z "$TARGET_DEV" ] || [ ! -b "$TARGET_DEV" ]; then
    echo "Usage: $0 /dev/sdX (target USB/disk)"
    exit 1
fi

ROOT_PART="${TARGET_DEV}2"
EFI_PART="${TARGET_DEV}1"
WORKDIR="/mnt"
REPO_URL="https://github.com/yourname/icarus-linux.git"  # adjust

echo "=== Icarus Bootstrap: starting installation ==="

# 1. Partition and format (if not already done)
echo "Partitioning $TARGET_DEV..."
# Assume GPT: 512M EFI, rest Linux
parted -s "$TARGET_DEV" mklabel gpt
parted -s "$TARGET_DEV" mkpart primary fat32 1MiB 513MiB
parted -s "$TARGET_DEV" set 1 esp on
parted -s "$TARGET_DEV" mkpart primary ext4 513MiB 100%
mkfs.fat -F32 "$EFI_PART"
mkfs.ext4 -F "$ROOT_PART"

# 2. Mount filesystems
mount "$ROOT_PART" "$WORKDIR"
mkdir -p "$WORKDIR/boot"
mount "$EFI_PART" "$WORKDIR/boot"

# 3. Base system install
echo "Installing base packages..."
pacstrap "$WORKDIR" base base-devel linux-firmware intel-ucode iwd vim git \
    networkmanager sudo zsh xorg-server xorg-xinit i3-wm alacritty \
    polybar picom feh dmenu plymouth bc rsync fbterm

# 4. Generate fstab
genfstab -U "$WORKDIR" >> "$WORKDIR/etc/fstab"

# 5. Chroot configuration script
cat > "$WORKDIR/icarus-chroot.sh" << 'CHROOT_EOF'
#!/bin/bash
set -e

# Timezone and locale
ln -sf /usr/share/zoneinfo/Asia/Kolkata /etc/localtime
hwclock --systohc
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf
echo "icarus" > /etc/hostname

# Users
useradd -m -G wheel icarus
echo "icarus:icarus" | chpasswd
echo "root:root" | chpasswd
echo "%wheel ALL=(ALL) ALL" >> /etc/sudoers

# Enable services
systemctl enable NetworkManager
systemctl enable systemd-resolved
systemctl enable iwd
systemctl enable plymouth

# Bootloader (systemd-boot)
bootctl --path=/boot install
echo "default icarus" > /boot/loader/loader.conf
echo "timeout 2" >> /boot/loader/loader.conf

# Create initial boot entry (temporary, will be updated after kernel build)
cat > /boot/loader/entries/icarus.conf << EOF
title   Icarus OS
linux   /vmlinuz-linux-icarus
initrd  /intel-ucode.img
initrd  /initramfs-linux-icarus.img
options root=UUID=$(blkid -s UUID -o value /dev/disk/by-label/ROOT) rw mitigations=off quiet loglevel=0
EOF

# Clone the Icarus repository
cd /home/icarus
git clone https://github.com/yourname/icarus-linux.git
chown -R icarus:icarus icarus-linux

# Build the custom kernel (this takes time)
cd /home/icarus/icarus-linux/kernel
sudo -u icarus makepkg -sf --noconfirm
pacman -U --noconfirm linux-icarus-*.pkg.tar.zst

# Install ram-root hook
cp /home/icarus/icarus-linux/initramfs/ram-root-hook /etc/initcpio/hooks/
cp /home/icarus/icarus-linux/initramfs/ram-root-install /etc/initcpio/install/
# Add ram-root to mkinitcpio.conf (after fsck)
sed -i 's/^HOOKS=(.*)/HOOKS=(base udev autodetect modconf block filesystems keyboard fsck ram-root)/' /etc/mkinitcpio.conf
mkinitcpio -p linux-icarus

# Deploy configs
cd /home/icarus/icarus-linux
make install-configs

# Enable Grimoire Keeper, Auto-tune, Sentinel, and Stealth
cp rootfs/icarus-grimoire-keeper.sh /usr/local/bin/
cp rootfs/icarus-tune.sh /usr/local/bin/
cp rootfs/icarus-sentinel.sh /usr/local/bin/
cp rootfs/icarus-stealth.sh /usr/local/bin/
cp rootfs/*.service rootfs/*.timer /etc/systemd/system/
systemctl enable icarus-grimoire.timer
systemctl enable icarus-tune.service
systemctl enable icarus-sentinel.service
systemctl enable icarus-stealth.service

# Plymouth theme
cd plymouth
bash install-icarus-theme.sh
cd ..

# Set up Vulkan engine (install python deps)
pacman -S --noconfirm python python-pip vulkan-icd-loader vulkan-intel
pip install --no-cache-dir vulkan numpy

# Final touch: set ownership
chown -R icarus:icarus /home/icarus

echo "Icarus installation complete. Remove this script and reboot."
CHROOT_EOF

chmod +x "$WORKDIR/icarus-chroot.sh"
arch-chroot "$WORKDIR" /icarus-chroot.sh

# Cleanup
rm "$WORKDIR/icarus-chroot.sh"

echo "=== Icarus Bootstrap finished. You may now reboot. ==="