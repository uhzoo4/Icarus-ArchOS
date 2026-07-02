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
# Icarus Forge Makefile - Build, benchmark, release.
VERSION := $(shell cat VERSION)
KERNEL_DIR := kernel
INITRAMFS_DIR := initramfs
ROOTFS_DIR := rootfs
DOTFILES_DIR := dotfiles
BENCH_DIR := benchmarks

.PHONY: kernel ramdisk install-configs benchmark release clean

kernel:
	@echo "Forging Icarus kernel..."
	cd $(KERNEL_DIR) && makepkg -sf --noconfirm


ramdisk:
	@echo "Deploying ram-root hooks..."
	sudo cp $(INITRAMFS_DIR)/ram-root-hook /etc/initcpio/hooks/
	sudo cp $(INITRAMFS_DIR)/ram-root-install /etc/initcpio/install/

	sudo mkinitcpio -p linux-icarus


install-configs:
	@echo "Installing zram, overlay, and dotfiles..."
	sudo cp $(ROOTFS_DIR)/zram-generator.conf /etc/systemd/zram-generator.conf

	sudo systemctl restart systemd-zram-setup@zram0.service 2>/dev/null || true

	sudo cp $(ROOTFS_DIR)/icarus-overlay-setup.service /etc/systemd/system/
	sudo systemctl daemon-reload

	cp -r $(DOTFILES_DIR)/* $(HOME)/.config/



benchmark:
	@echo "Running benchmarks..."
	@mkdir -p $(BENCH_DIR)/results
	./$(BENCH_DIR)/bench-all.sh | tee $(BENCH_DIR)/results/$(VERSION).log


release: kernel ramdisk install-configs benchmark
	@echo "Monthly release $(VERSION)"
	git add -A
	git commit -m "Release $(VERSION)" || true
	git tag -a $(VERSION) -m "Icarus $(VERSION)"
	@echo "Tagged $(VERSION). Push with: git push --follow-tags"

clean:

	cd $(KERNEL_DIR) && rm -rf src pkg *.pkg.tar.*