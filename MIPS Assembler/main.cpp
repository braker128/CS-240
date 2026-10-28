//
// Created by Carter on 10/17/2026.
//

#include <iostream>
#include <fstream>
#include <string>
#include <iomanip>
#include <bitset>

#include "Assembler.h"
#include "Parser.h"

using namespace std;

int main() {
    // program to assemble, without .asm (outputs go next to it as .mhc-ascii / .mhc-bin)
    string baseName = R"(C:\Users\Carter\CLionProjects\CS-240\MIPS Assembler\FizzBuzz)";
    ifstream file(baseName + ".asm");

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

    // ============ Output files ============

    // every byte to write: instructions first (high byte first), then data
    vector<uint8_t> output;

    for (uint32_t word : machineCode) {
        output.push_back((word >> 24) & 0xFF);
        output.push_back((word >> 16) & 0xFF);
        output.push_back((word >> 8) & 0xFF);
        output.push_back(word & 0xFF);
    }

    const vector<uint8_t>& dataBytes = assembler.getDataBytes();
    output.insert(output.end(), dataBytes.begin(), dataBytes.end());

    while (output.size() % 4 != 0) { // pad data to a whole 32-bit line
        output.push_back(0);
    }


    // .mhc-ascii: one 32-bit word per line as 0s and 1s
    ofstream asciiFile(baseName + ".mhc-ascii");
    for (size_t i = 0; i < output.size(); i += 4) {
        uint32_t word = ((uint32_t)output[i] << 24) | ((uint32_t)output[i + 1] << 16) | ((uint32_t)output[i + 2] << 8) | output[i + 3];
        asciiFile << bitset<32>(word) << "\n";
    }

    // .mhc-bin: the same bytes, raw
    ofstream binFile(baseName + ".mhc-bin", ios::binary);
    binFile.write((const char*)output.data(), output.size());

    if (!asciiFile || !binFile) {
        cerr << "Error writing output files.\n";
        return 1;
    }

    cout << endl << "Wrote " << baseName << ".mhc-ascii and .mhc-bin (" << output.size() / 4 << " words)" << endl;

    return 0;
}