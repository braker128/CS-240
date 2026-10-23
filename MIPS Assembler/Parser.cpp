//
// Created by Carter on 10/17/2026.
//

#include "Parser.h"
#include <iostream>
#include <array>
#include <string>

using namespace std;

/*
Accept filepath as a string
Instantiate file instance
read file contents
read line by line (keep track with a variable for labels)

convert

output .mhc-ascii and .mhc-bin
*/

// ============ Non Instruction ============
// .data / .text / .? / etc
// labels
// comments -> remove / ignore

// =========== Pseudo-Instruction ===========
// move $t0, $t1
// -> addu $t0, $t1, $zero

// li $t0, value
// General 32-bit constant:
// -> lui $t0, upper16(value)
// -> ori $t0, $t0, lower16(value)

// la $t0, label
// For a fixed absolute label address:
// -> lui $t0, upper16(address_of_label)
// -> ori $t0, $t0, lower16(address_of_label)

// abs $t0, $t1
// -> sra  $at, $t1, 31
// -> xor  $t0, $t1, $at
// -> subu $t0, $t0, $at

// neg $t0, $t1
// -> sub $t0, $zero, $t1

// negu $t0, $t1
// -> subu $t0, $zero, $t1

// not $t0, $t1
// -> nor $t0, $t1, $zero

// blt $t1, $t2, label
// -> slt $at, $t1, $t2
// -> bne $at, $zero, label

// bgt $t1, $t2, label
// -> slt $at, $t2, $t1
// -> bne $at, $zero, label

// ble $t1, $t2, label
// -> slt $at, $t2, $t1
// -> beq $at, $zero, label

// bge $t1, $t2, label
// -> slt $at, $t1, $t2
// -> beq $at, $zero, label

// sge $t0, $t1, $t2
// -> slt  $t0, $t1, $t2
// -> xori $t0, $t0, 1

// sgt $t0, $t1, $t2
// -> slt $t0, $t2, $t1


// =============== Instruction ===============
// Segment String Arrays // delimited by "," ", " or " "
array<string, 6> RTypeSegments;
array<string, 4> ITypeSegments;
array<string, 2> JTypeSegments;

// -> all one array?



// add $t0, $t1, $t2
// mnemonic = "add"
// operands = ["$t0", "$t1, "$t2"]

// li $t9, 9 -> addiu $t9, $zero, 9
// mnemonic = "addiu"
// operands = ["$t9", "$zero", "9"]

// rem $t1, $t8, $t3
// mnemonic = "rem"
// operands = ["$t1", "$t8", "$t3"]

// beq $t1, $t2, fizzbuzz
// mnemonic = "beq"
// operands = ["$t1", "$t12", "fizzbuzz"]

// label

// mnemonic

// directive

// operands

// comment

// blank line



