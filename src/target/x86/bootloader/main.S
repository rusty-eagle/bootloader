[bits 32]
global bootmain

;; Some helpers
_video equ 0xb8000
_sector equ 512
_elf_magic_match equ 0x464C457F
_scratch_location equ 0x10000

;;;;;;;;;;; Elf Offsets ;;;;;;;;;;;;;;;;;;;;;;;;;
_elf_magic_number equ	0		; 4 bytes
_elf_string equ 4			; 12 bytes
_elf_type equ 16			; 2 bytes
_elf_machine equ 18			; 2 bytes
_elf_version equ 20			; 4 bytes
_elf_entry equ 24			; 4 bytes
_elf_program_header_offset equ 28	; 4 bytes
_elf_section_header_offset equ 32	; 4 bytes
_elf_flags equ 36			; 4 bytes
_elf_eh_size equ 40			; 2 bytes
_elf_ph_ent_size equ 42			; 2 bytes
_elf_ph_number equ 44			; 2 bytes
_elf_sh_ent_size equ 46			; 2 bytes
_elf_sh_number equ 48			; 2 bytes
_elf_sh_str_ndx equ 50			; 2 bytes
;;;;;;;;; Total of 52 bytes ;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;; Program Header Offsets ;;;;;;;;;;;;;;;;
_program_type equ 0			; 4 bytes
_program_offset equ 4			; 4 bytes
_program_virtual_address equ 8		; 4 bytes
_program_physical_address equ 12	; 4 bytes
_program_file_size equ 16		; 4 bytes
_program_memory_size equ 20		; 4 bytes
_program_flags equ 24			; 4 bytes
_program_align equ 28			; 4 bytes
;;;;;;;;; Total of 32 bytes ;;;;;;;;;;;;;;;;;;;;;

bootmain:
	;; Read 1st sector off disk
	mov	edi, _scratch_location	; destination
	mov	ebx, 0			; offset
	mov	ecx, 4096		; count
	mov	eax, 0			; don't pad
	call	read_kernel_segment
	;; Now the first 8 sectors of kernel is located at 0x10000 in memory

	;; Check if it is an elf exe (0x464C457F)
	;; Move 4 bytes into eax
	mov	eax, [_scratch_location]
	mov	ebx, _elf_magic_match
	cmp	eax, ebx
	jnz	error

	;; Look at the program headers, and read them from disk

	;; Set esi to the program header location
	;; esi = ph
	;; 1. Move eax to where the kernel ELF image is
	mov	eax, _scratch_location
	;; 2. Add the offset to the memory location with phoff value
	add	eax, _elf_program_header_offset
	;; 3. Set ebx to phoff
	mov 	ebx, [eax]
	;; 4. Set esi to the scratch location
	mov	esi, _scratch_location
	;; 5. Add the program header offset, so now esi = program header 1
	add	esi, ebx

	;; Set ecx to program header number
	;; cx = phnum
	;; 1. Move into eax the location of kernel ELF image
	mov	eax, _scratch_location
	;; 2. Add offset to program header number value
	add	eax, _elf_ph_number
	;; 3. Dereference the address as a 2 bytes value, into bx
	mov	cx, [eax]

.program_header_number_loop:
	;; Preserve # of program headers left to read
	push	cx

	;; Read program header segment from disk
	;; edi = destination
	;; bx = offset (in sectors)
	;; ecx = count

	;; destination
	;; edi = ph->paddr
	mov	eax, esi
	add	eax, _program_physical_address
	mov	edi, [eax]

	;; count
	;; ecx = ph->filesz
	mov	eax, esi
	add	eax, _program_file_size
	mov	ecx, [eax]

	;; offset
	;; bx = ph->off
	mov	eax, esi
	add	eax, _program_offset
	mov	ebx, [eax]

	mov	eax, 1		; do pad
	call	read_kernel_segment

	;; Restore # of program headers left to read
	pop	cx

	;; Increment esi
	add	esi, 32 ;; 32 bit program headers

	;; Decrement counter
	dec	cx
	test	cx, cx	;; 0x0000 & 0x0000
	jnz	.program_header_number_loop

	;; Call Kernel entry
	mov	eax, _scratch_location
	add	eax, _elf_entry
	mov	ebx, [eax]
	sub	ebx, 0x80000000
	jmp	ebx

	hlt

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
error:
	mov	edi, _video
