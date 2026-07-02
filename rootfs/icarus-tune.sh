#!/bin/bash
# Icarus Auto-Tune Daemon - Dynamically adjusts kernel parameters
# for maximum AI throughput on integrated GPU.

function apply_performance() {
    # CPU governor to performance
    for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
        echo performance > "$cpu" 2>/dev/null
    done
    # Disable C-states deeper than C1
    echo 1 > /sys/module/intel_idle/parameters/max_cstate
    # Increase GPU frequency (if supported)
    if [ -f /sys/class/drm/card0/gt_max_freq_mhz ]; then
        echo 1100 > /sys/class/drm/card0/gt_max_freq_mhz 2>/dev/null
    fi
    # Set I/O scheduler to kyber for NVMe/SATA
    for dev in /sys/block/sd*/queue/scheduler; do
        echo kyber > "$dev" 2>/dev/null
    done
    for dev in /sys/block/nvme*/queue/scheduler; do
        echo kyber > "$dev" 2>/dev/null
    done
    # Increase readahead
    echo 4096 > /sys/block/sda/queue/read_ahead_kb 2>/dev/null
    echo 4096 > /sys/block/nvme0n1/queue/read_ahead_kb 2>/dev/null
    # Transparent hugepages always
    echo always > /sys/kernel/mm/transparent_hugepage/enabled
    echo always > /sys/kernel/mm/transparent_hugepage/defrag
    # Disable swap unless necessary
    echo 0 > /proc/sys/vm/swappiness
}

function apply_powersave() {
    # Restore conservative defaults when idle
    for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
        echo powersave > "$cpu" 2>/dev/null
    done
    echo 9 > /sys/module/intel_idle/parameters/max_cstate
    echo 300 > /sys/class/drm/card0/gt_max_freq_mhz 2>/dev/null
    for dev in /sys/block/sd*/queue/scheduler; do
        echo bfq > "$dev" 2>/dev/null
    done
    echo madvise > /sys/kernel/mm/transparent_hugepage/enabled
    echo madvise > /sys/kernel/mm/transparent_hugepage/defrag
    echo 60 > /proc/sys/vm/swappiness
}

# Main loop: monitor CPU load (simple 1-min average)
THRESHOLD=2.0   # load avg above which we go performance
while true; do
    load=$(awk '{print $1}' /proc/loadavg)
    current_state=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor)
    if (( $(echo "$load > $THRESHOLD" | bc -l) )); then
        if [ "$current_state" != "performance" ]; then
            apply_performance
        fi
    else
        if [ "$current_state" != "powersave" ]; then
            apply_powersave
        fi
    fi
    sleep 10
done