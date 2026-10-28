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
            throw runtime_error("Invalid li operands on line " + to_string(parsed.lineNumber));
        }

        const string& text = operands[1];
        long long value; // long long so 0xFFFFFFFF fits

        if (text.size() == 3 && text[0] == '\'' && text[2] == '\'') { // 'A'
            value = text[1];
        }
        else if (text.size() == 4 && text[0] == '\'' && text[1] == '\\' && text[3] == '\'') { // '\n' etc.
            switch (text[2]) {
                case 'n': value = '\n'; break;
                case 't': value = '\t'; break;
                case 'r': value = '\r'; break;
                case '0': value = '\0'; break;
                case '\\': value = '\\'; break;
                case '\'': value = '\''; break;
                case '"': value = '"'; break;
                default: throw runtime_error("Invalid character " + text + " on line " + to_string(parsed.lineNumber));
            }
        }
        else {
            try {
                value = stoll(text, nullptr, 0);
            } catch (const exception&) { // stoll throws for "abc" or huge numbers
                throw runtime_error("Invalid li value " + text + " on line " + to_string(parsed.lineNumber));
            }
        }

        if (value < -2147483648LL || value > 4294967295LL) { // has to fit in 32 bits, signed or unsigned
            throw runtime_error("li value out of range on line " + to_string(parsed.lineNumber));
        }

        if (value >= -32768 && value <= 32767) { // fits in signed 16 bits
            instruction.mnemonic = "addiu";
            instruction.operands = {operands[0], "$zero", to_string(value)};
        }
        else if (value >= 0 && value <= 65535) { // fits in unsigned 16 bits
            instruction.mnemonic = "ori";
            instruction.operands = {operands[0], "$zero", to_string(value)};
        }
        else { // needs all 32 bits
            uint32_t upper = (uint32_t)value >> 16;
            uint32_t lower = (uint32_t)value & 0xFFFF;

            instruction.mnemonic = "lui";
            instruction.operands = {"$at", to_string(upper)};
            expanded.push_back(instruction);

            instruction.mnemonic = "ori";
            instruction.operands = {operands[0], "$at", to_string(lower)};
            instruction.label = "";
            expanded.push_back(instruction);

            return expanded;
        }
    }

    else if (mnemonic == "rem" || ((mnemonic == "div" || mnemonic == "divu") && operands.size() == 3)) {
        if (operands.size() != 3) {
            throw runtime_error("Invalid " + mnemonic + " operands on line " + to_string(parsed.lineNumber));
        }

        string divisor = operands[2];

        // divisor is a number, load it into $at first, ex: div $t0, $t1, 10
        if (divisor[0] != '$') {
            for (const ParsedLine& loaded : loadAt(divisor, parsed)) {
                expanded.push_back(loaded);
            }
            instruction.label = ""; // label is already on the first li instruction
            divisor = "$at";
        }

        // Divide source registers
        instruction.mnemonic = (mnemonic == "divu") ? "divu" : "div";
        instruction.operands = {operands[1], divisor};

        expanded.push_back(instruction);

        // rem: remainder is in hi, div: quotient is in lo
        instruction.mnemonic = (mnemonic == "rem") ? "mfhi" : "mflo";
        instruction.operands = {operands[0]};
        instruction.label = "";

        expanded.push_back(instruction);

        return expanded;
    }

    else if ((mnemonic == "add" || mnemonic == "addu" || mnemonic == "sub" || mnemonic == "subu"
              || mnemonic == "and" || mnemonic == "or" || mnemonic == "xor" || mnemonic == "nor"
              || mnemonic == "slt" || mnemonic == "sltu" || mnemonic == "mul")
             && operands.size() == 3 && operands[2][0] != '$') {

        // last operand is a number, load it into $at first, ex: mul $t0, $s0, 2
        for (const ParsedLine& loaded : loadAt(operands[2], parsed)) {
            expanded.push_back(loaded);
        }

        instruction.mnemonic = mnemonic;
        instruction.operands = {operands[0], operands[1], "$at"};
        instruction.label = ""; // label is already on the first li instruction
    }

    else if (mnemonic == "beqz" || mnemonic == "bnez") {
        if (operands.size() != 2) {
            throw runtime_error("Invalid " + mnemonic + " operands on line " + to_string(parsed.lineNumber));
        }

        // compare against $zero
        instruction.mnemonic = (mnemonic == "beqz") ? "beq" : "bne";
        instruction.operands = {operands[0], "$zero", operands[1]};
    }

    else if (((mnemonic == "beq" || mnemonic == "bne") && operands.size() == 3 && operands[1][0] != '$') // beq $v0, 0, quit
             || mnemonic == "blt" || mnemonic == "bgt" || mnemonic == "ble" || mnemonic == "bge"
             || mnemonic == "bltu" || mnemonic == "bgtu" || mnemonic == "bleu" || mnemonic == "bgeu") {
        if (operands.size() != 3) {
            throw runtime_error("Invalid " + mnemonic + " operands on line " + to_string(parsed.lineNumber));
        }

        string rs = operands[0];
        string rt = operands[1];
        string label = operands[2];

        // second operand is a number or character, load it into $at first
        if (rt[0] != '$') {
            ParsedLine load;
            load.lineNumber = parsed.lineNumber;
            load.label = parsed.label;
            load.mnemonic = "li";
            load.operands = {"$at", rt};

            for (const ParsedLine& loaded : expandPseudo(load)) { // li may be 1 or 2 instructions
                expanded.push_back(loaded);
            }

            instruction.label = ""; // label is already on the first li instruction
            rt = "$at";
        }

        // beq / bne only needed the immediate loaded
        if (mnemonic == "beq" || mnemonic == "bne") {
            instruction.mnemonic = mnemonic;
            instruction.operands = {rs, rt, label};
            expanded.push_back(instruction);

            return expanded;
        }

        bool isUnsigned = (mnemonic.back() == 'u');            // bltu, bgtu, bleu, bgeu
        string comparison = mnemonic.substr(0, 3);             // blt, bgt, ble, bge

        // $at = 1 if (rs < rt) for blt/bge, (rt < rs) for bgt/ble
        instruction.mnemonic = isUnsigned ? "sltu" : "slt";
        if (comparison == "blt" || comparison == "bge") {
            instruction.operands = {"$at", rs, rt};
        }
        else {
            instruction.operands = {"$at", rt, rs};
        }
        expanded.push_back(instruction);

        // blt/bgt branch when $at is 1, ble/bge branch when $at is 0
        instruction.mnemonic = (comparison == "blt" || comparison == "bgt") ? "bne" : "beq";
        instruction.operands = {"$at", "$zero", label};
        instruction.label = "";
        expanded.push_back(instruction);

        return expanded;
    }

    else if ((mnemonic == "lw" || mnemonic == "sw" || mnemonic == "lb" || mnemonic == "lbu"
              || mnemonic == "lh" || mnemonic == "lhu" || mnemonic == "sb" || mnemonic == "sh")
             && operands.size() == 2 && operands[1].find('(') == string::npos) {

        // address is a label instead of offset($base), ex: lw $t0, ui_bg or sb $zero, buf+1
        string label = operands[1];
        string offset = "0";

        size_t plus = label.find('+');
        if (plus != string::npos) { // buf+1 -> label buf, offset 1
            offset = label.substr(plus + 1);
            label = label.substr(0, plus);
        }

        // same as la $at, label
        instruction.mnemonic = "lui";
        instruction.operands = {"$at", "%hi(" + label + ")"};
        expanded.push_back(instruction);

        instruction.mnemonic = "ori";
        instruction.operands = {"$at", "$at", "%lo(" + label + ")"};
        instruction.label = "";
        expanded.push_back(instruction);

        // then a normal load / store from offset($at)
        instruction.mnemonic = mnemonic;
        instruction.operands = {operands[0], offset + "($at)"};
        expanded.push_back(instruction);

        return expanded;
             }

    else if (mnemonic == "la") {
        if (operands.size() != 2) {
            throw runtime_error("Invalid la operands");
        }

        // label address unknown until after pass 1, pass 2 fills in %hi / %lo
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

// li $at, value for pseudo-instructions that need a number in a register
// returns 1 or 2 instructions, the original line's label goes on the first one
vector<ParsedLine> Assembler::loadAt(const string& value, const ParsedLine& parsed) {
    ParsedLine load;
    load.lineNumber = parsed.lineNumber;
    load.label = parsed.label;
    load.mnemonic = "li";
    load.operands = {"$at", value};

    return expandPseudo(load);
}


// ============ Pass 1 ============


// MARS default start addresses
static const uint32_t TEXT_START = 0x00400000;
static const uint32_t DATA_START = 0x10010000;

// bytes of a .asciiz / .ascii string, an escape like \n is one byte
static vector<uint8_t> stringBytes(const ParsedLine& parsed) {
    const string& directive = parsed.mnemonic;
    const vector<string>& operands = parsed.operands;

    if (directive != ".asciiz" && directive != ".ascii") {
        throw runtime_error("Unsupported directive: " + directive + " on line " + to_string(parsed.lineNumber));
    }

    if (operands.size() != 1 || operands[0].size() < 2 || operands[0].front() != '"' || operands[0].back() != '"') {
        throw runtime_error("Invalid string on line " + to_string(parsed.lineNumber));
    }

    const string& text = operands[0];
    vector<uint8_t> bytes;

    for (size_t i = 1; i + 1 < text.size(); i++) { // between the quotes
        char c = text[i];

        if (c == '\\') { // escape, use the next character
            i++;
            if (text[i] == 'n') { c = '\n'; }
            else if (text[i] == 't') { c = '\t'; }
            else if (text[i] == '0') { c = '\0'; }
            else { c = text[i]; } // \" \\ \'
        }

        bytes.push_back((uint8_t)c);
    }

    if (directive == ".asciiz") {
        bytes.push_back(0); // null terminator
    }

    return bytes;
}



void Assembler::firstPass(const vector<ParsedLine>& parsedLines) {

    bool inText = true; // .text if no directive
    uint32_t textAddress = TEXT_START;

    unordered_map<string, string> constants; // .eqv name -> replacement text

    symbols.clear();
    textInstructions.clear();
    dataBytes.clear();

    for (const ParsedLine& original : parsedLines) {
        ParsedLine parsed = original; // copy so .eqv names can be replaced
        const string& mnemonic = parsed.mnemonic;

        // .eqv NAME value
        if (mnemonic == ".eqv") {
            if (parsed.operands.size() != 2) {
                throw runtime_error("Invalid .eqv operands on line " + to_string(parsed.lineNumber));
            }
            if (constants.count(parsed.operands[0])) {
                throw runtime_error("Duplicate .eqv: " + parsed.operands[0] + " on line " + to_string(parsed.lineNumber));
            }
            constants[parsed.operands[0]] = parsed.operands[1];
            continue;
        }

        // replace .eqv names in operands
        for (string& operand : parsed.operands) {
            if (constants.count(operand)) {
                operand = constants.at(operand);
            }
        }

        // section switches
        if (mnemonic == ".text") {
            inText = true;
        }
        else if (mnemonic == ".data") {
            inText = false;
        }

        // record label at the current address of whichever section we're in
        if (!parsed.label.empty()) {
            if (symbols.count(parsed.label)) {
                throw runtime_error("Duplicate label: " + parsed.label + " on line " + to_string(parsed.lineNumber));
            }
            symbols[parsed.label] = inText ? textAddress : DATA_START + (uint32_t)dataBytes.size();
        }

        // label-only lines and section switches take no space
        if (mnemonic.empty() || mnemonic == ".text" || mnemonic == ".data") {
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
            vector<uint8_t> bytes = stringBytes(parsed);
            dataBytes.insert(dataBytes.end(), bytes.begin(), bytes.end()); // add to the end
        }
    }
}


// ============ Pass 2 ============


// checks if a label's address is not defined -> error
uint32_t Assembler::labelAddress(const string& label, int lineNumber) const {
    auto iterator = symbols.find(label);
    if (iterator == symbols.end()) {
        throw runtime_error("Undefined label: " + label + " on line " + to_string(lineNumber));
    }

    return iterator->second;
}


vector<uint32_t> Assembler::secondPass() {
    Encoder encoder;
    vector<uint32_t> machineCode; // 32-bit instructions
    uint32_t address = TEXT_START;

    for (const ParsedLine& original : textInstructions) {
        ParsedLine instruction = original; // copy so labels can -> offsets, targets, or la addresses
        vector<string>& operands = instruction.operands; // reference
        int lineNumber = instruction.lineNumber;

        // branches: offset counts instructions from the one after the branch
        bool twoRegisterBranch = (instruction.mnemonic == "beq" || instruction.mnemonic == "bne") && operands.size() == 3;
        bool zeroBranch = (instruction.mnemonic == "bgtz" || instruction.mnemonic == "blez" || instruction.mnemonic == "bltz" || instruction.mnemonic == "bgez") && operands.size() == 2;

        if (twoRegisterBranch || zeroBranch) {
            int32_t target = (int32_t)labelAddress(operands.back(), lineNumber); // label is always the last operand
            int32_t offset = (target - (int32_t)(address + 4)) / 4;  // n/4 for instruction count

            // branch stores offsets as signed 16 bits, outside isn't possible / will be a wrong jump
            if (offset < -32768 || offset > 32767) {
                throw runtime_error("Branch too far on line " + to_string(lineNumber));
            }

            operands.back() = to_string(offset);
        }

        // jumps: target is the address without its bottom 2 bits (always 00)
        else if ((instruction.mnemonic == "j" || instruction.mnemonic == "jal") && operands.size() == 1) {
            uint32_t target = labelAddress(operands[0], lineNumber);

            if ((target & 0xF0000000) != ((address + 4) & 0xF0000000)) { // top 4 bits come from pc
                throw runtime_error("Jump too far on line " + to_string(lineNumber));
            }

            operands[0] = to_string(target >> 2);
        }

        // la placeholders: %hi(label) -> upper 16 bits, %lo(label) -> lower 16 bits
        for (string& operand : operands) {
            if (operand.substr(0, 4) == "%hi(" && operand.back() == ')') {
                string label = operand.substr(4, operand.size() - 5); // between "%hi(" and ")"
                operand = to_string(labelAddress(label, lineNumber) >> 16);
            }
            else if (operand.substr(0, 4) == "%lo(" && operand.back() == ')') {
                string label = operand.substr(4, operand.size() - 5);
                operand = to_string(labelAddress(label, lineNumber) & 0xFFFF);
            }
        }

        machineCode.push_back(encoder.encode(instruction));
        address += 4;
    }

    return machineCode;
}