#!/bin/bash
# ------------------------------------------------------------------
# Icarus Module Signing - Generate MOK and sign kernel/modules.
# Run once after kernel build.  Then import the MOK into UEFI.
# ------------------------------------------------------------------
set -euo pipefail

KEY_DIR="/etc/efi-keys"
MOK_NAME="icarus-secureboot"

log() { echo "[SIGN] $*"; }

# 1. Generate key
if [ ! -f "$KEY_DIR/MOK.priv" ]; then
    log "Generating Machine Owner Key..."
    sudo mkdir -p "$KEY_DIR"
    sudo openssl req -new -x509 -newkey rsa:2048 -keyout "$KEY_DIR/MOK.priv" \
         -outform DER -out "$KEY_DIR/MOK.der" -nodes -days 36500 \
         -subj "/CN=$MOK_NAME/"
    sudo chmod 600 "$KEY_DIR/MOK.priv"
fi

# 2. Sign the kernel image
KERNEL_IMG="/boot/vmlinuz-linux-icarus"
if [ -f "$KERNEL_IMG" ]; then
    log "Signing kernel image..."
    sudo sbsign --key "$KEY_DIR/MOK.priv" --cert "$KEY_DIR/MOK.der" \
         --output "$KERNEL_IMG" "$KERNEL_IMG"
fi

# 3. Sign all modules
MOD_DIR="/lib/modules/$(uname -r)"
if [ -d "$MOD_DIR" ]; then
    log "Signing kernel modules..."
    for mod in $(find "$MOD_DIR" -name '*.ko'); do
        sudo sbsign --key "$KEY_DIR/MOK.priv" --cert "$KEY_DIR/MOK.der" "$mod"
    done
fi

# 4. Import MOK into UEFI (requires reboot)
log "MOK generated. Reboot and run: sudo mokutil --import $KEY_DIR/MOK.der"
echo "Then follow the MOK Manager prompt at boot to enroll the key."