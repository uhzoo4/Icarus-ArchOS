#!/bin/bash
# ------------------------------------------------------------------
# Icarus Compute Pinner - Isolates AI workloads to dedicated cores.
# Looks for processes with high GPU usage or tagged with "icarus-compute".
# The isolated cores are specified in /etc/icarus/isolated-cpus.
# ------------------------------------------------------------------
set -u

ISOLATED_CPUS="${ISOLATED_CPUS:-2,3}"
CGROUP_NAME="icarus-compute"
CGROUP_DIR="/sys/fs/cgroup/cpu/$CGROUP_NAME"
CHECK_INTERVAL=5

log() { echo "[Pinner] $(date '+%H:%M:%S') $*"; }

# Create cgroup if not exists
if [ ! -d "$CGROUP_DIR" ]; then
    sudo cgcreate -g cpu:/$CGROUP_NAME
    echo "Created cgroup cpu:/$CGROUP_NAME"
fi

# Move all current processes with Vulkan/OpenCL into the cgroup
pin_processes() {
    # Find PIDs using i915 GPU or Intel OpenCL
    for pid in $(lsof -t /dev/dri/card0 2>/dev/null) \
               $(pgrep -f "python.*icarus_vulkan") \
               $(pgrep -f "cl_task"); do
        if [ -n "$pid" ]; then
            # Add to cgroup (which limits them to isolated CPUs via cpuset)
            sudo cgclassify -g cpu,cpuset:/$CGROUP_NAME "$pid" 2>/dev/null || true
            # Also pin directly with taskset for immediate effect
            taskset -pc "$ISOLATED_CPUS" "$pid" 2>/dev/null || true
            # Set real-time priority
            chrt -f -p 50 "$pid" 2>/dev/null || true
            log "Pinned process $pid to CPUs $ISOLATED_CPUS"
        fi
    done
}

# Ensure cpuset cgroup restricts to isolated cores (if cpuset is mounted)
if [ -d /sys/fs/cgroup/cpuset ]; then
    sudo cgset -r cpuset.cpus="$ISOLATED_CPUS" /icarus-compute 2>/dev/null || true
fi

while true; do
    pin_processes
    sleep "$CHECK_INTERVAL"
done