.global _main 
.align 2

.text
_main:
    adrp x19, vm_stack@PAGE
    add x19, x19, vm_stack@PAGEOFF


    adrp x20, program@PAGE
    add x20, x20, program@PAGEOFF

loop:
    ldrb w0, [x20] // load into w0, one byte from x20
    add x20, x20, #1 // increment the program counter pointer by one, such that it points to next instruction
    cmp w0, #1 // val in w0 == 1? 
    b.eq do_push // if above statement is true, branch to do_push

    cmp w0, #5 // w0 == 5?
    b.eq do_halt //if true branch to do_halt

    b loop //if none of the above match, branch to loop
    

do_push:
    ldrb w1, [x20] //load into w1, one byte from x20
    add x20, x20, #1 // increment program 

    strb w1, [x19] //write the val in w1 into x19
    add x19, x19 ,#1 //increment stack pointer by one

    b loop


do_halt:
    sub x19, x19, #1 // move stack pointer down such that its pointing at the top elem, not an empty space
    ldrb w0, [x19] //read byte of x19 into w0

    mov x16, #1 //setup syscall number for exit
    svc #0x80 //trigger syscall

.data
program: .byte 1, 3, 1, 4, 5

.bss
.align 3
vm_stack: .space 256
