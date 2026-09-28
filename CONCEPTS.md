# How it works

This explains each mechanism in the VM and the assembler conceptually, in the order they were built. It assumes you've read DESIGN.md for the opcode table.

## The dispatch loop

The VM's entire execution model is one loop:

1. Read one byte from the address in `x20` (the current opcode).
2. Move `x20` forward by one.
3. Compare the byte against every known opcode, one at a time, and branch to the matching handler.
4. Each handler does its work, then jumps back to step 1.

`x20` only ever knows about individual bytes, not "instructions." An opcode that takes an operand (like PUSH) advances `x20` a second time, inside its own handler, after reading the operand. A 2-byte instruction is only 2 bytes wide because its handler does two advances, not because the loop treats it specially.

## The stack, and why the pointer sits "one past the top"

`x19` always holds the address of the next *free* slot, not the address of the top value. This is why pushing does the write before the increment (`strb`, then `add x19, x19, #1`), and every pop does the decrement before the read (`sub x19, x19, #1`, then `ldrb`).

The practical effect: any operation that wants to *read* something already on the stack (ADD, SUB, MUL, PRINT, HALT) must step `x19` back first to land on real data. Forgetting this reads garbage from an untouched memory slot instead of an actual pushed value.

POP is the simplest opcode in the VM for exactly this reason: since nothing needs to read the popped value, `do_pop` only has to move `x19` back one slot. The old byte is left in memory, untouched, but it's no longer considered part of the stack, and the next PUSH will silently overwrite it.

## Addresses vs. registers vs. brackets

A register on its own just holds a number. `[x19]` in an instruction means "treat that number as a memory address, and go there." This distinction is why `strb w1, [x19]` writes `w1`'s value into memory at the address in `x19`, while a bare `x19` in an arithmetic instruction just uses `x19`'s numeric value directly, with no memory access at all.

`adrp` + `add` is a two-instruction idiom used everywhere a label's address is needed (`vm_stack`, `program`, `print_buf`). ARM64 instructions are a fixed 4 bytes, which isn't enough room to encode a full address in one instruction, so the address is built in two steps: `adrp` gets the address of the 4KB memory page containing the label, and `add` adds the small offset within that page.

## Two's complement and signed PRINT

Every value in the VM is a single byte. Two's complement is the convention that lets that same byte represent negative numbers: if the highest bit (bit 7) is set, the byte is read as negative.

`do_print` tests this directly: `and w8, w0, #0x80` zeroes out every bit except bit 7. If the result is 0, the value is positive and printing proceeds as normal. If it's nonzero, the value is negative, and its true magnitude is `256 - value` (a fixed relationship for 8-bit two's complement). The VM prints a `-` character, computes the magnitude, and then falls through into the same digit-printing code used for positive numbers — the digit extraction itself never needs to know about signs.

Without this check, PRINT would just extract digits from the raw byte, so `-1` (stored as `255`) would print as `255` instead. The `exit` code shown by `echo $?` behaves the same way: it always displays the raw byte as unsigned 0-255, since the shell has no way to know whether a program's exit code was "meant" to be signed.

## Extracting digits by repeated division

To turn a number into printable digits, `do_print` repeatedly divides by 10:

- `udiv` gives the quotient: the number with its last digit removed.
- `msub` recovers what division discarded: `value - (quotient * 10)`, which is exactly the last digit.

Each pass extracts one digit, always from the end of the number, and each digit comes out in reverse order (last digit first). To print them in the correct order, they're written into a small buffer back-to-front: the loop starts at the buffer's last content slot and moves one slot to the left after every digit. By the time the loop ends (the quotient reaches 0), the buffer holds the digits in correct left-to-right order, regardless of how many digits there were. `print_it` then figures out the actual starting position and length from where the write index ended up, rather than counting digits separately.

The zero case is handled separately, before the loop runs at all: dividing 0 by 10 immediately gives quotient 0, so the loop would exit on its first check without ever writing a digit. A short special case writes `'0'` directly.

## Jumps: converting an index into an address

JMP and JZ take an operand that's an *index* — "byte number N of the program" — not a memory address. Converting one to the other needs the address of byte 0, which is why `x22` exists: it's saved once at startup and never changes, unlike `x20`, which moves forward on every instruction and can't be used to reconstruct where the program started.

`do_jmp` reads the target index, computes `x22 + index`, and writes that directly into `x20` — overwriting the program counter completely, which is what makes execution continue from a different point instead of the next byte in sequence.

`do_jz` does the same computation, but only when the top of the stack is 0. Critically, it *peeks* at the stack instead of popping: `ldrb w0, [x19, #-1]` reads the value one slot before `x19` without moving `x19` at all. This matters for loops that check a counter repeatedly — if checking it destroyed it, there'd be no way to use it again on the next pass without some way to put it back.

## Why loops need both JMP and JZ

JMP alone can only move execution somewhere and keep going — useful for skipping code, but on its own it can only produce an infinite loop, since nothing ever decides to stop. JZ alone can only skip forward conditionally. A loop that runs a fixed number of times needs both: JZ checks an exit condition each pass and jumps *out* when it's met; JMP unconditionally sends execution *back* to the top of the loop body when the condition isn't met yet.

The countdown-from-3 example (`examples/countdown.asm`) shows this: each pass subtracts 1 from a counter and checks (via JZ) whether it reached 0. If not, JMP sends execution back to subtract again. Only when JZ's condition is finally true does execution fall through, print, and halt.

## Labels and the two-pass assembler

Writing `JMP 2` by hand means counting how many bytes every earlier instruction occupies — tedious, and it breaks the moment a line is added or removed anywhere before it. The assembler (`tools/assembler.py`) exists to remove that counting: it lets you write `JMP loop` instead, where `loop` is just a name attached to a specific line, and figures out the real number itself.

A label is a name that stands for a byte index, nothing more. Writing `loop:` on its own line doesn't produce any bytes — it's a marker saying "remember this position," attached to whatever index the next real instruction ends up at. The VM never sees the word `loop` at all; by the time the assembler is done, every label has been replaced with the plain number it stood for.

This is why the assembler has to make two separate passes over the source rather than one:

- **Pass one** (`build_label_table`) walks the program purely to count. It doesn't care what any instruction *does* — only whether it takes 1 byte or 2 — and every time it passes a label, it records the current count against that label's name. It emits no bytes at all; its only output is a dictionary like `{"loop": 2, "done": 9}`.
- **Pass two** (`assemble`) walks the same program again, this time actually building the byte list. For every operand, it checks whether the text is a plain number (`"3"`) or a name (`"loop"`); a plain number is converted directly, while a name is looked up in the table pass one already built.

The two passes have to happen in this order and can't be merged into one, because pass two might need to resolve a label (like `JMP loop`, jumping *backward*) that pass one hasn't necessarily counted differently than a *forward* reference (`JZ done`, jumping to a line later in the file it hasn't reached yet). By finishing the counting pass completely before resolving any operand, the assembler never has to guess at a label it hasn't seen yet — every label's final index is already known before pass two even starts.
