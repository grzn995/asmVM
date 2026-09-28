# Advanced bugs and fixes

Syntax typos (missing commas, wrong opcode numbers, mismatched labels) aren't included here — they're mechanical and easy to spot by rereading the file. This file covers the bugs that came from a genuine misunderstanding of how the machine behaves, where the code looked reasonable and the failure only showed up once you knew what to look for.

## The `write` syscall clobbering registers mid-computation

**The setup:** `do_print`'s negative-number path needs to do two separate things — print a `-` character, and then still go on to print the digits of the magnitude. Printing the `-` means making a full `write` syscall in the middle of the handler, before the actual digit-printing work has even started.

**The bug:** the original value being printed was sitting in `w0`, and the buffer address was sitting in `x1`. A `write` syscall needs `x0` (fd), `x1` (buffer address), and `x2` (length) set as its arguments — and the syscall itself is free to change any of the argument/scratch registers (`x0`–`x18`) as part of doing its job. Setting up the syscall for the `-` character meant overwriting `x1` with the address of the `-` character's one-byte buffer slot, and the syscall's own internals could disturb other scratch registers too. By the time the syscall returned, the original `x1` (pointing at `print_buf`) and potentially `w0` (the value to print) were no longer trustworthy — code that assumed they still held what was set before the syscall was reading corrupted state.

**The fix:** save anything that needs to survive the syscall into a register the syscall has no reason to touch, before making the call, and restore it afterward. Specifically: `mov w11, w0` before the `-` is printed, and after the syscall returns, `mov w0, w11` to restore the value, plus recomputing `x1` with a fresh `adrp`/`add` pair rather than assuming it survived.

**The general lesson:** any register holding state you still need *after* a syscall (or any subroutine call) has to be explicitly protected — either by copying it somewhere safe first, or by recomputing it fresh afterward rather than trusting it wasn't touched. This is exactly why ARM64's calling convention designates some registers as "caller-saved" (assumed to be destroyed by any call) and others as "callee-saved" (guaranteed to survive) — `x19`–`x28` are callee-saved by convention, which is part of why the VM's own long-lived state (`x19` the stack pointer, `x20` the program counter, and later `x21`/`x22`) was deliberately kept there rather than in the lower registers, even though nothing in this VM makes actual subroutine calls that rely on the convention. The syscall bug is the same category of problem showing up without a formal function call boundary.

## A register already committed to another job

**The setup:** implementing jumps required a new permanent register to hold the program's base address, separate from `x20` (which moves every instruction). The plan going in specified `x21` for this.

**The bug:** by the time jumps were actually implemented, `x21` had already been claimed for something else — it held the *stack's* base address, added earlier to let `do_halt` detect an empty stack (`cmp x19, x21`). Using `x21` for the program base too would have meant one of the two permanent values silently overwriting the other the moment both features' setup code ran, with no error at build or run time — just one of the two features quietly reading the wrong address.

**The fix:** move the program-base address to `x22` instead, leaving `x21` exclusively as the stack base. No code using `x21` needed to change; only the newly-written jump setup and handlers needed the different register number.

**The general lesson:** as a project grows past its original plan, a register number chosen for a feature designed in isolation can collide with one already committed elsewhere. There's no compiler warning for this on purpose — from the CPU's perspective, reusing a register for two unrelated permanent values is completely legal, it's just wrong for the program's logic. The only defense is tracking, deliberately, which registers are already "owned" by existing long-lived state before assigning a new one (see REGISTERS.md).

## JZ corrupting execution when the jump isn't taken

**The setup:** `do_jz` needs to read its own operand (the jump target index) regardless of whether the jump actually happens, because the operand byte is physically sitting in the bytecode either way and has to be accounted for.

**The bug:** an early version read the operand but only advanced the program counter past it along the *taken* branch, not the not-taken one. When the condition was false and execution fell through to just continue with `b loop`, the program counter was still pointing at the operand byte — which then got read and interpreted as if it were the *next opcode*. Depending on what number that operand byte happened to be, this could dispatch to a completely unrelated handler, or silently do nothing and merely desynchronize every subsequent read by one byte for the rest of the program. Unlike the earlier ADD/opcode-number bugs, this didn't just produce one wrong number — it could derail everything that ran afterward, since the program counter never resynchronized on its own.

**The fix:** the program-counter advance past an operand has to happen unconditionally, before any branch on the condition, exactly mirroring how `do_push` always advances past its operand regardless of what happens next. Conditional logic belongs entirely *after* the bytecode has been fully and correctly consumed, never mixed into it.

**The general lesson:** in a fetch-decode-execute loop, "how many bytes this instruction occupies" and "what this instruction does" are two separate concerns, and the first one can never be made conditional on the second. Every opcode with an operand must advance the program counter past that operand on every code path, before any decision that depends on the instruction's meaning.

## Two's complement meaning depending entirely on interpretation

**Not a bug, but the pitfall behind one:** `sub w3, w1, w0` computing `3 - 4` produces the bit pattern `11111111` — this is unambiguously correct, and the instruction never does anything wrong. Whether those bits mean `255` or `-1` is entirely a question of which convention whatever reads them later chooses to apply. `echo $?` always applies the unsigned convention (0-255) with no exception, while a `PRINT` that checks bit 7 applies the signed convention. Neither is "more correct" — they're different, valid interpretations of the same physical bits.

The practical trap: it's easy to conclude "my subtraction is broken" when what's actually happening is that two different parts of the system (the exit code display vs. a hand-written PRINT) are reading identical bits under different rules. Confirming this required deliberately computing the same value both ways and checking that the *bit pattern* matched expectations, rather than trusting either displayed number in isolation.
