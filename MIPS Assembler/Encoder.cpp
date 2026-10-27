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
    static const unordered_map<string, int> rFunct = {
        {"addu", 0x21}
    };

    // rd, rs, rt
    if (rFunct.count(mnemonic)) {
        expect(3);
        return rType(registerNumber(operands[1]), registerNumber(operands[2]), registerNumber(operands[0]), 0, rFunct.at(mnemonic));
    }

    // sll rd, rt, shamt
    if (mnemonic == "sll") {
        expect(3);
        int shamt = stoi(operands[2], nullptr, 0);
        if (shamt < 0 || shamt > 31) {
            throw runtime_error("Invalid shift amount on line " + to_string(instruction.lineNumber));
        }
        return rType(0, registerNumber(operands[1]), registerNumber(operands[0]), shamt, 0x00);
    }

    // div rs, rt (result in hi/lo)
    if (mnemonic == "div") {
        expect(2);
        return rType(registerNumber(operands[0]), registerNumber(operands[1]), 0, 0, 0x1A);
    }

    // mfhi rd
    if (mnemonic == "mfhi") {
        expect(1);
        return rType(0, 0, registerNumber(operands[0]), 0, 0x10);
    }

    // syscall
    if (mnemonic == "syscall") {
        expect(0);
        return rType(0, 0, 0, 0, 0x0C);
    }




    // ================= I-type =================
    static const unordered_map<string, int> iOpcode = {
        {"addi", 0x08},
        {"addiu", 0x09},
        {"ori", 0x0D}
    };

    // rt, rs, immediate
    if (iOpcode.count(mnemonic)) {
        expect(3);
        return iType(iOpcode.at(mnemonic), registerNumber(operands[1]), registerNumber(operands[0]), immediate16(operands[2]));
    }

    // lui rt, immediate
    if (mnemonic == "lui") {
        expect(2);
        return iType(0x0F, 0, registerNumber(operands[0]), immediate16(operands[1]));
    }

    // beq/bne rs, rt, offset // label -> instructions from pc + 4
    if (mnemonic == "beq" || mnemonic == "bne") {
        expect(3);
        int opcode = (mnemonic == "beq") ? 0x04 : 0x05;
        return iType(opcode, registerNumber(operands[0]), registerNumber(operands[1]), immediate16(operands[2]));
    }




    // ================= J-type =================
    // j target // label -> address >> 2
    if (mnemonic == "j") {
        expect(1);
        return jType(0x02, stoul(operands[0], nullptr, 0));
    }

    throw runtime_error("Unsupported instruction: " + mnemonic + " on line " + to_string(instruction.lineNumber));

}