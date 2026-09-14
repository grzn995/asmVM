.global _main 
.align 2

.text
_main:
    adrp x19, vm_stack@PAGE
    add x19, x19, vm_stack@PAGEOFF


    adrp x20, program@PAGE
    add x20, x20, program@PAGEOFF


    mov x0, #0
    mov x16, #1
    svc 0x80

.data
program: .byte 1, 3, 1, 4, 5

.bss
.align 3
vm_stack: .space 256
