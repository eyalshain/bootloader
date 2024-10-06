
org 0x7c00  ; setting the starting address where the code will be loaded into memory.

bits 16

main:

    mov ax, 0
    mov ds, ax
    mov es, ax
    mov ss, ax

    mov sp, 0x7c00           ; moving the starting address to the stack pointer.
    mov si, os_boot_msg      ; initializing si with the boot message
    call print               ; printing the message
    hlt 

halt:
    jmp halt    ; booting and then freezing the operating system.


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
    pop si
    pop ax
    pop bx
    ret

os_boot_msg: db 'Our operating system has booted! ', 0dh, 0ah, 0


; boot sector have 512 bytes. the last 2 bytes contains this signature (0xAA55)
; so we are taking 510 bytes (to leave 2 bytes) minus the space that this program takes ($-$$).
times 510 - ($-$$) db 0   
dw 0xaa55

