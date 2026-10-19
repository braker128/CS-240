cmake_minimum_required(VERSION 4.3)
project(CS_240)

set(CMAKE_CXX_STANDARD 14)

include_directories("MIPS Assembler")

add_executable(MIPS_ASSEMBLER
        "MIPS Assembler/Assembler.cpp"
        "MIPS Assembler/Assembler.h"
        "MIPS Assembler/main.cpp"
        "MIPS Assembler/Parser.cpp"
        "MIPS Assembler/Parser.h"
        "MIPS Assembler/Instruction.h"
        "MIPS Assembler/Encoder.cpp"
        "MIPS Assembler/Encoder.h"
)
