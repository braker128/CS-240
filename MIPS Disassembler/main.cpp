//
// Created by comet on 10/22/2026.
//

#include <iostream>
#include <string>

#include "Disassembler.h"

using namespace std;

int main() {
    // either file works, the disassembler checks which format it is (output goes next to it as _DISASSEMBLED.asm)
    // string inputPath = R"(C:\Users\Carter\CLionProjects\CS-240\MIPS Disassembler\FizzBuzz.mhc-bin)";
    string inputPath = R"(C:\Users\Carter\CLionProjects\CS-240\MIPS Disassembler\FizzBuzz.mhc-ascii)";

    Disassembler disassembler;

    try {
        cout << disassembler.disassemble(inputPath);
    } catch (const exception& e) { // ex: "Could not open FizzBuzz.mhc-bin"
        cerr << "Error: " << e.what() << endl;
        return 1;
    }

    return 0;
}
