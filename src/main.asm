org 0x7c00  ; setting the starting address where the code will be loaded into memory.

bits 16

main:
    hlt 

halt:
    jmp halt    ; booting and then freezing the operating system.


; boot sector have 512 bytes. the last 2 bytes contains this signature (0xAA55)
; so we are taking 510 bytes (to leave 2 bytes) minus the space that this program takes ($-$$).
times 510 - ($-$$) db 0   
dw 0xaa55