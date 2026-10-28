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
    assembler.firstPass(parsedLines);

    cout << "Symbols:" << endl;
    for (const auto& symbol : assembler.getSymbols()) {
        cout << "  " << symbol.first << " = 0x" << hex << setw(8) << setfill('0') << symbol.second << dec << endl;
    }

    cout << endl << "Text:" << endl;
    uint32_t address = 0x00400000;
    for (const ParsedLine& instruction : assembler.getTextInstructions()) {
        cout << "  0x" << hex << setw(8) << setfill('0') << address << dec << "  " << instruction.mnemonic;
        for (const string& operand : instruction.operands) {
            cout << " " << operand;
        }
        cout << endl;
        address += 4;
    }

    return 0;
}