# Register map

This lists every register `vm.s` uses, what it holds, and how long that value lasts. Registers not listed (like `x4`, `x13`, and so on) are unused.

## Long-lived registers

These are set up once in `_main` and keep their meaning for the entire run. They are never repurposed for scratch work, which is what makes them safe to rely on across every handler.

| Register | Holds | Set in |
|---|---|---|
| `x19` | Stack pointer: the address of the next free slot on the VM stack. Points one slot *past* the top value, never at it. | `_main`, updated by every push/pop |
| `x20` | Program counter: the address of the next byte to read from the program. Moves forward by default; overwritten directly by JMP and JZ. | `_main`, updated every loop pass |
| `x21` | Stack base: the address of the bottom of `vm_stack`, saved once at startup. Used by `do_halt` to detect an empty stack (`x19 == x21`). | `_main` |
| `x22` | Program base: the address of the first byte of `program`, saved once at startup. Used by JMP and JZ to convert a bytecode index into an address (`address = x22 + index`). | `_main` |

## Scratch registers

These are reused across different opcode handlers. Their contents are only meaningful within the handler currently running, and a value in one of these should never be assumed to survive from one opcode to the next.

| Register | Typical use |
|---|---|
| `w0` | The opcode just read, at the top of `loop`. Reused inside most handlers as the first popped stack value, and in `do_print` as the value being printed / the sign-adjusted magnitude. |
| `w1` | The operand byte for PUSH, JMP, and JZ. Reused in ADD/SUB/MUL as the second popped stack value. |
| `w2` | The peeked stack value in `do_jz`, held separately from `w1` (the JZ operand) so the two don't overwrite each other. Also used as `x2`, the byte count passed to the `write` syscall in `do_print`. |
| `w3` | The computed result in ADD/SUB/MUL, before it's written back to the stack. In `do_print`, holds the newline character (`0x0A`) before it's stored. |
| `w5`, `w6`, `w7` | Digit extraction in `do_print`'s `digit_loop`: divisor (`w5`), quotient (`w6`), remainder/digit (`w7`). |
| `w8` | The result of `AND`-ing the popped value with `0x80` in `do_print`, used to test the sign bit. |
| `w9` | The `-` character (`0x2D`) in `do_print`'s negative-number path. Also reused as `x9`, the starting index of the printed digits in `print_it`. |
| `w10` | Holds `256` in `do_print`, used to compute the magnitude of a negative value (`256 - value`). |
| `w11` | Saves the original popped value in `do_print` before the sign is checked, since `w0` gets overwritten by the `write` syscall for the `-` character. |
| `w12` | The ASCII character `'0'` (`0x30`), used only in the zero special case in `do_print`. |
| `x1` | The address of `print_buf` in `do_print`. Also the buffer address argument (and later, the shifted start-of-text address) for the `write` syscall. |
| `x5` | The calculated number of bytes to print, in `print_it`. |
| `x16` | The syscall number. `1` for exit, `4` for write. Set immediately before every `svc`. |

## Why some values get saved into unusual registers

`do_print`'s negative-number path calls the `write` syscall once (to print the `-` character) before it's done processing the number. System calls are free to change `w0`–`w2` and other argument registers, so if the actual value being printed were left sitting in one of those, the syscall could silently destroy it. That's why the original value is copied into `w11` first — a register the syscall has no reason to touch — and restored into `w0` only after the `-` has been printed.

This is the same reason the VM reserves `x19`–`x22` for long-lived state instead of `x0`–`x18`: by convention those lower registers are considered fair game for any called routine (including a syscall) to overwrite, while `x19` and up are expected to survive.
