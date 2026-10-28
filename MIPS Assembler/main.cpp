//
// Created by Carter on 10/17/2026.
//

#include <iostream>
#include <fstream>
#include <string>
#include <iomanip>

#include "Assembler.h"
#include "Parser.h"

using namespace std;

int main() {
    ifstream file(R"(C:\Users\Carter\CLionProjects\CS-240\MIPS Assembler\FizzBuzz.asm)");

    if (!file.is_open()) {
        cerr << "Error opening file.\n";
        return 1;
    }

    Parser parser;
    string line;
    int lineNumber = 0;

    vector<ParsedLine> parsedLines; // dynamic array holding line info

    while (getline(file, line)) {
        lineNumber++;
        ParsedLine parsed = parser.parseLine(line, lineNumber);

        // skip empty lines, keep labels
        if (parsed.mnemonic.empty() && parsed.label.empty()) {
            continue;
        }

        parsedLines.push_back(parsed);
    }

    Assembler assembler;
    vector<uint32_t> machineCode;

    try {
        assembler.firstPass(parsedLines);
        machineCode = assembler.secondPass();
    } catch (const exception& e) { // any assembler error, ex: "Undefined label: fizz on line 21"
        cerr << "Error: " << e.what() << endl;
        return 1;
    }

    cout << "Symbols:" << endl;
    for (const auto& symbol : assembler.getSymbols()) {
        cout << "  " << symbol.first << " = 0x" << hex << setw(8) << setfill('0') << symbol.second << dec << endl;
    }

    cout << endl << "Text:" << endl;
    const vector<ParsedLine>& instructions = assembler.getTextInstructions();
    uint32_t address = 0x00400000;

    for (size_t i = 0; i < instructions.size(); i++) {
        cout << "  0x" << hex << setw(8) << setfill('0') << address << "  0x" << setw(8) << machineCode[i] << dec << "  " << instructions[i].mnemonic;
        for (const string& operand : instructions[i].operands) {
            cout << " " << operand;
        }
        cout << endl;
        address += 4;
    }

    return 0;
}