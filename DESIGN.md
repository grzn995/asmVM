# Bytecode format

Each instruction starts with a 1-byte opcode. Some opcodes take a 1-byte operand immediately after.

| Mnemonic | Opcode | Operand? | Effect |
|---|---|---|---|
| PUSH | 0x01 | yes | push operand onto the stack |
| ADD  | 0x02 | no  | pop two, push their sum |
| SUB  | 0x03 | no  | pop two, push (second - top) |
| PRINT | 0x04 | no | pop one, print it |
| HALT | 0x05 | no | stop execution |
