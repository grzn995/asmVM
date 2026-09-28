# ARM64 Bytecode VM

A small stack-based virtual machine written entirely in ARM64 assembly for Apple Silicon (macOS), plus a Python assembler that lets you write programs with labels instead of hand-counted byte indices. The VM reads a program from a byte array, executes it one instruction at a time, and can print numbers, do arithmetic, and run loops. There is no C code and no libc calls in the VM itself. All output goes through raw `write` and `exit` system calls.

I built it to learn assembly from the ground up: memory addressing, the fetch-decode-execute cycle, system calls, how numbers become text, and finally how an assembler turns readable source into raw bytes.

## Features

- Fetch-decode-execute dispatch loop
- Separate VM stack, managed by hand through a stack pointer register
- 9 opcodes: arithmetic, stack manipulation, printing, and control flow
- Signed 8-bit values (-128 to 127) with correct negative-number output
- Unconditional and conditional jumps, so bytecode programs can loop
- Multi-digit number printing, using division to extract digits into a buffer
- A two-pass Python assembler that supports labels, so jump targets don't have to be counted by hand

## Requirements

- macOS on Apple Silicon (M1 or later)
- Xcode command line tools (`xcode-select --install`), which provide `clang`
- Python 3, only needed to run the assembler

The syscall numbers and calling convention are macOS-specific, so the VM will not run unmodified on Linux.

## Quickstart

```bash
# assemble a program into a .byte line
python3 tools/assembler.py examples/multiply.asm
# -> program: .byte 1, 6, 1, 7, 7, 4, 5

# paste that line into vm.s, replacing the existing `program:` line, then build and run
clang -o vm vm.s
./vm
```

## The assembler

Writing raw bytecode by hand means counting byte indices yourself, and recounting everything if you add or remove a line — this is what the countdown loop example needed before the assembler existed. `tools/assembler.py` does that counting for you, and lets you write programs like this instead:

```
PUSH 3
loop:
PUSH 1
SUB
JZ done
JMP loop
done:
PRINT
HALT
```

A line ending in `:` is a label — a name for the byte index of whatever comes right after it. JMP and JZ can take either a plain number or a label name as their operand. `//` starts a comment, same as in `vm.s`.

Run it with a path to an `.asm` file:
```bash
python3 tools/assembler.py examples/countdown.asm
```
It prints a single line, ready to paste into `vm.s`:
```
program: .byte 1, 3, 1, 1, 3, 9, 9, 8, 2, 4, 5
```

Internally it works in two passes: the first walks the program counting bytes and records where each label lands; the second walks it again and emits the actual bytes, looking up any label name in the table the first pass built. Neither pass runs your program — they only work out what the final bytes should be.

## Build and run the VM directly

```bash
clang -o vm vm.s
./vm
```

The program the VM executes is the `.byte` line in the `.data` section at the bottom of `vm.s`. Replace it (by hand, or with the assembler's output), rebuild, and run again.

## Opcodes

| Mnemonic | Opcode | Operand | Effect |
|---|---|---|---|
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

The `examples/` folder has runnable `.asm` source for each one below. Assemble any of them with `python3 tools/assembler.py examples/<name>.asm` and paste the result into `vm.s`.

| File | What it does | Expected output |
|---|---|---|
| `multiply.asm` | `PUSH 6, PUSH 7, MUL, PRINT, HALT` | `42` |
| `negative.asm` | `PUSH 3, PUSH 4, SUB, PRINT, HALT` | `-1` |
| `skip.asm` | JMP skips over a `PUSH 99` before printing | `5` |
| `stack_juggle.asm` | PUSH/POP/MUL together; POP discards a junk value before multiplying | `42` |
| `countdown.asm` | A loop using JZ and JMP with labels, counting down to 0 | `0` |

`countdown.asm` is the best one to read end to end if you want to see labels and a real loop together:
```
PUSH 3
loop:
PUSH 1
SUB
JZ done
JMP loop
done:
PRINT
HALT
```
The stack top goes 3, 2, 1, 0. Each pass pushes 1 and subtracts it. While the result is nonzero, `JMP loop` repeats the loop body. Once it reaches 0, `JZ done` jumps to `PRINT`.

## Documentation

- [DESIGN.md](DESIGN.md): the bytecode format and opcode table
- [REGISTERS.md](REGISTERS.md): what every register holds, and why
- [CONCEPTS.md](CONCEPTS.md): how each feature works, step by step
- [DEBUGGING.md](DEBUGGING.md): the more subtle bugs hit while building this, and what they revealed

## Limitations

These are known and deliberate, to keep the project small.

- Values are one byte, so the range is -128 to 127.
- The VM stack is 256 bytes, and the program is limited to 256 bytes, since jump targets are 1-byte indices.
- There is no error checking in the VM. An unknown opcode is skipped, and popping an empty stack reads whatever bytes happen to be in memory.
- The assembler doesn't validate much either: a mistyped mnemonic or an out-of-range operand will produce a Python error or silently wrong bytes rather than a clear message.
- The assembler's output still has to be pasted into `vm.s` by hand; it doesn't write the file for you.
