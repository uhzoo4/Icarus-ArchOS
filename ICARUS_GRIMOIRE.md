# ICARUS OS — THE COMPLETE GRIMOIRE

## Prologue
Icarus is a custom‑built Arch Linux derivative that transforms low‑spec Intel hardware
(8 GB RAM, Iris Xe iGPU) into an AI inferencing beast rivaling Apple M‑series unified memory.
It uses a hand‑compiled kernel, RAM‑root filesystem, zero‑copy Vulkan compute,
and a stealth terminal disguise. This document catalogues every spell, script,
and configuration required to build and maintain the system.

## I. Kernel – The Wolf's Heart
- **PKGBUILD** (`kernel/PKGBUILD`): Builds `linux-icarus` with native optimizations,
  no security mitigations, full preemption, and 1000 Hz tick.
- **Config** (`kernel/config-icarus`): 10,000+ lines; tuned for Intel Iris Xe, zram, tmpfs,
  and device drivers stripped of unnecessary bloat.
- **Patches** (`kernel/0001-icarus-base.patch`): Placeholder for custom scheduler/GPU tweaks.
- **Signing** (`kernel/sign-modules.sh`, `kernel/secureboot-setup.sh`): Sign kernel modules
  and bootloader for Secure Boot using sbctl.
- **Hardware Probe** (`kernel/probe-hardware.sh`): Generates a config fragment for the
  exact CPU/GPU.
- **Rust Module** (`kernel/rust-icarus/`): Minimal Rust kernel module example.

## II. Initramfs – The Ascension
- **Ram‑Root Hook** (`initramfs/ram-root-hook`): Copies root filesystem into a tmpfs at boot;
  optional persistent overlay.
- **Install Script** (`initramfs/ram-root-install`): mkinitcpio helper.

## III. Root Filesystem & Daemons – The Living System
- **zram** (`rootfs/zram-generator.conf`): Compressed in‑RAM swap, 50% of physical RAM.
- **Auto‑Tune** (`rootfs/icarus-tune.sh`): Switches CPU/GPU governor based on load.
- **Sentinel** (`rootfs/icarus-sentinel.sh`): Thermal, memory, and I/O protection daemon.
- **Memory Tiering** (`rootfs/icarus-memtierd.sh`): Three‑tier memory (hot RAM, warm zram, cold SSD).
- **Stealth** (`rootfs/icarus-stealth.sh`): Fake BSD TTY at boot; Ctrl+Alt+F12 reveals i3.
- **Exporter** (`rootfs/icarus-exporter.sh`): Prometheus metrics on port 9100.
- **Welcome** (`rootfs/icarus-welcome.sh`): First‑boot configuration wizard.
- **Backup** (`rootfs/icarus-backup.sh`): Encrypted overlay backup.
- **Grimoire Keeper** (`rootfs/icarus-grimoire-keeper.sh`): Auto‑commits changes to repository hourly.
- **Pinner** (`rootfs/icarus-pinner.sh`): Pins GPU compute processes to isolated CPU cores.
- **Python/NumPy Build** (`rootfs/build-python-numpy.sh`): Compiles Python 3.12 and NumPy with PGO, BOLT.
- **Network Hardening** (`rootfs/network/`): iwd, systemd‑resolved, nftables firewall configuration.
- **Filesystem Snapshots** (`rootfs/setup-btrfs-snapshots.sh`): Btrfs subvolumes with hourly snapper snapshots.

## IV. Desktop Environment – The Sheep's Clothing
- **i3** (`dotfiles/i3/config`): Minimal tiling window manager, golden accent.
- **Alacritty** (`dotfiles/alacritty/alacritty.yml`): Transparent terminal with golden text.
- **Polybar** (`dotfiles/polybar/config.ini`): Golden status bar.
- **Picom** (`dotfiles/picom/picom.conf`): Dual‑Kawase blur, rounded corners.
- **Plymouth** (`plymouth/`): Animated sun boot theme.

## V. Vulkan Compute – The Unified Memory Engine
- **Backend** (`vulkan/icarus_vulkan_engine.py`): Creates Vulkan instance, allocates UMA buffers.
- **Pipeline Builder** (`vulkan/icarus_pipeline.py`): Loads SPIR‑V shaders and dispatches compute.
- **Shaders** (`vulkan/shaders/`):
  - `vector_add.comp`, `matmul.comp`, `attention_scores.comp`, `softmax.comp`,
    `layernorm.comp`, `gelu.comp`, `fused_attention_softmax.comp`.

## VI. Automation & Release – The Monthly Cycle
- **Makefile** (`Makefile`): `make kernel`, `make ramdisk`, `make release` targets.
- **ISO Builder** (`ci/build-iso.sh`): Generates bootable Archiso with Icarus pre‑packaged.
- **CI/CD** (`.github/workflows/monthly-release.yml`): Builds ISO on tag push.
- **Benchmark Suite** (`benchmarks/bench-all.sh`, `benchmarks/tracing/`): Performance tests and bpftrace probes.
- **Test Suite** (`tests/run-tests.sh`): Validates RAM‑root, Vulkan, sentinel, etc.

## VII. Installation – The Birth Ritual
1. Boot Arch Linux live ISO.
2. Partition target disk (GPT: 512 MB EFI, remainder ext4/btrfs).
3. Clone repository and run `icarus-bootstrap.sh /dev/sdX`.
4. Chroot into the new system and execute `icarus-master.sh /dev/sdX`.
5. Reboot into Icarus.

## VIII. Man Page – `docs/icarus.7`
`man icarus` for on‑system reference.

## IX. Appendix – Repository Layout

Icarus-ArchOS/
├── icarus-bootstrap.sh
├── icarus-master.sh
├── Makefile
├── ICARUS_GRIMOIRE.md
├── kernel/
├── initramfs/
├── rootfs/
├── dotfiles/
├── plymouth/
├── vulkan/
├── ci/
├── benchmarks/
├── tests/
├── docs/
└── .github
├── README.md             # Quick start
├── .gitignore            # What not to track
├── VERSION               # Monthly version file
└── CHANGELOG.md          # Release history


All scripts use bash, assume root access for system changes, and log verbosely.
Run all commands inside the `Icarus-ArchOS` directory.


## X. Epilogue
Icarus is not merely an operating system; it is a proof that low‑spec hardware, when
tuned with pure intent, can touch the divine. The grimoire is complete. The wolf is awake.