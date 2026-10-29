//
// Created by comet on 10/22/2026.
//

#include "Disassembler.h"
#include <fstream>
#include <iterator>
#include <sstream>
#include <stdexcept>
#include <unordered_map>

using namespace std;


static const uint32_t TEXT_START = 0x00400000;
static const uint32_t DATA_START = 0x10010000;

static const string REGISTERS[32] = {
    "$zero", "$at", "$v0", "$v1", "$a0", "$a1", "$a2", "$a3",
    "$t0", "$t1", "$t2", "$t3", "$t4", "$t5", "$t6", "$t7",
    "$s0", "$s1", "$s2", "$s3", "$s4", "$s5", "$s6", "$s7",
    "$t8", "$t9", "$k0", "$k1", "$gp", "$sp", "$fp", "$ra"
};


static string hexString(uint32_t value) {
    stringstream stream;
    stream << "0x" << hex << value;
    return stream.str();
}


// ================= 1. Check whether machine code or ascii binary =================

// .mhc-ascii is only '0', '1', and line endings; anything else is raw machine code (.mhc-bin)
static bool isAsciiBinary(const vector<uint8_t>& bytes) {
    if (bytes.empty()) {
        return false;
    }
    for (uint8_t byte : bytes) {
        if (byte != '0' && byte != '1' && byte != '\n' && byte != '\r') {
            return false;
        }
    }
    return true;
}

void Disassembler::readWords(const string& path) {
    ifstream file(path, ios::binary);
    if (!file.is_open()) {
        throw runtime_error("Could not open " + path);
    }

    vector<uint8_t> bytes((istreambuf_iterator<char>(file)), istreambuf_iterator<char>());
    words.clear();

    if (isAsciiBinary(bytes)) {
        // one 32-bit word per line as 0s and 1s
        string line;
        for (size_t i = 0; i <= bytes.size(); i++) {
            if (i < bytes.size() && bytes[i] != '\n' && bytes[i] != '\r') {
                line += (char)bytes[i];
                continue;
            }
            if (line.empty()) {
                continue;
            }
            if (line.size() != 32) {
                throw runtime_error("Invalid line in " + path + ": " + line);
            }
            words.push_back((uint32_t)stoul(line, nullptr, 2));
            line.clear();
        }
    } else {
        // raw bytes, high byte first
        if (bytes.size() % 4 != 0) {
            throw runtime_error(path + " is not a whole number of 32-bit words");
        }
        for (size_t i = 0; i < bytes.size(); i += 4) {
            words.push_back(((uint32_t)bytes[i] << 24) | ((uint32_t)bytes[i + 1] << 16) | ((uint32_t)bytes[i + 2] << 8) | bytes[i + 3]);
        }
    }
}


// ================= 2. Determine directives and labels =================

// there's no marker between .text and .data, so .text ends at the first word that isn't an instruction
void Disassembler::findDirectives() {
    textWords = 0;
    while (textWords < words.size() && !decode(words[textWords], TEXT_START + 4 * (uint32_t)textWords).mnemonic.empty()) {
        textWords++;
    }
}

// if word is a branch or jump, sets target to the address it goes to
static bool jumpTarget(uint32_t word, uint32_t address, uint32_t& target) {
    uint32_t opcode = word >> 26;

    // j / jal: target is address >> 2, top 4 bits come from pc + 4
    if (opcode == 0x02 || opcode == 0x03) {
        target = ((address + 4) & 0xF0000000) | ((word & 0x3FFFFFF) << 2);
        return true;
    }

    // bltz/bgez (1), beq (4), bne (5), blez (6), bgtz (7): offset is instructions away from pc + 4
    if (opcode == 0x01 || (opcode >= 0x04 && opcode <= 0x07)) {
        int32_t offset = (int16_t)(word & 0xFFFF);
        target = address + 4 + (uint32_t)(offset * 4);
        return true;
    }

    return false;
}

