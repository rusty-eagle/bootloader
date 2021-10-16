# bootloader

This is a clone of xv6's bootloader portion, rewritten in nasm only.  This expects a kernel to be written to the same disk, at LBA 1.

The kernel should be in ELF format, and have a virtual memory mapping into 0x80000000 (for example, the xv6 kernel goes into 0x80100000).

To build:

```
make bootloader
```
