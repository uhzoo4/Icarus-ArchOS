.PHONY: kernel ramdisk install-configs release

VERSION ?= $(shell cat VERSION)

kernel:
	cd kernel && makepkg -sf --noconfirm

ramdisk:
	sudo cp initramfs/ram-root-hook /etc/initcpio/hooks/
	sudo cp initramfs/ram-root-install /etc/initcpio/install/
	sudo mkinitcpio -p linux-icarus

install-configs:
	sudo cp rootfs/zram-generator.conf /etc/systemd/
	sudo cp rootfs/icarus-overlay-setup.service /etc/systemd/system/
	cp -r dotfiles/* ~/.config/

benchmark:
	./benchmarks/bench-all.sh | tee benchmarks/results/$(VERSION).log

release: kernel ramdisk benchmark
	git tag -a $(VERSION) -m "Icarus $(VERSION) – M5 Pro Max"
	git push origin $(VERSION)
	echo "Monthly release $(VERSION) built and tagged."

	# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Icarus Forge Makefile — "The Hammer of Hephaestus"
# Automates: kernel compile, initramfs, config deployment,
#            benchmarking, and monthly release tagging.
# Usage:
#   make kernel         — build the linux-icarus package
#   make ramdisk        — regenerate initramfs with ram-root
#   make install-configs— deploy dotfiles, zram, services
#   make benchmark      — run performance suite
#   make release        — all above + git tag + push
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

.PHONY: kernel ramdisk install-configs benchmark release clean

VERSION := $(shell cat VERSION)
KERNEL_DIR := kernel
INITRAMFS_DIR := initramfs
ROOTFS_DIR := rootfs
DOTFILES_DIR := dotfiles
BENCH_DIR := benchmarks

kernel:
	@echo "🔥 Forging the Icarus kernel..."
	cd $(KERNEL_DIR) && makepkg -sf --noconfirm
	@echo "   Kernel package built. Install with: sudo pacman -U *.pkg.tar.zst"

ramdisk:
	@echo "💨 Copying ram-root hook into system..."
	sudo cp $(INITRAMFS_DIR)/ram-root-hook /etc/initcpio/hooks/
	sudo cp $(INITRAMFS_DIR)/ram-root-install /etc/initcpio/install/
	@echo "   Regenerating initramfs for linux-icarus..."
	sudo mkinitcpio -p linux-icarus
	@echo "   Initramfs ready. Reboot to taste the speed."

install-configs:
	@echo "🎨 Installing Icarus dotfiles and system configs..."
	# zram
	sudo cp $(ROOTFS_DIR)/zram-generator.conf /etc/systemd/zram-generator.conf
	sudo systemctl restart systemd-zram-setup@zram0.service 2>/dev/null || true
	# overlay placeholder service
	sudo cp $(ROOTFS_DIR)/icarus-overlay-setup.service /etc/systemd/system/
	sudo systemctl daemon-reload
	# dotfiles
	cp -r $(DOTFILES_DIR)/* $(HOME)/.config/
	@echo "   Configs deployed."

benchmark:
	@echo "📊 Running Icarus benchmark suite..."
	@mkdir -p $(BENCH_DIR)/results
	./$(BENCH_DIR)/bench-all.sh | tee $(BENCH_DIR)/results/$(VERSION).log
	@echo "   Results saved to benchmarks/results/$(VERSION).log"

release: kernel ramdisk install-configs benchmark
	@echo "🌕 Monthly release $(VERSION) — stamping into legend..."
	# Update changelog automatically? Could be manual; we just commit everything.
	git add -A
	git commit -m "Release $(VERSION) – the wolf grows stronger" || true
	git tag -a $(VERSION) -m "Icarus $(VERSION) – M5 Pro Max"
	@echo "   Tagged $(VERSION). Don't forget to push: git push --follow-tags"
	@echo "   Stock of code increased. Icarus flies higher."

clean:
	@echo "🧹 Cleaning kernel build artifacts..."
	cd $(KERNEL_DIR) && rm -rf src pkg *.pkg.tar.*