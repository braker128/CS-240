//
// Created by Carter on 10/17/2026.
//

#include "Assembler.h"

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
    else if (mnemonic == "li") {  // TODO: implement >signed-16-bit integers
        if (operands.size() != 2) {
            throw runtime_error("Invalid li operands");
        }
        int value = stoi(operands[1]); // string to integer

        if (value >= -32768 && value <= 32767) { // checks li range
            instruction.mnemonic = "addiu";
            instruction.operands = {operands[0], "$zero", operands[1]};
        }
        else {
            throw runtime_error("li immediate out of supported range");
        }
    }
    else {
        return{parsed};
    }

    expanded.push_back(instruction);
    return expanded;
}