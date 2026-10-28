//
// Created by Carter on 10/17/2026.
//

#include "Encoder.h"
#include <unordered_map>
#include <stdexcept>


using namespace std;


int Encoder::registerNumber(const string& reg) {
    static const unordered_map<string, int> registers = {
        {"$zero", 0},
        {"$at", 1},
        {"$v0", 2},
        {"$v1", 3},
        {"$a0", 4},
        {"$a1", 5},
        {"$a2", 6},
        {"$a3", 7},
        {"$t0", 8},
        {"$t1", 9},
        {"$t2", 10},
        {"$t3", 11},
        {"$t4", 12},
        {"$t5", 13},
        {"$t6", 14},
        {"$t7", 15},
        {"$s0", 16},
        {"$s1", 17},
        {"$s2", 18},
        {"$s3", 19},
        {"$s4", 20},
        {"$s5", 21},
        {"$s6", 22},
        {"$s7", 23},
        {"$t8", 24},
        {"$t9", 25},
        {"$k0", 26},
        {"$k1", 27},
        {"$gp", 28},
        {"$sp", 29},
        {"$fp", 30},
        {"$s8", 30},
        {"$ra", 31}
    };

    auto iterator = registers.find(reg);
    if (iterator == registers.end()) {
        throw runtime_error("Invalid register: " + reg);
    }

    return iterator->second;
}


// parses decimal, hex (0x), or negative values and keeps the low 16 bits
static uint32_t immediate16(const string& value) {
    return (uint32_t)stoi(value, nullptr, 0) & 0xFFFF;
}


// R-type: opcode(6) rs(5) rt(5) rd(5) shamt(5) funct(6)
static uint32_t rType(int rs, int rt, int rd, int shamt, int funct) {
    return ((uint32_t)rs << 21) | ((uint32_t)rt << 16) | ((uint32_t)rd << 11) | ((uint32_t)shamt << 6) | (uint32_t)funct;
}

// I-type: opcode(6) rs(5) rt(5) immediate(16)
static uint32_t iType(int opcode, int rs, int rt, uint32_t immediate) {
    return ((uint32_t)opcode << 26) | ((uint32_t)rs << 21) | ((uint32_t)rt << 16) | (immediate & 0xFFFF);
}

// J-type: opcode(6) target(26)
static uint32_t jType(int opcode, uint32_t target) {
    return ((uint32_t)opcode << 26) | (target & 0x3FFFFFF);
}



