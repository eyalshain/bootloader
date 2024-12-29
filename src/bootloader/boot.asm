; How a bootloader works:
;
; When a computer starts, the BIOS (Basic Input/Output System) 
; initializes the hardware and searches through a list of devices 
; (e.g., hard drives, USB drives) for a bootable device. It looks 
; for a device with an MBR (Master Boot Record) in the first sector, 
; known as the boot sector.
;
; The MBR is 512 bytes long and contains the bootloader code as 
; well as the partition table. The MBR ends with a 2-byte signature 
; (0xAA55) that allows the BIOS to recognize it as valid.
;
; Once the BIOS finds a valid MBR, it loads the MBR's contents 
; into memory at a predefined address (0x7C00 for x86 systems) 
; and sets the CPU's instruction pointer (IP) to this address.
;
; The bootloader code is executed and uses the partition table to 
; locate the operating system on the disk, typically using either 
; cylinder-head-sector (CHS) addressing or Logical Block Addressing 
; (LBA).
;
; The bootloader loads the required sectors of the OS from the disk 
; into memory. Once loaded, it transfers execution to the OS by 
; jumping to the appropriate memory address.
;
; This process transitions control from the BIOS to the bootloader, 
; and finally, to the operating system.


org 0x7c00  ; setting the starting address where the code will be loaded into memory.

bits 16

jmp short main      ; skipping all the headers, since we don't want them to get executed.
nop

bdb_oem:                  db   'MSWIN4.1'          ; OEM identifier string: "MSWIN4.1" (used to identify the filesystem type)
bdb_bytes_per_sector:     dw   512                 ; Bytes per sector: 512 bytes (standard sector size)
bdb_sectors_per_cluster:  db   1                   ; Sectors per cluster: 1 (each cluster is one sector)
bdb_reserved_sectors:     dw   1                   ; Reserved sectors: 1 (reserved for the bootloader and filesystem structures)
bdb_fat_count:            db   2                   ; Number of FATs: 2 (File Allocation Tables for redundancy)
bdb_dir_entries_count:    dw   0e0h                ; Number of directory entries: 224 (maximum number of files and directories)
bdb_total_sectors:        dw   2880                ; Total number of sectors: 2880 (total number of sectors on the disk)
bdb_media_descriptor_type:db   0f0h                ; Media descriptor type: 0xF0 (indicates a 1.44 MB floppy disk)
bdb_sectors_per_fat:      dw   9                   ; Sectors per FAT: 9 (number of sectors occupied by each FAT)
bdb_sectors_per_track:    dw   18                  ; Sectors per track: 18 (number of sectors on each track of the disk)
bdb_heads:                dw   2                   ; Number of heads: 2 (number of read/write heads on the disk)
bdb_hidden_sectors:       dd   0                   ; Number of hidden sectors: 0 (no hidden sectors before the start of the FAT)
bdb_large_sectors_count:  dd   0                   ; Large sectors count: 0 (not used for FAT12, this is set to 0)

ebr_drive_number:         db   0                   ; Drive number: 0 (not used for FAT12, typically 0x80 for the first hard drive)
                          db   0                   ; Reserved: 0 (reserved byte, not used)
ebr_signature:            db   29h                 ; Signature: 0x29 (boot signature indicating the end of the boot record)
ebr_volume_id:            db   12h, 34h, 56h, 78h  ; Volume ID: 0x12345678 (unique identifier for the volume)
ebr_volume_label:         db   'BOBO OS    '       ; Volume label: "bobo OS" (name of the volume, padded to 11 characters)
ebr_system_id:            db   'FAT12   '          ; System ID: "FAT12" (filesystem type identifier)


main:

    mov ax, 0
    mov ds, ax
    mov es, ax
    mov ss, ax

    mov sp, 0x7c00           ; moving the starting address to the stack pointer.

    mov si, os_boot_msg      ; initializing si with the boot message
    call print               ; printing the message
    hlt 


    ; 4 segments
    ; reserved segment = 1 sector - boot sector
    ; there is 2 FAT, each one is 9 sectors => 18 sectors
    ; Root directory
    ; Data

    mov ax, [bdb_sectors_per_fat]
    mov bl, [bdb_fat_count]
    xor bh, bh
    mul bx                          ; ax * bx => 9 * 2 => 18 sectors => ax
    add ax, [bdb_reserved_sectors]    ;  now ax contains the lba value of the root directory.
    

    push ax                         ;saving ax so we can do another calculation

    mov ax, [bdb_dir_entries_count]
    shl ax, 5                       ; ax *= 32 (2^5): multiplying the number of directory entries by 32 - bytes per entry.
    xor dx, dx
    div word [bdb_bytes_per_sector] ;(ax*32) / bytes per sector = how many directory entries per sector

    test dx, dx                     ;if there is a reminder, increment ax.
    jz RootDirAfter
    inc ax


; reading the root directory from the disk into the buffer
RootDirAfter: 
    mov cl, al                      ; number of sectors needed for all directory entries 
    pop ax                          ; restoring the lba value of the root directory
    mov dl, [ebr_drive_number]
    mov bx, buffer
    call disk_read

    xor bx, bx
    mov di, buffer

; in fat12, the first 11 bytes of the dir-entry is for the name, 8 bytes for name, and 3
; or the extension (kernel.bin ==> kernel  bin)
search_kernel:
    mov si, kernel_file_name

    mov cx, 11              
    push di
    repe cmpsb  ;comparing si with di - kernel file and the data on the root directory that we looking for (which is the kernel.bin)
    pop di
    je kernel_found

    add di, 32  ;moving to the next directory entry
    inc bx      ;counting the directory entries we passed on
    cmp bx, [bdb_dir_entries_count]

    jl search_kernel

    jmp kernel_not_found
    
 
