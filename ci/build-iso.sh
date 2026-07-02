#!/bin/bash
# ------------------------------------------------------------------
# Icarus ISO Builder - Generates a live ISO from the repository.
# Requires: archiso, mkinitcpio, and this repo cloned at /tmp/icarus-build.
# Usage: bash ci/build-iso.sh [version]
# ------------------------------------------------------------------
set -euo pipefail

VERSION="${1:-$(date +%Y.%m.%d)}"
BUILD_DIR="/tmp/icarus-iso-build"
PROFILE_DIR="$BUILD_DIR/profile"
OUT_DIR="$PWD/iso"

log() { echo "[ISO] $*"; }

# Prepare profile
log "Preparing Archiso profile..."
mkdir -p "$PROFILE_DIR"
cp -r /usr/share/archiso/configs/releng/* "$PROFILE_DIR/"

# Override packages.x86_64 to include Icarus components
cat > "$PROFILE_DIR/packages.x86_64" << EOF
base
base-devel
linux-firmware
intel-ucode
iwd
networkmanager
sudo
zsh
xorg-server
xorg-xinit
i3-wm
alacritty
polybar
picom
feh
dmenu
plymouth
git
bc
rsync
vulkan-intel
vulkan-icd-loader
python
python-pip
python-numpy
EOF

# Copy our custom kernel package into the build
log "Copying Icarus kernel package..."
mkdir -p "$PROFILE_DIR/airootfs/root/icarus-packages"
cp ../kernel/linux-icarus-*.pkg.tar.zst "$PROFILE_DIR/airootfs/root/icarus-packages/"
echo "linux-icarus" >> "$PROFILE_DIR/packages.x86_64"

# Customize pacman.conf to include local repository
cat >> "$PROFILE_DIR/pacman.conf" << EOF
[icarus]
SigLevel = Never
Server = file:///root/icarus-packages
EOF

# Add Icarus repository and install scripts to the rootfs overlay
mkdir -p "$PROFILE_DIR/airootfs/root/icarus-linux"
cp -r ../../* "$PROFILE_DIR/airootfs/root/icarus-linux/"

# Add a post-install script that runs inside the live environment
cat > "$PROFILE_DIR/airootfs/root/customize_airootfs.sh" << 'CHROOT'
#!/bin/bash
# Customizations for Icarus Live ISO

# Enable services
systemctl enable NetworkManager
systemctl enable iwd

# Create user
useradd -m -G wheel liveuser
echo "liveuser:liveuser" | chpasswd
echo "%wheel ALL=(ALL) ALL" >> /etc/sudoers

# Set up dotfiles for live user
mkdir -p /home/liveuser/.config
cp -r /root/icarus-linux/dotfiles/* /home/liveuser/.config/
chown -R liveuser:liveuser /home/liveuser

# Preload Plymouth theme
cd /root/icarus-linux/plymouth && bash install-icarus-theme.sh

# Make bootstrap accessible
cp /root/icarus-linux/icarus-bootstrap.sh /usr/local/bin/
chmod +x /usr/local/bin/icarus-bootstrap.sh
CHROOT
chmod +x "$PROFILE_DIR/airootfs/root/customize_airootfs.sh"

# Build ISO
log "Building ISO..."
cd "$PROFILE_DIR"
mkarchiso -v -w /tmp/archiso-tmp -o "$OUT_DIR" "$PROFILE_DIR"

log "ISO created at $OUT_DIR/icarus-${VERSION}.iso"