// every branch/jump target inside .text gets a label, numbered in address order
void Disassembler::findLabels() {
    labels.clear();
    uint32_t textEnd = TEXT_START + 4 * (uint32_t)textWords; // a label can sit right after the last instruction (ex: Exit:)

    for (size_t i = 0; i < textWords; i++) {
        uint32_t target;
        if (jumpTarget(words[i], TEXT_START + 4 * (uint32_t)i, target) && target >= TEXT_START && target <= textEnd) {
            labels[target] = "";
        }
    }

    int count = 0;
    for (auto& label : labels) {
        label.second = "L" + to_string(count++);
    }

    // every string in .data gets a label (data0, data1, ...) so la can point to it
    dataLabels.clear();
    vector<uint8_t> bytes = dataBytes();

    size_t start = 0;
    while (start < bytes.size()) {
        dataLabels[DATA_START + (uint32_t)start] = "data" + to_string(dataLabels.size());

        while (start < bytes.size() && bytes[start] != 0) {
            start++;
        }
        start++; // skip the terminator
    }
}

// .data words split back into bytes, without the padding at the end
vector<uint8_t> Disassembler::dataBytes() const {
    vector<uint8_t> bytes;
    for (size_t i = textWords; i < words.size(); i++) {
        bytes.push_back((words[i] >> 24) & 0xFF);
        bytes.push_back((words[i] >> 16) & 0xFF);
        bytes.push_back((words[i] >> 8) & 0xFF);
        bytes.push_back(words[i] & 0xFF);
    }

    while (!bytes.empty() && bytes.back() == 0) { // padding to a whole word (and the last terminator)
        bytes.pop_back();
    }

    return bytes;
}


// ================= 3. Convert directives and labels to ascii =================

string Disassembler::labelFor(uint32_t address) const {
    auto iterator = labels.find(address);
    return iterator != labels.end() ? iterator->second : hexString(address);
}

// .data bytes, read back as null-terminated strings
string Disassembler::dataToAscii() const {
    vector<uint8_t> bytes = dataBytes();

    if (bytes.empty()) {
        return "";
    }

    stringstream output;
    output << ".data\n";

    size_t start = 0;
    while (start < bytes.size()) {
        string text;
        size_t end = start;

        for (; end < bytes.size() && bytes[end] != 0; end++) {
            char c = (char)bytes[end];
            if (c == '\n') text += "\\n";
            else if (c == '\t') text += "\\t";
            else if (c == '"') text += "\\\"";
            else if (c == '\\') text += "\\\\";
            else text += c;
        }

        output << dataLabels.at(DATA_START + (uint32_t)start) << ": .asciiz \"" << text << "\"\n";
        start = end + 1; // skip the terminator
    }

    return output.str() + "\n";
}


// ================= 4. Divide R, I, and J functions by opcode =================

// opcode 0 (and mul's 0x1C) -> R, 2/3 -> J, everything else -> I
char Disassembler::instructionType(uint32_t word) const {
    uint32_t opcode = word >> 26;

    if (opcode == 0x00 || opcode == 0x1C) {
        return 'R';
    }
    if (opcode == 0x02 || opcode == 0x03) {
        return 'J';
    }
    return 'I';
}


// ================= 5. Convert R, I, J functions into ascii pieces =================

Instruction Disassembler::decode(uint32_t word, uint32_t address) const {
    switch (instructionType(word)) {
        case 'R': return decodeR(word);
        case 'J': return decodeJ(word, address);
        default:  return decodeI(word, address);
    }
}

