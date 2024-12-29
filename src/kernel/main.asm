; need to remove it!
; org 0x7c00  ; setting the starting address where the code will be loaded into memory.
org 0x0

bits 16

start:
    mov si, os_boot_msg
    call print
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


