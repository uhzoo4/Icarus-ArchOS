#!/bin/bash
# Install Icarus Sun Plymouth theme and set as default.
THEME_NAME="icarus-sun"
THEME_DIR="/usr/share/plymouth/themes/$THEME_NAME"

sudo mkdir -p "$THEME_DIR"
sudo cp icarus-sun.plymouth "$THEME_DIR/"
sudo cp icarus-sun.script "$THEME_DIR/"
# Placeholder: generate a simple golden sun image if not present
if [ ! -f "sun.png" ]; then
    echo "Generating default sun.png (requires ImageMagick)..."
    convert -size 512x512 xc:transparent \
            -fill '#d4af37' -draw "circle 256,256 256,128" \
            sun.png
fi
sudo cp sun.png "$THEME_DIR/"
sudo plymouth-set-default-theme -R "$THEME_NAME"