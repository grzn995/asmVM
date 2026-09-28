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



if __name__ == "__main__":
    lines = loadLines("test.asm")
    print(lines)