// R-type: opcode(6) rs(5) rt(5) rd(5) shamt(5) funct(6)
Instruction Disassembler::decodeR(uint32_t word) const {
    uint32_t opcode = word >> 26;
    const string& rs = REGISTERS[(word >> 21) & 0x1F];
    const string& rt = REGISTERS[(word >> 16) & 0x1F];
    const string& rd = REGISTERS[(word >> 11) & 0x1F];
    string shamt = to_string((word >> 6) & 0x1F);
    uint32_t funct = word & 0x3F;

    // mul rd, rs, rt (opcode 0x1C, laid out like R-type)
    if (opcode == 0x1C) {
        if (funct == 0x02) return {"mul", {rd, rs, rt}};
        return {};
    }

    // rd, rs, rt
    static const unordered_map<uint32_t, string> rFunct = {
        {0x20, "add"},
        {0x21, "addu"},
        {0x22, "sub"},
        {0x23, "subu"},
        {0x24, "and"},
        {0x25, "or"},
        {0x26, "xor"},
        {0x27, "nor"},
        {0x2A, "slt"},
        {0x2B, "sltu"}
    };

    if (rFunct.count(funct)) {
        return {rFunct.at(funct), {rd, rs, rt}};
    }

    // rd, rt, shamt
    static const unordered_map<uint32_t, string> shiftFunct = {
        {0x00, "sll"},
        {0x02, "srl"},
        {0x03, "sra"}
    };

    if (shiftFunct.count(funct)) {
        return {shiftFunct.at(funct), {rd, rt, shamt}};
    }

    // rd, rt, rs
    static const unordered_map<uint32_t, string> shiftVariableFunct = {
        {0x04, "sllv"},
        {0x06, "srlv"},
        {0x07, "srav"}
    };

    if (shiftVariableFunct.count(funct)) {
        return {shiftVariableFunct.at(funct), {rd, rt, rs}};
    }

    // rs, rt
    static const unordered_map<uint32_t, string> hiLoFunct = {
        {0x18, "mult"},
        {0x19, "multu"},
        {0x1A, "div"},
        {0x1B, "divu"}
    };

    if (hiLoFunct.count(funct)) {
        return {hiLoFunct.at(funct), {rs, rt}};
    }

    if (funct == 0x10) return {"mfhi", {rd}};
    if (funct == 0x12) return {"mflo", {rd}};
    if (funct == 0x11) return {"mthi", {rs}};
    if (funct == 0x13) return {"mtlo", {rs}};
    if (funct == 0x08) return {"jr", {rs}};
    if (funct == 0x0C) return {"syscall", {}};

    return {};
}

// I-type: opcode(6) rs(5) rt(5) immediate(16)
Instruction Disassembler::decodeI(uint32_t word, uint32_t address) const {
    uint32_t opcode = word >> 26;
    uint32_t rtNumber = (word >> 16) & 0x1F;
    const string& rs = REGISTERS[(word >> 21) & 0x1F];
    const string& rt = REGISTERS[rtNumber];
    string immediate = to_string((int16_t)(word & 0xFFFF)); // sign-extended (addi, lw)
    string unsignedImmediate = hexString(word & 0xFFFF);    // zero-extended (andi, ori, xori, lui)

    // rt, rs, signed immediate
    static const unordered_map<uint32_t, string> iOpcode = {
        {0x08, "addi"},
        {0x09, "addiu"},
        {0x0A, "slti"},
        {0x0B, "sltiu"}
    };

    if (iOpcode.count(opcode)) {
        return {iOpcode.at(opcode), {rt, rs, immediate}};
    }

    // rt, rs, unsigned immediate
    static const unordered_map<uint32_t, string> logicalOpcode = {
        {0x0C, "andi"},
        {0x0D, "ori"},
        {0x0E, "xori"}
    };

    if (logicalOpcode.count(opcode)) {
        return {logicalOpcode.at(opcode), {rt, rs, unsignedImmediate}};
    }

    if (opcode == 0x0F) {
        return {"lui", {rt, unsignedImmediate}};
    }

    // rt, offset(rs)
    static const unordered_map<uint32_t, string> memoryOpcode = {
        {0x20, "lb"},
        {0x21, "lh"},
        {0x23, "lw"},
        {0x24, "lbu"},
        {0x25, "lhu"},
        {0x28, "sb"},
        {0x29, "sh"},
        {0x2B, "sw"}
    };

    if (memoryOpcode.count(opcode)) {
        return {memoryOpcode.at(opcode), {rt, immediate + "(" + rs + ")"}};
    }

    // branches: offset -> label
    uint32_t target = 0;
    jumpTarget(word, address, target);
    string label = labelFor(target);

    if (opcode == 0x04) return {"beq", {rs, rt, label}};
    if (opcode == 0x05) return {"bne", {rs, rt, label}};
    if (opcode == 0x06) return {"blez", {rs, label}};
    if (opcode == 0x07) return {"bgtz", {rs, label}};

    // bltz / bgez share opcode 1, rt picks which one
    if (opcode == 0x01 && rtNumber == 0) return {"bltz", {rs, label}};
    if (opcode == 0x01 && rtNumber == 1) return {"bgez", {rs, label}};

    return {};
}

