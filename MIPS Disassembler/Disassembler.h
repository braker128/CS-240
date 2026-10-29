//
// Created by comet on 10/22/2026.
//

#pragma once
#include <cstdint>
#include <map>
#include <string>
#include <vector>

using namespace std;

// one decoded instruction, split into pieces (like ParsedLine in the assembler)
struct Instruction {
    string mnemonic;          // "" if the word isn't an instruction
    vector<string> operands;
};

class Disassembler {
public:
    // runs every step and writes filename_DISASSEMBLED.asm next to the input, returns the program text
    string disassemble(const string& inputPath);

private:
    vector<uint32_t> words;             // every 32-bit word in the file, words[0] is at 0x00400000
    size_t textWords = 0;               // how many words are instructions (the rest is .data)
    map<uint32_t, string> labels;       // .text address -> label name (L0, L1, ...)
    map<uint32_t, string> dataLabels;   // .data address -> label name (data0, data1, ...)

    // 1. Check whether machine code or ascii binary
    void readWords(const string& path);

    // 2. Determine directives and labels
    void findDirectives();
    void findLabels();
    vector<uint8_t> dataBytes() const;

    // 3. Convert directives and labels to ascii
    string dataToAscii() const;
    string labelFor(uint32_t address) const;

    // 4. Divide R, I, and J functions by opcode
    char instructionType(uint32_t word) const;

    // 5. Convert R, I, J functions into ascii pieces
    Instruction decode(uint32_t word, uint32_t address) const;
    Instruction decodeR(uint32_t word) const;
    Instruction decodeI(uint32_t word, uint32_t address) const;
    Instruction decodeJ(uint32_t word, uint32_t address) const;
    bool decodeLoadAddress(size_t index, Instruction& instruction) const;

    // 6. Assemble ascii functions together
    string textToAscii() const;
};
