KDIR ?= /lib/modules/$(shell uname -r)/build

obj-m := icarus_rust.o
icarus_rust-objs := src/lib.o

all:
	$(MAKE) -C $(KDIR) M=$(PWD) modules

clean:
	$(MAKE) -C $(KDIR) M=$(PWD) clean