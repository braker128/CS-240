//
// Created by Carter on 10/17/2026.
//

#include "Assembler.h"

#include <cstdint>
#include <stdexcept>

#include "ParsedLine.h"


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

    else {
        return{parsed};
    }

    expanded.push_back(instruction);
    return expanded;
}