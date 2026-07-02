#!/bin/bash
# ------------------------------------------------------------------
# Icarus Metrics Exporter - Exposes system stats on port 9100.
# Format: Prometheus text exposition.
# ------------------------------------------------------------------
set -u

PORT=9100

# Helpers
cpu_temp() {
    local t=0
    for zone in /sys/class/thermal/thermal_zone*/temp; do
        t=$(cat "$zone" 2>/dev/null | head -1)
        break
    done
    echo $(( t / 1000 ))
}
gpu_temp() {
    for hwmon in /sys/class/hwmon/hwmon*; do
        if grep -q "i915" "$hwmon/name" 2>/dev/null; then
            echo $(( $(cat "$hwmon/temp1_input") / 1000 ))
            return
        fi
    done
    echo 0
}
mem_used_pct() {
    awk '/MemTotal/{t=$2} /MemAvailable/{a=$2} END{printf "%.1f", (1-a/t)*100}' /proc/meminfo
}
zram_comp_size() {
    cat /sys/block/zram0/mm_stat 2>/dev/null | awk '{print $2}'
}

# Simple HTTP server using netcat
while true; do
    {
        echo "HTTP/1.1 200 OK"
        echo "Content-Type: text/plain"
        echo ""
        echo "# HELP icarus_cpu_temp Celsius CPU temperature"
        echo "# TYPE icarus_cpu_temp gauge"
        echo "icarus_cpu_temp $(cpu_temp)"
        echo "# HELP icarus_gpu_temp Celsius GPU temperature"
        echo "# TYPE icarus_gpu_temp gauge"
        echo "icarus_gpu_temp $(gpu_temp)"
        echo "# HELP icarus_mem_used_pct Memory usage percent"
        echo "# TYPE icarus_mem_used_pct gauge"
        echo "icarus_mem_used_pct $(mem_used_pct)"
        echo "# HELP icarus_zram_comp_pages Compressed pages in zram"
        echo "# TYPE icarus_zram_comp_pages gauge"
        echo "icarus_zram_comp_pages $(zram_comp_size)"
    } | nc -l -p $PORT -q 1
done