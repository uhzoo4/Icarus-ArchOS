#!/bin/bash
# ------------------------------------------------------------------
# Icarus Hardware Probe - Generates a kernel config fragment for the
# current machine's exact CPU, GPU, and memory topology.
# Run on the target system before kernel compilation.
# ------------------------------------------------------------------
set -euo pipefail

OUTPUT_FRAGMENT="config-icarus-fragment"
echo "# Icarus hardware probe generated fragment" > "$OUTPUT_FRAGMENT"

# CPU vendor and family
CPU_VENDOR=$(grep -m1 'vendor_id' /proc/cpuinfo | awk '{print $3}')
if [ "$CPU_VENDOR" = "GenuineIntel" ]; then
    echo "CONFIG_CPU_SUP_INTEL=y" >> "$OUTPUT_FRAGMENT"
    # Determine microarchitecture for -march (we'll set compiler flags separately)
    echo "# Intel CPU detected" >> "$OUTPUT_FRAGMENT"
elif [ "$CPU_VENDOR" = "AuthenticAMD" ]; then
    echo "CONFIG_CPU_SUP_AMD=y" >> "$OUTPUT_FRAGMENT"
fi

# Number of cores
CORES=$(nproc)
echo "CONFIG_NR_CPUS=$CORES" >> "$OUTPUT_FRAGMENT"

# Memory size to tune tmpfs
MEMTOTAL_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
MEMTOTAL_MB=$(( MEMTOTAL_KB / 1024 ))
echo "# Total memory: ${MEMTOTAL_MB} MB" >> "$OUTPUT_FRAGMENT"
# We can set default tmpfs size or let ram-root hook handle it.

# GPU detection for DRM
if lspci | grep -qi "VGA.*Intel"; then
    echo "CONFIG_DRM_I915=m" >> "$OUTPUT_FRAGMENT"
    echo "# Intel iGPU detected" >> "$OUTPUT_FRAGMENT"
fi
if lspci | grep -qi "VGA.*NVIDIA"; then
    echo "CONFIG_DRM_NOUVEAU=m" >> "$OUTPUT_FRAGMENT"
fi
if lspci | grep -qi "VGA.*AMD/ATI"; then
    echo "CONFIG_DRM_AMDGPU=m" >> "$OUTPUT_FRAGMENT"
fi

# Check for NVMe
if ls /dev/nvme* 1>/dev/null 2>&1; then
    echo "CONFIG_BLK_DEV_NVME=m" >> "$OUTPUT_FRAGMENT"
    echo "CONFIG_NVME_CORE=m" >> "$OUTPUT_FRAGMENT"
fi

# Add specific microarchitecture compiler flags to CONFIG_LOCALVERSION or just note
# We'll append to the config later via PKGBUILD
echo "Probe complete. Fragment saved to $OUTPUT_FRAGMENT"
echo "Append this to the base config before building."