.looper:
	;; Print cool circles
	mov word [edi], 0x0409
	mov word [edi+0x2], 0x0609
	mov word [edi+0x4], 0x0809
	add edi, 0x6
	cmp edi, 0xb8F00
	jl .looper
	hlt
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;; Boot loader functions ;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
waitdisk:
	push	eax		; preserve
	push	edx

	mov	edx, 0x01F7
.start_wait:
	in 	al, dx		; read from port
	and	al, 0xC0	; enable 0xC0 bit
	cmp	al, 0x40	; eax - 0x40
	jne	.start_wait	; if it's not 0x40, do it again

	pop	edx
	pop	eax		; restore value
	ret
	
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
readsect:
	;; edi = destination
	;; ebx = offset

	;; Preserve this
	push 	edx
	push	ecx

	; Wait for the disk to be ready
	call waitdisk

	; Copy Offset to eax
	mov	eax, ebx

	; Port to send drive and bit 24-27 of LBA
	mov	edx, 0x01F6
	shr	eax, 24		;; get bit 24-27 in al
	or	eax, 11100000b	;; set bit 6 in al for LBA mode
	out	dx, al

	; Port to send number of sectors
	mov	edx, 0x01F2
	mov	al, 1		; count = 1
	out	dx, al

	; Port to send bit 0-7 of LBA
	mov	eax, ebx	;; copy offset again
	mov	edx, 0x01F3
	out	dx, al

	; Port to send bit 8-15 of LBA
	mov	eax, ebx	;; copy offset again
	mov	edx, 0x01F4
	shr	eax, 8		; >> 8
	out	dx, al

	; Port to send bit 16-23 of LBA
	mov	eax, ebx	;; copy offset again
	mov	edx, 0x01F5
	shr	eax, 16		; >> 16
	out	dx, al

	; Command port
	mov	edx, 0x01F7
	mov	al, 0x20	; Command 0x20 - read sector(s)
	out	dx, al

	; Wait for the disk to be ready
	call waitdisk

	; Copy bytes from buffer into memory
	cld
	mov	edx, 0x01F0	; port
	mov	cx, _sector/4	; count
	;; Destination is already set in edi
	rep	insd

;; Is it writing to the memory pointed to by edi?

	;; Restore this
	pop	ecx
	pop	edx

	ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
read_kernel_segment:
	;; edi = destination
	;; ebx = offset
	;; ecx = count
	;; eax = pad? 0 = no, 1 = yes

	push	eax	;; we don't need this til later

	;; edx = end of destination
	mov	edx, edi
	add	edx, ecx

	;; Fix offset to ignore bootloader & start at kernel
	;; check for zero
	test	ebx, ebx
	jz	.readseg_continue

	;; Divide Offset by Sector size, gives LBA
	;; Assumes offset is bigger than 0x200 (512 bytes)
	;; Assumes offset is multiple of 0x200
	;; So you must compile the kernel that way
	push	edx		; since we're going to divide
	xor	edx, edx	; prepare dividend High
	mov	eax, ebx	; prepare dividend Low
	mov	ebx, _sector	; prepare divisor
	div	ebx		; divide
	mov	ebx, eax	; move quotient back to edx
	pop	edx

.readseg_continue:
	add	ebx, 1

.segment_loop:
	;; Read the sector from disk
	;; bx is the offset for both functions
	;; edi is the destination for both functions
	call	readsect

	;; Increase disk LBA offset
	inc	ebx

	;; Increase memory pointer location
	add	edi, _sector

	;; See if we hit the end
	cmp	edi, edx
	jl	.segment_loop

	;; Pad any extra space with 0's
	pop	eax
	test	eax, eax
	jz	.read_end
	;; eax = 0
	mov	eax, 0
	;; ecx = edi - edx - 1
	mov	ecx, edi
	sub	ecx, edx
	sub	ecx, 1
	;; edi = edx + 1
	mov	edi, edx
	add	edi, 1
	rep	stosd

.read_end:
	;; End function
	ret
