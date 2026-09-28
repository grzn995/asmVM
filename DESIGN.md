# Bytecode format

Each instruction starts with a 1-byte opcode. Some opcodes take a 1-byte operand immediately after.
Values are 8-bit two's complement (-128 to 127). 
PUSH operands are written as bytes, so 254 is stored as -2.

| Mnemonic | Opcode | Operand? | Effect |
|---|---|---|---|
| PUSH | 0x01 | yes | push operand onto the stack |
| ADD  | 0x02 | no  | pop two, push their sum |
| SUB  | 0x03 | no  | pop two, push (second - top) |
| PRINT | 0x04 | no | pop one, print it |
| HALT | 0x05 | no | stop execution |
| POP| 0x06 | no | pops and discards the top of the stack |
| MUL | 0x07 | no | pops two values and pushes their product |
| JMP | 0x08 | yes | jump to the program index given by the operand |
| JZ | 0x09 | yes | if the top of the stack is 0, jump to the operand index; otherwise continue (the top value is not removed)|

