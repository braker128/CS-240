//
// Created by Carter on 10/17/2026.
//

#include <iostream>
#include <fstream>
#include <string>
#include "Parser.h"

using namespace std;

int main() {
    ifstream file(R"(C:\Users\Carter\CLionProjects\CS-240\MIPS Assembler\FizzBuzz.asm)");

    if (!file.is_open()) {
        cerr << "Error opening file!\n";
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

    // Printing
    for (const ParsedLine& parsed : parsedLines) {
        cout << "Line: " << parsed.lineNumber << endl;
        cout << "Mnemonic: " << parsed.mnemonic << endl;
        cout << "Label: " << parsed.label << endl;

        for (const string& operand : parsed.operands) {
            cout << "Operand: " << operand << endl;
        }

        cout << endl;
    }

    return 0;
}