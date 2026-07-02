#!/bin/bash
# Run this on the target laptop to produce a full Icarus kernel config.
# Requires: base-devel, git, and the kernel source downloaded.

KERNEL_VER="6.9.7"
cd ~/icarus-linux/kernel
wget https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-${KERNEL_VER}.tar.xz
tar xf linux-${KERNEL_VER}.tar.xz
cd linux-${KERNEL_VER}

# Start with a minimal config from your current running kernel
zcat /proc/config.gz > .config
make olddefconfig

# Now apply Icarus-specific tweaks using scripts/config
scripts/config --enable CONFIG_PREEMPT
scripts/config --disable CONFIG_PREEMPT_VOLUNTARY
scripts/config --set-val CONFIG_HZ 1000
scripts/config --enable CONFIG_NO_HZ_FULL
scripts/config --enable CONFIG_RCU_NOCB_CPU
scripts/config --enable CONFIG_TRANSPARENT_HUGEPAGE_ALWAYS
scripts/config --enable CONFIG_ZRAM
scripts/config --enable CONFIG_ZSMALLOC
scripts/config --enable CONFIG_LZ4_COMPRESS
scripts/config --module CONFIG_DRM_I915
scripts/config --disable CONFIG_DRM_I915_GVT
scripts/config --disable CONFIG_RETPOLINE
scripts/config --disable CONFIG_PAGE_TABLE_ISOLATION
scripts/config --disable CONFIG_MITIGATION_RETPOLINE
scripts/config --disable CONFIG_MITIGATION_PAGE_TABLE_ISOLATION
scripts/config --disable CONFIG_MITIGATION_SPECTRE_V2
scripts/config --disable CONFIG_MITIGATION_SRBDS
scripts/config --disable CONFIG_MITIGATION_SSB
scripts/config --disable CONFIG_MITIGATION_L1TF
scripts/config --disable CONFIG_MITIGATION_MDS
scripts/config --disable CONFIG_MITIGATION_TAA
scripts/config --disable CONFIG_MITIGATION_MMIO_STALE_DATA
scripts/config --disable CONFIG_MITIGATION_RFDS
scripts/config --disable CONFIG_MITIGATION_SPECTRE_V1
scripts/config --disable CONFIG_MITIGATION_SPECTRE_BHB
scripts/config --disable CONFIG_MITIGATION_SPECTRE_V3A
scripts/config --disable CONFIG_MITIGATION_SPEC_STORE_BYPASS
scripts/config --disable CONFIG_MITIGATION_UNRET_ENTRY
scripts/config --enable CONFIG_CPU_FREQ_DEFAULT_GOV_PERFORMANCE
scripts/config --enable CONFIG_INTEL_IDLE
scripts/config --enable CONFIG_INTEL_PSTATE
scripts/config --enable CONFIG_TMPFS
scripts/config --module CONFIG_OVERLAY_FS
scripts/config --enable CONFIG_BLK_DEV_INITRD
scripts/config --enable CONFIG_RD_XZ
scripts/config --enable CONFIG_RD_LZ4

# Recompute dependencies
make olddefconfig

# Now copy to our config-icarus
cp .config ../config-icarus
echo "Full Icarus kernel config generated."