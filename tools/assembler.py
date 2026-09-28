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



if __name__ == "__main__":
    test_lines = ["PUSH", "loop:", "PUSH", "SUB", "JZ", "JMP", "done:", "PRINT", "HALT"]
    print(buildLabelTable(test_lines))
