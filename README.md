# bootloader

This is a clone of xv6's bootloader portion, rewritten in nasm only.  This expects a kernel to be written to the same disk, at LBA 1.

The kernel should be in ELF format, and have a virtual memory mapping into 0x80000000 (for example, the xv6 kernel goes into 0x80100000).

To build:

```
make bootloader
```

And you'll need to sign the bootloader after you build it.  I recommend this one:

https://github.com/rusty-eagle/boot_loader_signer

It requires Rust/Cargo.  You should be able to do something like this:

```
mkdir tmp
cd tmp
git clone --depth=1 https://github.com/rusty-eagle/boot_loader_signer
cd boot_loader_signer
cargo build
```
