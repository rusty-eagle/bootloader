CC = x86_64-linux-gnu-gcc
AS = nasm
LD = x86_64-linux-gnu-ld
OBJCOPY = /usr/bin/objcopy
CFLAGS = -m32 -fno-pic -static -fno-builtin -fno-strict-aliasing -Wall -MD -ggdb -Werror -fno-omit-frame-pointer -fno-pie -no-pie

.PHONY: bootloader-x86 bootdisk-x86 bootdisk-x86-debug

bootloader-x86:
	## Making Bootloader Build Folder
	mkdir -p build/x86/bootloader
	mkdir -p dist/x86
	## Assembling Source Files
	$(AS) -f elf32 -g -Isrc/include -o build/x86/bootloader/main.o src/target/x86/bootloader/main.S
	$(AS) -f elf32 -g -Isrc/include -o build/x86/bootloader/boot.o src/target/x86/bootloader/boot.S
	## Linking Bootloader object file
	$(LD) -m elf_i386 -N -e start -Ttext 0x7c00 -o build/x86/bootloader/bootblock.o build/x86/bootloader/boot.o build/x86/bootloader/main.o
	## Copying copying .text section to "bootblock" file
	$(OBJCOPY) -S -O binary -j .text build/x86/bootloader/bootblock.o dist/x86/bootblock
	## Signing Bootloader
	tmp/boot_loader_signer/target/debug/boot_loader_signer dist/x86/bootblock

bootdisk-x86-debug: bootloader-x86
	## Create bootdisk
	dd if=/dev/zero of=dist/x86/freedom.img count=10000
	## Write bootloader to it
	dd if=dist/x86/bootblock of=dist/x86/freedom.img conv=notrunc
	## Then the kernel
	dd if=dist/x86/kernel.bin of=dist/x86/freedom.img seek=1 conv=notrunc
	## Debug Qemu
	qemu-system-i386 -drive file=dist/x86/freedom.img,index=0,media=disk,format=raw -m 512 -s -S

bootdisk-x86: bootloader-x86
	## Create bootdisk
	dd if=/dev/zero of=dist/x86/freedom.img count=10000
	## Write bootloader to it
	dd if=dist/x86/bootblock of=dist/x86/freedom.img conv=notrunc
	## Then the kernel
	dd if=dist/x86/kernel.bin of=dist/x86/freedom.img seek=1 conv=notrunc
	## Non debug qemu
	qemu-system-i386 -drive file=dist/x86/freedom.img,index=0,media=disk,format=raw -m 512
