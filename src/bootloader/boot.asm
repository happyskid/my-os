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

	; read something from floppy_disk
	; BIOS should set DL to drive number
	mov [ebr_drive_number], dl
	mov ax, 1	; LBA=1, second sector from disk
	mov cl, 1	; 1 sector read
	mov bx, 0x7E00	; data should be after the bootloader
	call disk_read

	; print msg
	mov si, msg_hello
	call puts

	cli
	hlt

; Error handlers

floppy_error:
	mov si, msg_read_failed
	call puts
	jmp wait_key_and_reboot

wait_key_and_reboot:
	xor ah, ah
	int 16h 	; wait for keypress
	jmp 0FFFFh:0	; jmp to beginning of bios, should reboot

.halt:
	cli
	jmp .halt

; Disk routines

; Converts LBA address to a CHS address
; Parameters
;	- ax: LBA address
; Returns:
;	- cx [bits 0-5]: sector number
; 	- cx [bits 6-5]: cylinder
;	- dh: head

lba_to_chs:
	; save to stack
	push ax
	push dx

	xor dx, dx				; dx = 0
	div word [bdp_sectors_per_track]	; ax = LBA / SectorsPerTrack
						; dx = LBA % SectorsPerTrack
	inc dx					; dx = (LBA % SectorsPerTrack + 1) = sector
	mov cx, dx				; cx = sector

	xor dx, dx				; dx = 0
	div word [bdp_heads]			; ax = (LBA / SectorsPerTrack) / Heads = cyliner
						; dx = (LBA / SectorsPerTrack) % Heads = head
	mov dh, dl				; dh = head
	mov ch, al				; ch = cylinder (lower 8 bits)
	shl ah, 6
	or cl, ah				; put upper 2 bits of cylinder in cl
	
	pop ax
	mov dl, al				; restore dl
	pop ax
	ret

; Read sectors from a disk
; Paramaters
;	- ax = LBA address
;	- cl: num of sectors to read (up to 128)
;	- dl: drive number
;	- es:bx memory address where to store read deata
disk_read:
	push ax					; save registers we will modify
	push bx
	push cx
	push dx
	push di
	push cx					; temporarily save CL (number of sectors to read)
	call lba_to_chs				; compute CHS
	pop ax					; AL = number of sectors to read
	mov ah, 02h
	mov di, 3				; retry count
	
.retry:
	pusha					; save all registers, we don't know what bios modifies
	stc					; set carry flag, some bios forget to set it/dont
	int 13h					; carry flag cleared = success
	jnc .done				; jump if carry not set
	
	; read failed
	popa
	call disk_reset
	dec di
	test di, di
	jnz .retry

.fail:
	; after all attempts exhausted
	jmp floppy_error

.done:
	popa
	pop di
	pop dx
	pop cx
	pop bx
	pop ax					; restore modified registers
	ret

; Resets disk controller
; Paramaters
;	- dl: drive number
disk_reset:
	pusha
	xor ah, ah
	stc
	int 13h
	jc floppy_error
	popa
	ret

msg_hello: 		db 'Hello World!', ENDL, 0
msg_read_failed: 	db 'Read from disk fialed!', ENDL, 0

times 510-($-$$) db 0
dw 0AA55h
