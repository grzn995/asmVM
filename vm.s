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

    cmp w0, #2 //same process as above
    b.eq do_add

    cmp w0,#3
    b.eq do_sub

    cmp w0, #4
    b.eq do_print

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

    //store the newline character at the last index of buffer
    mov w3,#10
    strb w3,[x1,#3]

    //set x2 to point at the 2 index of buffer
    mov x2,#2

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

.data
program: .byte 1, 4, 1, 3, 3, 5

.bss
.align 3
vm_stack: .space 256
print_buf: .space 8