kernel_not_found:
    mov si, msg_kernel_not_found
    call print

    hlt 
    jmp halt

kernel_found:
    ;mov si, msg_kernel_found
    ;call print

    ; reading the fat table
    mov ax, [di+26]     ;first logical cluster - index into the fat table;
    mov [kernel_cluster], ax
    mov bx, buffer
    mov cl, [bdb_sectors_per_fat]
    mov dl, [ebr_drive_number]

    call disk_read

    mov bx, kernel_load_segment ;0x2000
    mov es, bx
    mov bx, kernel_load_offset


;first 33 sectors of the disk are predefined (boot + 2 fats + root directory).
;in the fat, entries 0 and 1 are reserved, so entry 2 of the fat contains the
;description of sector 33. therefore:
;physical sector = 33 + fat entry number - 2:
;physical sector = 31 + fat entry number.

load_kernel_loop:
    mov ax, [kernel_cluster]
    add ax, 31  ; physical sector number.
    mov cl, 1   ;reading one cluster at a time.
    mov dl, [ebr_drive_number]

    call disk_read

    add bx, [bdb_bytes_per_sector]

    ;each entry at the fat table is 12 bits -> 1.5 bytes.
    ;(kernel cluster * 3) / 2  ==>  the number of bytes needed to store all of the fat entries
    ;till the current entry(which is the current cluster)
    mov ax, [kernel_cluster]
    mov cx, 3
    mul cx
    mov cx, 2
    div cx

    mov si, buffer
    add si, ax
    mov ax, [ds:si]

    or dx, dx
    jz even 

odd:
    shr ax, 4
    jmp nextClusterAfter

even:
    and ax, 0x0FFF

nextClusterAfter:
    cmp ax, 0x0FF8
    jae readFinish

    mov [kernel_cluster], ax
    jmp load_kernel_loop

readFinish:
    mov dl, [ebr_drive_number]
    mov ax, kernel_load_segment
    mov ds, ax
    mov es, ax

    jmp kernel_load_segment:kernel_load_offset

    hlt

halt:
    jmp halt    ; booting and then freezing the operating system.


; input: LBA index in ax
; cx [bits 0-5]: sector number
; cx [bits 6-15]: cylinder
; dh: head
lba_to_chs:
    push ax
    push dx

    xor dx, dx

    div word [bdb_sectors_per_track]    ; ax / sectors_per_track:
                                        ; (lba % sectors_per_track) + 1 = sector
    inc dx                              ; reminder stores in dx, so all we need to do in increase dx by one and get the sector
    mov cx, dx
    xor dx, dx  ; moving dx into cx, so we can use dx again.

    ; head:     (LBA/sectors_per_track) % number of heads
    ; cyilnder: (LBA/sectors_per_track) / number of heads
    ;           (LBA/sectors_per_track) is already store in ax, so lets do another division:

    div word [bdb_heads]     ; ((LBA/sectors_per_track) / number of heads) -> ax
    mov dh, dl      ; head number in dh for interrupt 13
    mov ch, al      ; al containing the cyilnder, now we gonna move it to ch
    shl ah, 6
    or cl, ah       ; cyilnder

    pop ax
    mov dl, al
    pop ax
    

    ret


disk_read:
    push ax
    push bx
    push cx
    push dx
    push di
    
    mov [sectors_to_read], cl 
    
    call lba_to_chs

    ;trying to read from the disk at least 3 times
    mov ah, 02h
    mov al, [sectors_to_read]
    mov di, 3       ; counter

retry:
    ;CF = 0 if successful
    ;CF = 1 if error

    stc     ; set the carry
    int 13h
    jnc done_read

    call disk_reset     
    
    dec di 
    test di, di
    jnz retry

fail_disk_read:
    mov si, read_failure 
    call print
    hlt
    jmp halt


disk_reset:
    pusha
    mov ah, 0   ; interrupt 13, ah = 0. for resting the disk drivers
    stc
    int 13h
    jc fail_disk_read
    popa
    ret

done_read:  
    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    
    ret



print:
    push si
    push ax
    push bx

print_loop: 
    lodsb 
    or al, al       ; if we reached the end of the string (0), end the loop.
    jz done_print

    mov ah, 0x0e    ; printing a character 
    mov bh, 0       ; page memory = 0
    int 10h         ; interrupt

    jmp print_loop

done_print: 
    pop bx
    pop ax
    pop si
    ret

os_boot_msg: db 'welcome! BOBO_OS is loading...', 0dh, 0ah, 0
read_failure db 'failed to read the disk. ', 0

kernel_file_name db 'KERNEL  BIN'


msg_kernel_not_found db 0dh, 0ah, 'KERNEL.BIN was not found', 0dh, 0ah, 0
;msg_kernel_found db 0dh, 0ah, 'KERNEL.BIN was found!', 0dh, 0ah, 0


kernel_cluster dw 0
kernel_load_segment equ 0x2000     ; available memory 
kernel_load_offset equ 0


sectors_to_read dd 0   ;


; boot sector have 512 bytes. the last 2 bytes contains this signature (0xAA55)
; so we are taking 510 bytes (to leave 2 bytes) minus the space that this program takes ($-$$).
times 510 - ($-$$) db 0   
dw 0xaa55

buffer: 