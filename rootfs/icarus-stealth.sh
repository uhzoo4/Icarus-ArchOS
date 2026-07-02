#!/bin/bash
# ------------------------------------------------------------------
# Icarus Stealth Mode - Displays a fake BSD terminal on boot.
# Press Ctrl+Alt+F12 to kill it and reveal the true desktop.
# ------------------------------------------------------------------

# Use fbterm to render a framebuffer terminal
if command -v fbterm &>/dev/null; then
    # Start fbterm in fullscreen with a retro green-on-black palette
    fbterm -- font=Terminus,12 --geometry=80x24 \
           --color=0,2,0,0,0,0 \
           -- \
           bash -c '
               clear
               echo "4.4BSD Unix (icarus) (ttyv0)"
               echo ""
               echo "login: root"
               echo "Password:"
               sleep 2
               echo "Last login: Thu Jan  1 00:00:00 on ttyv0"
               echo "4.4BSD UNIX #0: Thu Jan  1 00:00:00 GMT 1970"
               echo "You have mail."
               echo ""
               # Wait for the secret key combo (handled externally) to exit
               while true; do sleep 60; done
           ' &
    STEALTH_PID=$!
else
    # Fallback: just use a plain tty
    STEALTH_PID=0
fi

# Trap the secret key combo (Ctrl+Alt+F12) to kill the fake terminal
# We use actkbd or a simple xbindkeys; for simplicity, we install a
# systemd override that restarts getty on Ctrl+Alt+F12.
# This script is run as a systemd service before the graphical target.

# Store PID for later cleanup
echo $STEALTH_PID > /var/run/icarus-stealth.pid
wait $STEALTH_PID