// J-type: opcode(6) target(26)
Instruction Disassembler::decodeJ(uint32_t word, uint32_t address) const {
    uint32_t target;
    jumpTarget(word, address, target);

    string mnemonic = ((word >> 26) == 0x02) ? "j" : "jal";
    return {mnemonic, {labelFor(target)}};
}

// la rY, label was assembled as: lui $at, upper / ori rY, $at, lower
// if words[index] and words[index + 1] are that pair and point at a data label, rebuild the la
bool Disassembler::decodeLoadAddress(size_t index, Instruction& instruction) const {
    if (index + 1 >= textWords) {
        return false;
    }

    uint32_t lui = words[index];
    uint32_t ori = words[index + 1];

    bool isLui = (lui >> 26) == 0x0F && ((lui >> 16) & 0x1F) == 1;   // lui $at, ...
    bool isOri = (ori >> 26) == 0x0D && ((ori >> 21) & 0x1F) == 1;   // ori rY, $at, ...
    if (!isLui || !isOri) {
        return false;
    }

    // a branch can't land between the two halves
    if (labels.count(TEXT_START + 4 * (uint32_t)(index + 1))) {
        return false;
    }

    uint32_t address = ((lui & 0xFFFF) << 16) | (ori & 0xFFFF);
    auto iterator = dataLabels.find(address);
    if (iterator == dataLabels.end()) {
        return false;
    }

    instruction = {"la", {REGISTERS[(ori >> 16) & 0x1F], iterator->second}};
    return true;
}


// ================= 6. Assemble ascii functions together =================

string Disassembler::textToAscii() const {
    stringstream output;
    output << ".text\n";

    for (size_t i = 0; i <= textWords; i++) {
        uint32_t address = TEXT_START + 4 * (uint32_t)i;

        if (labels.count(address)) {
            output << labels.at(address) << ":\n";
        }
        if (i == textWords) {
            break;
        }

        // "mnemonic op1, op2, op3"
        Instruction instruction;
        if (decodeLoadAddress(i, instruction)) {
            i++; // the ori was part of the la
        } else {
            instruction = decode(words[i], address);
        }

        output << "    " << instruction.mnemonic;
        for (size_t j = 0; j < instruction.operands.size(); j++) {
            output << (j == 0 ? " " : ", ") << instruction.operands[j];
        }
        output << "\n";
    }

    return output.str();
}


// ================= 7. Combine and write into filename.asm =================

string Disassembler::disassemble(const string& inputPath) {
    readWords(inputPath);
    findDirectives();
    findLabels();

    string program = dataToAscii() + textToAscii();

    // FizzBuzz.mhc-ascii -> FizzBuzz_DISASSEMBLED.asm
    string outputPath = inputPath.substr(0, inputPath.rfind('.')) + "_DISASSEMBLED.asm";
    ofstream file(outputPath);
    file << program;

    if (!file) {
        throw runtime_error("Could not write " + outputPath);
    }

    return program;
}
