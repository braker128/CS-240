//
// Created by Carter on 10/17/2026.
//

#include <cstdint>
#include <stdexcept>

#include "Assembler.h"
#include "ParsedLine.h"
#include "Encoder.h"

using namespace std;


vector<ParsedLine> Assembler::expandPseudo(const ParsedLine& parsed) {

    vector<ParsedLine> expanded;

    string mnemonic = parsed.mnemonic;
    vector<string> operands = parsed.operands;

    ParsedLine instruction;
    instruction.lineNumber = parsed.lineNumber;
    instruction.label = parsed.label;

    if (mnemonic == "move") {
        if (operands.size() != 2) {
            throw runtime_error("Invalid move operands");
        }
        instruction.mnemonic = "addu";
        instruction.operands = {operands[0], operands[1], "$zero"};
    }


    else if (mnemonic == "nop") {
        if (!operands.empty()) {
            throw runtime_error("Invalid nop operands");
        }
        instruction.mnemonic = "sll";
        instruction.operands = {"$zero", "$zero", "0"};
    }


    else if (mnemonic == "b") {
        if (operands.size() != 1) {
            throw runtime_error("Invalid b operands");
        }
        instruction.mnemonic = "beq";
        instruction.operands = {"$zero", "$zero", operands[0]};
    }


    else if (mnemonic == "li") {
        if (operands.size() != 2) {
            throw runtime_error("Invalid li operands");
        }

        int value;

        if (operands[1] == R"('\n')"){ value = '\n';}
        else if (operands[1] == R"('\t')"){ value = '\t';}
        else if (operands[1].size() == 3 && operands[1][0] == '\'' && operands[1][2] == '\'') { value = operands[1][1];} // if 3 chars, 'A' and starts with ' and ends with '
        else {value = stoi(operands[1], nullptr, 0);}

        if (value >= -32768 && value <= 32767) { // checks li range to 16 bits
            instruction.mnemonic = "addiu";
            instruction.operands = {operands[0], "$zero", to_string(value)};
        }
        else { // handle 17-32 bit numbers
            uint32_t upper = (uint32_t)value >> 16;
            uint32_t lower = (uint32_t)value & 0xFFFF;

            instruction.mnemonic = "lui";
            instruction.operands = {operands[0], to_string(upper)};
            expanded.push_back(instruction);

            instruction.mnemonic = "ori";
            instruction.operands = {operands[0], operands[0], to_string(lower)};
            instruction.label = "";
            expanded.push_back(instruction);

            return expanded;
        }
    }

    else if (mnemonic == "rem") {
        if (operands.size() != 3) {
            throw runtime_error("Invalid rem operands");
        }

        // Divide source registers
        instruction.mnemonic = "div";
        instruction.operands = {operands[1], operands[2]};

        expanded.push_back(instruction);

        // remainder -> $rt
        instruction.mnemonic = "mfhi";
        instruction.operands = {operands[0]};
        instruction.label = "";

        expanded.push_back(instruction);

        return expanded;
    }

    else if (mnemonic == "la") {
        if (operands.size() != 2) {
            throw runtime_error("Invalid la operands");
        }

        // label address isn't known until pass 1 finishes, so pass 2 fills in %hi / %lo
        instruction.mnemonic = "lui";
        instruction.operands = {"$at", "%hi(" + operands[1] + ")"};
        expanded.push_back(instruction);

        instruction.mnemonic = "ori";
        instruction.operands = {operands[0], "$at", "%lo(" + operands[1] + ")"};
        instruction.label = "";
        expanded.push_back(instruction);

        return expanded;
    }

    else {
        return{parsed};
    }

    expanded.push_back(instruction);
    return expanded;
}



// ============ Pass 1 ============


// MARS default segment start addresses
static const uint32_t TEXT_START = 0x00400000;
static const uint32_t DATA_START = 0x10010000;

// number of bytes a data directive takes up
static uint32_t dataSize(const ParsedLine& parsed) {
    const string& directive = parsed.mnemonic;
    const vector<string>& operands = parsed.operands;

    if (directive == ".asciiz" || directive == ".ascii") {
        if (operands.size() != 1 || operands[0].size() < 2 || operands[0].front() != '"' || operands[0].back() != '"') {
            throw runtime_error("Invalid string on line " + to_string(parsed.lineNumber));
        }

        const string& text = operands[0];

        // count characters between the quotes, an escape like \n is one byte
        uint32_t length = 0;
        for (size_t i = 1; i + 1 < text.size(); i++) {
            if (text[i] == '\\') {
                i++;
            }
            length++;
        }

        return (directive == ".asciiz") ? length + 1 : length; // +1 for the null terminator
    }

    if (directive == ".word") {
        return 4 * operands.size();
    }

    if (directive == ".byte") {
        return operands.size();
    }

    if (directive == ".space") {
        if (operands.size() != 1) {
            throw runtime_error("Invalid .space operands on line " + to_string(parsed.lineNumber));
        }
        return stoul(operands[0], nullptr, 0);
    }

    throw runtime_error("Unsupported directive: " + directive + " on line " + to_string(parsed.lineNumber));
}



void Assembler::firstPass(const vector<ParsedLine>& parsedLines) {

    bool inText = true; // .text if no directive
    uint32_t textAddress = TEXT_START;
    uint32_t dataAddress = DATA_START;

    symbols.clear();
    textInstructions.clear();

    for (const ParsedLine& parsed : parsedLines) {
        const string& mnemonic = parsed.mnemonic;

        // section switches
        if (mnemonic == ".text") {
            inText = true;
        }
        else if (mnemonic == ".data") {
            inText = false;
        }

        // .word must start on a 4-byte boundary, so align before the label gets its address
        if (!inText && mnemonic == ".word") {
            dataAddress = (dataAddress + 3) & ~3u;
        }

        // record label at the current address of whichever section we're in
        if (!parsed.label.empty()) {
            if (symbols.count(parsed.label)) {
                throw runtime_error("Duplicate label: " + parsed.label + " on line " + to_string(parsed.lineNumber));
            }
            symbols[parsed.label] = inText ? textAddress : dataAddress;
        }

        // label-only lines and section/globl directives take no space
        if (mnemonic.empty() || mnemonic == ".text" || mnemonic == ".data" || mnemonic == ".globl") {
            continue;
        }

        if (inText) {
            vector<ParsedLine> expanded = expandPseudo(parsed);
            for (const ParsedLine& instruction : expanded) {
                textInstructions.push_back(instruction);
                textAddress += 4;
            }
        }
        else {
            dataAddress += dataSize(parsed);
        }
    }
}