.global _main
.align 2

.text
_main:
    //get address of vm_stack and set x19 as our stack pointer
    adrp x19, vm_stack@PAGE
    add x19, x19, vm_stack@PAGEOFF
    mov x21, x19 //save the stack's base address, used by do_halt to detect an empty stack

    //save the program's base address permanently in x22, used by do_jmp/do_jz to turn an index into an address
    adrp x22, program@PAGE
    add x22, x22, program@PAGEOFF


    //get address of program and set x20 as our program counter (this one moves every instruction)
    adrp x20, program@PAGE
    add x20, x20, program@PAGEOFF

loop:
    ldrb w0, [x20] // load into w0, one byte from x20
    add x20, x20, #1 // increment the program counter pointer by one, such that it points to next instruction

    cmp w0, #1 // val in w0 == 1?
    b.eq do_push // if above statement is true, branch to do_push

    cmp w0, #2 //same process as above
    b.eq do_add

    cmp w0,#3
    b.eq do_sub

    cmp w0, #4
    b.eq do_print

    cmp w0, #5 // w0 == 5?
    b.eq do_halt //if true branch to do_halt

    cmp w0, #6
    b.eq do_pop

    cmp w0, #7
    b.eq do_mul

    cmp w0, #8
    b.eq do_jmp

    cmp w0, #9
    b.eq do_jz

    b loop //if none of the above match, branch to loop


do_push:
    ldrb w1, [x20] //load into w1, one byte from x20
    add x20, x20, #1 // increment program

    strb w1, [x19] //write the val in w1 into x19
    add x19, x19 ,#1 //increment stack pointer by one

    b loop


do_halt:
    cmp x19, x21 //check if the stack is empty (stack pointer == stack base)
    b.le halt_zero //if empty, skip straight to exiting with code 0
    sub x19, x19, #1 // move stack pointer down such that its pointing at the top elem, not an empty space
    ldrb w0, [x19] //read byte of x19 into w0
    b do_exit


halt_zero:
    mov w0,#0 //stack was empty, default exit code to 0


do_exit:
    mov x16, #1 //syscall number for exit
    svc #0x80 //trigger syscall

do_add:
    sub x19, x19 , #1 //move stack pointer back to point at second val
    ldrb w0, [x19] //read val into w0

    sub x19,x19,#1 //stack pointer -1
    ldrb w1, [x19] //load val into w1

    //calculate sum into w3,store w3 into current stack pos
    add w3,w1,w0
    strb w3,[x19]

    add x19,x19,#1 // increment stack pointer by 1

    b loop //branch into loop




do_sub:
    //Same process as in do_add
    sub x19, x19 , #1
    ldrb w0, [x19]

    sub x19,x19,#1
    ldrb w1, [x19]

    //Calculate sum into w3 and store w3 into stack
    sub w3,w1,w0
    strb w3,[x19]

    add x19,x19,#1

    b loop


do_print:
    //Pop val of the stack
    sub x19,x19,#1
    ldrb w0,[x19]


    //get adress of buffer
    adrp x1, print_buf@PAGE
    add x1, x1, print_buf@PAGEOFF

    and w8, w0, #0x80 //isolate bit 7 to check if the value is negative
    cmp w8, #0
    b.eq positive_print //bit 7 is 0, value is positive, skip the sign handling below

    mov w11,w0 //save the original value, since the write syscall below will clobber w0


    mov w9, #0x2D //ASCII '-'
    strb w9, [x1]
    mov x0, #1
    mov x2, #1
    mov x16, #4
    svc #0x80 //print the '-' character

    mov w0,w11 //restore the original value from before the syscall
    mov w10, #256
    sub w0, w10,w0 //compute the magnitude: 256 - value, since the syscall may have disturbed w0
    adrp x1, print_buf@PAGE //recompute the buffer address, don't trust it survived the syscall
    add x1, x1, print_buf@PAGEOFF

positive_print:
    //store the newline character at the last index of buffer
    mov w3,#10
    strb w3,[x1,#3]

    //set x2 to point at the 2 index of buffer
    mov x2,#2
    cmp w0, #0
    b.ne digit_loop //value isn't 0, go extract its digits normally

    //special case: value is 0, digit_loop would never write anything, so write '0' directly
    mov w12, #0x30
    strb w12, [x1,x2]
    sub x2, x2, #1
    b print_it

digit_loop:
    //check if value is 0 and if true branch to print_it
    cmp w0, #0
    b.eq print_it


    //put divisor into w5
    mov w5, #10

    //store the quotient of w0/w5 into w6, do msub to find a remainer to store into w7, convert the value in w7 to ascii with add.
    udiv w6, w0, w5
    msub w7, w6, w5, w0
    add w7, w7, #0x30

    //write the digit we extracted into the print buffer in x1, at the index x2. Decrement the index by one after
    strb w7, [x1,x2]
    sub x2,x2,#1

    //store the quotient into w0, to repeat the process
    mov w0,w6

    b digit_loop

print_it:
    //x2 always points one position to the left of the first number, make it point to the first number
    add x9,x2,#1

    //calculate the amount of bytes to print
    mov x5, #4
    sub x5, x5,x9

    //Set adress of x1 to point at the first digit
    add x1,x1,x9

    mov x0,#1 //file descriptor: stdout
    mov x2,x5 //length expected to be passed into x2, x5 = 4
    mov x16, #4 //syscall number for write
    svc #0x80 //triggering syscall

    b loop


do_pop:
    //make stack pointer point to the item we want to pop,
    //that makes the item pointed at unreachable because every other function effectively works with the item one position behind what the stack pointer is pointing at
    sub x19, x19 , #1
    b loop


do_mul:
    //reading in the values
    sub x19,x19,#1
    ldrb w0,[x19]

    sub x19,x19,#1
    ldrb w1,[x19]

    //calculate product and store into stack
    mul w3, w0, w1
    strb w3,[x19]

    //make stack pointer point one in front the last element
    add x19, x19, #1

    b loop

do_jmp:
    //read in the operand
    ldrb w1,[x20]
    add x20, x22, x1 //compute address of the target index (base + index) and overwrite the program counter with it
    b loop //continue the dispatch loop from the new position

do_jz:
    //read the operand (target index) - this always has to be read and advanced past,
    //regardless of whether the jump actually happens
    ldrb w1, [x20]
    add x20, x20, #1

    //peek at the top of the stack WITHOUT popping, so the value survives for the next loop pass
    ldrb w0, [x19, #-1]
    cmp w0, #0
    b.ne loop //top isn't 0, don't jump, x20 already points at the next instruction

    //top is 0: compute the jump target (base + index) and overwrite the program counter
    add x20, x22, x1
    b loop

.data
program: .byte 1, 3, 1, 1, 3, 9, 9, 8, 2, 4, 5 //the bytecode program the VM executes; see examples/ for more
.bss
.align 3
vm_stack: .space 256 //the VM's own stack, separate from the CPU's call stack
print_buf: .space 8 //scratch buffer PRINT uses to build the digit string before writing it out