uint32_t Encoder::encode(const ParsedLine& instruction) {
    const string& mnemonic = instruction.mnemonic;
    const vector<string>& operands = instruction.operands;

    auto expect = [&](size_t count) {
        if (operands.size() != count) {
            throw runtime_error("Invalid " + mnemonic + " operands on line " + to_string(instruction.lineNumber)); // ex: "Invalid div operands on line 63"
        }
    };


    // ============ R-type (opcode 000000 == 0) ============

    // rd, rs, rt
    static const unordered_map<string, int> rFunct = {
        {"add", 0x20},
        {"addu", 0x21},
        {"sub", 0x22},
        {"subu", 0x23},
        {"and", 0x24},
        {"or", 0x25},
        {"xor", 0x26},
        {"nor", 0x27},
        {"slt", 0x2A},
        {"sltu", 0x2B}
    };

    if (rFunct.count(mnemonic)) {
        expect(3);
        return rType(registerNumber(operands[1]), registerNumber(operands[2]), registerNumber(operands[0]), 0, rFunct.at(mnemonic));
    }

    // rd, rt, shamt
    static const unordered_map<string, int> shiftFunct = {
        {"sll", 0x00},
        {"srl", 0x02},
        {"sra", 0x03}
    };

    if (shiftFunct.count(mnemonic)) {
        expect(3);
        int shamt = stoi(operands[2], nullptr, 0);
        if (shamt < 0 || shamt > 31) {
            throw runtime_error("Invalid shift amount on line " + to_string(instruction.lineNumber));
        }
        return rType(0, registerNumber(operands[1]), registerNumber(operands[0]), shamt, shiftFunct.at(mnemonic));
    }

    // rd, rt, rs (shift amount comes from a register)
    static const unordered_map<string, int> shiftVariableFunct = {
        {"sllv", 0x04},
        {"srlv", 0x06},
        {"srav", 0x07}
    };

    if (shiftVariableFunct.count(mnemonic)) {
        expect(3);
        return rType(registerNumber(operands[2]), registerNumber(operands[1]), registerNumber(operands[0]), 0, shiftVariableFunct.at(mnemonic));
    }

    // rs, rt (result goes to hi/lo)
    static const unordered_map<string, int> hiLoFunct = {
        {"mult", 0x18},
        {"multu", 0x19},
        {"div", 0x1A},
        {"divu", 0x1B}
    };

    if (hiLoFunct.count(mnemonic)) {
        expect(2);
        return rType(registerNumber(operands[0]), registerNumber(operands[1]), 0, 0, hiLoFunct.at(mnemonic));
    }

    // mfhi / mflo rd
    if (mnemonic == "mfhi" || mnemonic == "mflo") {
        expect(1);
        int funct = (mnemonic == "mfhi") ? 0x10 : 0x12;
        return rType(0, 0, registerNumber(operands[0]), 0, funct);
    }

    // mthi / mtlo rs
    if (mnemonic == "mthi" || mnemonic == "mtlo") {
        expect(1);
        int funct = (mnemonic == "mthi") ? 0x11 : 0x13;
        return rType(registerNumber(operands[0]), 0, 0, 0, funct);
    }

    // jr rs
    if (mnemonic == "jr") {
        expect(1);
        return rType(registerNumber(operands[0]), 0, 0, 0, 0x08);
    }

    if (mnemonic == "syscall") {
        expect(0);
        return rType(0, 0, 0, 0, 0x0C);
    }

    // mul rd, rs, rt (not opcode 0, but laid out like R-type)
    if (mnemonic == "mul") {
        expect(3);
        return (0x1Cu << 26) | rType(registerNumber(operands[1]), registerNumber(operands[2]), registerNumber(operands[0]), 0, 0x02);
    }


    // ================= I-type =================

    // rt, rs, immediate
    static const unordered_map<string, int> iOpcode = {
        {"addi", 0x08},
        {"addiu", 0x09},
        {"slti", 0x0A},
        {"sltiu", 0x0B},
        {"andi", 0x0C},
        {"ori", 0x0D},
        {"xori", 0x0E}
    };

    if (iOpcode.count(mnemonic)) {
        expect(3);
        return iType(iOpcode.at(mnemonic), registerNumber(operands[1]), registerNumber(operands[0]), immediate16(operands[2]));
    }

    // lui rt, immediate
    if (mnemonic == "lui") {
        expect(2);
        return iType(0x0F, 0, registerNumber(operands[0]), immediate16(operands[1]));
    }

    // rt, offset(rs)
    static const unordered_map<string, int> memoryOpcode = {
        {"lb", 0x20},
        {"lh", 0x21},
        {"lw", 0x23},
        {"lbu", 0x24},
        {"lhu", 0x25},
        {"sb", 0x28},
        {"sh", 0x29},
        {"sw", 0x2B}
    };

    if (memoryOpcode.count(mnemonic)) {
        expect(2);

        // split "offset($base)" like "4($sp)", "-8($fp)", or "($t0)"
        const string& address = operands[1];
        size_t open = address.find('(');

        if (open == string::npos || address.back() != ')') {
            throw runtime_error("Invalid memory operand " + address + " on line " + to_string(instruction.lineNumber));
        }

        string offset = address.substr(0, open); // mem offset (before the '(')
        string base = address.substr(open + 1, address.size() - open - 2); // between ( and )

        if (offset.empty()) { // "($t0)" means an offset of 0
            offset = "0";
        }

        return iType(memoryOpcode.at(mnemonic), registerNumber(base), registerNumber(operands[0]), immediate16(offset));
    }

    // beq/bne rs, rt, offset // label -> instructions away from pc + 4
    if (mnemonic == "beq" || mnemonic == "bne") {
        expect(3);
        int opcode = (mnemonic == "beq") ? 0x04 : 0x05;
        return iType(opcode, registerNumber(operands[0]), registerNumber(operands[1]), immediate16(operands[2]));
    }

    // bgtz / blez / bltz / bgez rs, offset (compare rs against zero)
    if (mnemonic == "bgtz" || mnemonic == "blez") {
        expect(2);
        int opcode = (mnemonic == "bgtz") ? 0x07 : 0x06;
        return iType(opcode, registerNumber(operands[0]), 0, immediate16(operands[1]));
    }

    if (mnemonic == "bltz" || mnemonic == "bgez") {
        expect(2);
        int rt = (mnemonic == "bltz") ? 0 : 1; // both are opcode 1, rt picks which one
        return iType(0x01, registerNumber(operands[0]), rt, immediate16(operands[1]));
    }



    // ================= J-type =================

    // j / jal target // label -> address >> 2
    if (mnemonic == "j" || mnemonic == "jal") {
        expect(1);
        int opcode = (mnemonic == "j") ? 0x02 : 0x03;
        return jType(opcode, stoul(operands[0], nullptr, 0));
    }

    throw runtime_error("Unsupported instruction: " + mnemonic + " on line " + to_string(instruction.lineNumber));

}