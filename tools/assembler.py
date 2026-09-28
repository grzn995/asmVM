import sys



OPCODES = {
    "PUSH": (1, True),
    "ADD":  (2, False),
    "SUB":  (3, False),
    "PRINT":(4, False),
    "HALT": (5, False),
    "POP":  (6, False),
    "MUL":  (7, False),
    "JMP":  (8, True),
    "JZ":   (9, True),
}




def loadLines(filename):
    with open(filename) as f:
        rawLines = f.readlines()
        cleaned = []
        
        for line in rawLines:
            line = line.split("//")[0].strip()

            if line == "":
                continue

            cleaned.append(line)

    return cleaned

def buildLabelTable(lines):
    labels = {}
    index = 0
    for line in lines: 
        if line.endswith(":"):
            labelName = line.rstrip(":")
            labels[labelName] = index
        else:
            words = line.split()
            firstWord = words[0]
            opcodeNumber, hasOperand = OPCODES[firstWord]
            if hasOperand:
                index += 1
            index += 1


    return labels

def assemble(labels,lines):
    bytecode = []
    for line in lines:
        if line.endswith(":"):
            continue

        words = line.split()
        firstWord = words[0]
        opcodeNumber, hasOperand = OPCODES[firstWord]

        bytecode.append(opcodeNumber)

        if hasOperand:
            operand = words[1]
            if operand.isdigit():
                bytecode.append(int(operand))
            else:
                bytecode.append(labels[operand])

    return bytecode



if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python3 tools/assembler.py <path-to-asm-file>")
        sys.exit(1)

    filename = sys.argv[1]
    lines = loadLines(filename)
    labels = buildLabelTable(lines)
    bytecode = assemble(labels, lines)
    joined = ", ".join(str(b) for b in bytecode)
    print(f"program: .byte {joined}")
