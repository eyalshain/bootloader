ASM = nasm
SRC_DIR = src
BUILD_DIR = build

DEBUG ?= 0
CFLAGS = 

ifeq ($(DEBUG), 1)
    CFLAGS += -g # Add debugging symbols to bootloader and kernel
endif

#
# Floppy Image
#

floppy_image: $(BUILD_DIR)/main.img
$(BUILD_DIR)/main.img: bootloader kernel
	dd if=/dev/zero of=$(BUILD_DIR)/main.img bs=512 count=2880
	mkfs.fat -F 12 -n "BOBO_OS" $(BUILD_DIR)/main.img
	dd if=$(BUILD_DIR)/bootloader.bin of=$(BUILD_DIR)/main.img conv=notrunc
	mcopy -i $(BUILD_DIR)/main.img $(BUILD_DIR)/kernel.bin "::kernel.bin"

#
# Bootloader
#

bootloader: $(BUILD_DIR)/bootloader.bin
$(BUILD_DIR)/bootloader.bin:
	$(ASM) $(SRC_DIR)/bootloader/boot.asm -f bin -o $(BUILD_DIR)/bootloader.bin

#
# Kernel
#

kernel: $(BUILD_DIR)/kernel.bin
$(BUILD_DIR)/kernel.bin:
	$(ASM) $(SRC_DIR)/kernel/main.asm -f bin -o $(BUILD_DIR)/kernel.bin

run: floppy_image
	qemu-system-i386 -fda $(BUILD_DIR)/main.img

gdb_debug: floppy_image
	qemu-system-i386 -fda $(BUILD_DIR)/main.img -s -S

debug: clean bootloader kernel floppy_image gdb_debug

clean:
	rm -rf build/*

all: clean bootloader kernel floppy_image run
