# ARM64 Bytecode VM

A small stack-based virtual machine written entirely in ARM64 assembly for Apple Silicon (macOS). It reads a program from a byte array, executes it one instruction at a time, and can print numbers, do arithmetic, and run loops. There is no C code and no libc calls. All output goes through raw `write` and `exit` system calls.

I built it to learn assembly from the ground up: memory addressing, the fetch-decode-execute cycle, system calls, and how numbers become text.

## Features

- Fetch-decode-execute dispatch loop
- Separate VM stack, managed by hand through a stack pointer register
- 9 opcodes: arithmetic, stack manipulation, printing, and control flow
- Signed 8-bit values (-128 to 127) with correct negative-number output
- Unconditional and conditional jumps, so bytecode programs can loop
- Multi-digit number printing, using division to extract digits into a buffer

## Requirements

- macOS on Apple Silicon (M1 or later)
- Xcode command line tools (`xcode-select --install`), which provide `clang`

The syscall numbers and calling convention are macOS-specific, so this will not run unmodified on Linux.

## Build and run

``` bash
clang -o vm vm.s
./vm
```

The program to run is the `.byte` line in the `.data` section at the bottom of `vm.s`. Edit it, rebuild, and run again.

## Opcodes

| Mnemonic | Opcode | Operand | Effect |
|----|----|----|----|
| PUSH | 1 | 1 byte | push the operand onto the stack |
| ADD | 2 | none | pop two values, push their sum |
| SUB | 3 | none | pop two values, push (second - top) |
| PRINT | 4 | none | pop one value, print it as a signed number |
| HALT | 5 | none | stop; exit code is the top of the stack, or 0 if empty |
| POP | 6 | none | discard the top of the stack |
| MUL | 7 | none | pop two values, push their product |
| JMP | 8 | 1 byte | jump to the program index given by the operand |
| JZ | 9 | 1 byte | if the top of the stack is 0, jump to the operand index (the top is not removed) |

Full details are in [DESIGN.md](DESIGN.md).

## Example programs

Replace the `.byte` line in `vm.s` with any of these.

**Arithmetic: 6 x 7**

``` asm
program: .byte 1, 6, 1, 7, 7, 4, 5
```

`PUSH 6, PUSH 7, MUL, PRINT, HALT` prints `42`.

**Negative numbers: 3 - 4**

``` asm
program: .byte 1, 3, 1, 4, 3, 4, 5
```

`PUSH 3, PUSH 4, SUB, PRINT, HALT` prints `-1`.

**Skipping code with JMP**

``` asm
program: .byte 1, 5, 8, 6, 1, 99, 4, 5
```

`PUSH 5, JMP 6, PUSH 99, PRINT, HALT` prints `5`. The jump skips over `PUSH 99`.

**A loop: count down from 3 to 0**

``` asm
program: .byte 1, 3, 1, 1, 3, 9, 9, 8, 2, 4, 5
```

```         
index:  0  1  2  3  4  5  6  7  8  9  10
byte:   1  3  1  1  3  9  9  8  2  4  5
        PUSH 3 PUSH 1 SUB JZ 9  JMP 2 PRINT HALT
```

The stack top goes 3, 2, 1, 0. Each pass pushes 1 and subtracts it. While the result is nonzero, `JMP 2` goes back to the start of the loop body. When it reaches 0, `JZ 9` jumps to `PRINT`, which prints `0`.

## Documentation

- [DESIGN.md](DESIGN.md): the bytecode format and opcode table
- [REGISTERS.md](REGISTERS.md): what every register holds, and why
- [CONCEPTS.md](CONCEPTS.md): how each feature works, step by step

## Limitations

These are known and deliberate, to keep the VM small.

- Values are one byte, so the range is -128 to 127.
- The VM stack is 256 bytes, and the program is limited to 256 bytes, since jump targets are 1-byte indices.
- There is no error checking. An unknown opcode is skipped, and popping an empty stack reads whatever bytes happen to be in memory.
- There is no assembler yet. Programs are written as raw bytes.
