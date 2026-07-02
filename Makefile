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