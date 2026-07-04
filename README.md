# Icarus-ArchOS 1st try

> **⚠️ STATUS: BOOT FAILURE**
> *The system failed during the boot process. While all other components are managed and functioning perfectly, the boot area malfunctioned and ultimately crashed.*

## 🦅 The Vision

Icarus is a custom-built Arch Linux derivative designed to transform low-spec Intel hardware (e.g., 8 GB RAM, Iris Xe iGPU) into an AI inferencing powerhouse rivaling Apple's M-series unified memory architecture. 

It leverages a hand-compiled kernel, RAM-root filesystem, zero-copy Vulkan compute, and a stealth terminal disguise.

## 🔮 The Grimoire

For a complete breakdown of every spell, script, and configuration required to build and maintain the system, please refer to the **[ICARUS_GRIMOIRE.md](ICARUS_GRIMOIRE.md)**. 

### Key Components

- **Kernel - The Wolf's Heart:** Native optimizations, no security mitigations, full preemption, and 1000 Hz tick.
- **Initramfs - The Ascension:** RAM-root hook copying the root filesystem into a tmpfs at boot.
- **Root Filesystem & Daemons - The Living System:** Features zram, memory tiering, custom Vulkan/AI tools, and stealth terminal disguises.
- **Desktop Environment - The Sheep's Clothing:** Minimal i3 tiling manager with a golden accent, Alacritty, Polybar, and Plymouth.
- **Vulkan Compute - The Unified Memory Engine:** Zero-copy UMA buffers and Vulkan compute for AI inferencing.

## 🚀 Installation & Build

> *Note: Booting is currently malfunctioning. The instructions below outline the intended build ritual.*

1. Boot an Arch Linux live ISO.
2. Partition the target disk (GPT: 512MB EFI, remainder ext4/btrfs).
3. Clone this repository and run `icarus-bootstrap.sh /dev/sdX`.
4. Chroot into the new system and execute `icarus-master.sh /dev/sdX`.
5. Reboot into Icarus (currently experiencing a boot area crash).

## 📜 Documentation

- `docs/icarus.7` - system manual
- `ICARUS_GRIMOIRE.md` - detailed system architecture and setup

## 🛠️ Monthly Cycle

- `make kernel`: Build the custom kernel
- `make ramdisk`: Generate the custom initramfs
- `make release`: Create a new release

*“Icarus is not merely an operating system; it is a proof that low‑spec hardware, when tuned with pure intent, can touch the divine. The grimoire is complete. The wolf is awake.”*
