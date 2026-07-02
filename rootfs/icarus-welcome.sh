#!/bin/bash
# ------------------------------------------------------------------
# Icarus Welcome Script - First boot configuration wizard.
# Sets timezone, hostname, root password, and creates user.
# ------------------------------------------------------------------
set -euo pipefail

clear
echo "=================================================================="
echo "  Icarus OS - First Boot Configuration"
echo "=================================================================="
echo

read -p "Enter hostname [icarus]: " HOSTNAME
HOSTNAME=${HOSTNAME:-icarus}
echo "$HOSTNAME" > /etc/hostname
echo "127.0.0.1   $HOSTNAME" >> /etc/hosts

read -p "Enter timezone (e.g. Asia/Kolkata) [UTC]: " TIMEZONE
TIMEZONE=${TIMEZONE:-UTC}
ln -sf "/usr/share/zoneinfo/$TIMEZONE" /etc/localtime
hwclock --systohc

echo
echo "Setting root password:"
passwd root

echo
read -p "Create a new user (leave blank to skip): " NEWUSER
if [ -n "$NEWUSER" ]; then
    useradd -m -G wheel "$NEWUSER"
    passwd "$NEWUSER"
    echo "%wheel ALL=(ALL) ALL" >> /etc/sudoers
fi

echo
echo "Configuration complete. Icarus is ready."
echo "Type 'reboot' to restart."