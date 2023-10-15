org 0x7C00
bits 16
%define ENDL 0x0D, 0x0A

; FAT12 HEADER
jmp short start
nop
bdp_oem: 			db 'MSWIN4.1'		; 8 bytes
bdp_bytes_per_sector:		dw 512
bdp_sectors_per_cluster: 	db 1
bdp_reserved_sectors:		dw 1
bdp_fat_count:			db 2
bdp_dir_entries_count:		dw 0E0h
bdp_total_sectors:		dw 2880			; 2880 * 512 = 1.44MB
bdp_media_descriptor_type:	db 0F0h			; F0 = 3.5" floppy disk
bdp_sectors_per_fat:		dw 9			; 9 sectors/fat
bdp_sectors_per_track:		dw 18
bdp_heads:			dw 2
bdp_hidden_sectors:		dd 0
bdp_large_sector_count:		dd 0

; Extended boot record
ebr_drive_number:		db 0			; 0x00 = floppy, 0x80 = hdd, useless
				db 0			; reserved
ebr_signature:			db 29h
ebr_volume_id:			db 12h, 34h, 56h, 78h	; serial number, value doesn't matter
ebr_volume_label:		db 'MY OS      ' 	; 11 bytes, padded w/ spaces
ebr_system_id:			db 'FAT12   '		; 8 bytes, padded w/ space


; CODE GOES HERE

start:
	jmp main

; Print string to screen
; Params:
; - ds:si points to string
puts:
	; save registers we will modify
	push si
	push ax

.loop:
	lodsb		; loads next char in al
	or al, al	; verify if next char is null
	jz .done
	mov ah, 0x0e	; call bios interrupt
	int 0x10
	jmp .loop

.done:
	pop ax
	pop si
	ret

main:
	; setup data segments
	xor ax, ax 	; can't write directly to ds/es
	mov ds, ax
	mov es, ax

	; setup stack
	mov ss, ax
	mov sp, 0x7C00	; stack grows downwards from where we are loading in mem

	; print msg
	mov si, msg_hello
	call puts

	hlt

.halt:
	jmp .halt

msg_hello: db 'Hello World!', ENDL, 0

times 510-($-$$) db 0
dw 0AA55h
