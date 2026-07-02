#!/bin/bash
# ---------------------------------------------------------------
# Icarus System Sentinel - The Unseen Guardian
# Continuously monitors CPU/GPU temperature, memory pressure,
# and I/O latency.  Applies counter-measures before throttling
# or OOM conditions occur.  Designed for AI workloads that push
# integrated hardware to the absolute limit.
# ---------------------------------------------------------------

set -u

# --- Configuration (tune to your silicon) -----------------------
CPU_TEMP_LIMIT=85                # Celsius, start throttling
GPU_TEMP_LIMIT=90                # Intel i915 junction max
MEM_PRESSURE_LIMIT=70            # Percentage of available RAM used before compaction
IO_LATENCY_LIMIT_MS=500          # Max acceptable I/O wait before killing background sync
COMPACTION_ORDER=9               # Defrag up to 2^9 pages (2MB hugepages)
GPU_FREQ_STEP=50                 # MHz to reduce when throttling
CHECK_INTERVAL=5                 # Seconds between checks
# ------------------------------------------------------------------

log() { echo "[Sentinel] $(date '+%H:%M:%S') $*"; }

# --- Helper: read an integer value from a sysfs file, default 0 -----
read_sysfs() { cat "$1" 2>/dev/null || echo 0; }

# --- CPU temperature (x86 coretemp / k10temp) ------------------------
get_cpu_temp() {
    # Try multiple possible paths
    local temp_raw
    temp_raw=$(read_sysfs /sys/class/thermal/thermal_zone0/temp)
    if [ "$temp_raw" -gt 1000 ]; then
        # Usually millidegrees
        echo $(( temp_raw / 1000 ))
    else
        # Fallback: use coretemp hwmon
        local hwmon
        for hwmon in /sys/class/hwmon/hwmon*; do
            if grep -q "coretemp" "$hwmon/name" 2>/dev/null; then
                temp_raw=$(read_sysfs "$hwmon/temp1_input")
                echo $(( temp_raw / 1000 ))
                return
            fi
        done
    fi
    echo 0
}

# --- GPU temperature (i915 specific) ---------------------------------
get_gpu_temp() {
    local temp_raw
    # i915 often exposes temp1_input
    for hwmon in /sys/class/hwmon/hwmon*; do
        if [ -f "$hwmon/name" ] && grep -q "i915" "$hwmon/name" 2>/dev/null; then
            temp_raw=$(read_sysfs "$hwmon/temp1_input")
            echo $(( temp_raw / 1000 ))
            return
        fi
    done
    echo 0
}

# --- Memory pressure (0-100) -----------------------------------------
get_mem_pressure() {
    # Percentage of MemAvailable relative to MemTotal
    local total avail
    total=$(awk '/MemTotal/ {print $2}' /proc/meminfo)
    avail=$(awk '/MemAvailable/ {print $2}' /proc/meminfo)
    if [ "$total" -gt 0 ]; then
        echo $(( 100 - (avail * 100 / total) ))
    else
        echo 0
    fi
}

# --- I/O latency (rough average from block layer stat) ---------------
get_io_latency_ms() {
    # Use iostat if available, else dummy
    if command -v iostat &>/dev/null; then
        iostat -x 1 1 | awk '/^sd|^nvme/ {sum+=$10} END {printf "%.0f", sum}'
    else
        echo 0
    fi
}

# --- Actions ---------------------------------------------------------

throttle_cpu() {
    # Set CPU governor to powersave to reduce heat
    log "CPU temp high ($1 C). Forcing powersave governor."
    for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
        echo powersave > "$cpu" 2>/dev/null
    done
}

throttle_gpu() {
    # Reduce maximum GPU frequency
    local max_freq_file="/sys/class/drm/card0/gt_max_freq_mhz"
    if [ -f "$max_freq_file" ]; then
        local cur_max=$(read_sysfs "$max_freq_file")
        local new_max=$(( cur_max - GPU_FREQ_STEP ))
        if [ "$new_max" -ge 300 ]; then
            log "GPU temp high ($1 C). Reducing max freq from ${cur_max} to ${new_max} MHz."
            echo "$new_max" > "$max_freq_file" 2>/dev/null
        fi
    fi
}

compact_memory() {
    # Force memory compaction to create hugepages
    log "Memory pressure high ($1%). Triggering compaction."
    echo 1 > /proc/sys/vm/compact_memory 2>/dev/null
    # Also drop caches to free reclaimable slab memory (safe for UMA)
    sync; echo 3 > /proc/sys/vm/drop_caches 2>/dev/null
}

reduce_io_pressure() {
    # Kill any background sync/updatedb processes that hog disk
    log "I/O latency high (${1}ms). Pausing background services."
    systemctl stop man-db.timer updatedb.service 2>/dev/null
    # Lower dirty page thresholds to force earlier writeback
    echo 5 > /proc/sys/vm/dirty_background_ratio 2>/dev/null
    echo 10 > /proc/sys/vm/dirty_ratio 2>/dev/null
}

restore_normal() {
    # Return to performance state if temperatures are safe
    for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
        echo performance > "$cpu" 2>/dev/null
    done
    if [ -f /sys/class/drm/card0/gt_max_freq_mhz ]; then
        echo 1100 > /sys/class/drm/card0/gt_max_freq_mhz 2>/dev/null
    fi
    echo 10 > /proc/sys/vm/dirty_background_ratio 2>/dev/null
    echo 20 > /proc/sys/vm/dirty_ratio 2>/dev/null
}

# --- Main loop ------------------------------------------------------
log "Sentinel online. Watching over Icarus."

# Ensure we start in performance mode
restore_normal

while true; do
    cpu_temp=$(get_cpu_temp)
    gpu_temp=$(get_gpu_temp)
    mem_pressure=$(get_mem_pressure)
    io_latency=$(get_io_latency_ms)

    # 1. Temperature checks (CPU then GPU)
    if [ "$cpu_temp" -gt "$CPU_TEMP_LIMIT" ]; then
        throttle_cpu "$cpu_temp"
    elif [ "$gpu_temp" -gt "$GPU_TEMP_LIMIT" ]; then
        throttle_gpu "$gpu_temp"
    else
        # If temps are fine and we are not in performance mode, restore
        current_gov=$(read_sysfs /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor)
        if [ "$current_gov" != "performance" ]; then
            restore_normal
        fi
    fi

    # 2. Memory pressure - trigger proactive compaction
    if [ "$mem_pressure" -gt "$MEM_PRESSURE_LIMIT" ]; then
        compact_memory "$mem_pressure"
    fi

    # 3. I/O latency - reduce background load
    if [ "$io_latency" -gt "$IO_LATENCY_LIMIT_MS" ] && [ "$io_latency" -ne 0 ]; then
        reduce_io_pressure "$io_latency"
    fi

    sleep "$CHECK_INTERVAL"
done