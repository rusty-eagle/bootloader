
[bits 16]
global start
start:
	; Disable Interrupts
	cli

	; Zero the segment registers
	xor	ax, ax
	mov	ds, ax
	mov	es, ax
	mov	ss, ax

seta20_1:
	in	al, 0x64 ; wait for not busy
	test	al, 0x2
	jnz	seta20_1

	mov	al, 0xd1 ; 0xd1 -> port 0x64
	out	0x64, al

seta20_2:
	in	al, 0x64 ; wait for not busy
	test	al, 0x2
	jnz	seta20_2

	mov	al, 0xdf ; 0xdf -> port 0x60
	out	0x60, al

	; Now we switch from Real to Protected mode.
	; We will use a bootstrap GDT that makes virtual addresses
	; map directly to physical addresses, so that the effective
	; memory map doesn't change during the transition.
	lgdt	[gdtdesc]
	mov	eax, cr0
	or	eax, 0x1
	mov	cr0, eax

	jmp	0x8:start32

[bits 32]
extern bootmain
start32:
	mov word	ax, 0x0010
	mov word	ds, ax
	mov word	es, ax
	mov word	ss, ax
	mov word	ax, 0
	mov word	fs, ax
	mov word	gs, ax

	mov	esp, start

	;; Now we change to the main
	call bootmain

spin:
	jmp spin

%macro SEG_NULLASM 0
	dd	0
	dd	0
%endmacro

;; type, base, limit
%macro SEG_ASM 3
	dw	((%3 >> 12) & 0xffff)
	dw	((%2) & 0xffff)
	db	((%2 >> 16) & 0xff)
	db	(0x90 | (%1))
	db	(0xC0 | (((%3) >> 28) & 0xf))
	db	(((%2) >> 24) & 0xff)
%endmacro

align 4
STA_X equ 0x8 ; Executable segment
STA_W equ 0x2 ; Writable (non-executable segments)
STA_R equ 0x2 ; Readable (executable segments)
gdt:
	; Null segment
	SEG_NULLASM

	; Code segment
	SEG_ASM (STA_X|STA_R), 0x0, 0xffffffff

	; Data segment
	SEG_ASM STA_W, 0x0, 0xffffffff

gdtdesc:
	dw	gdtdesc - gdt - 1
	dd	gdt
