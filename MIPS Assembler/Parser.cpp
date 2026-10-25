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
// move $rd, $rs
// -> addu $rd, $rs, $zero

// li $rt, value
// General 32-bit constant:
// -> lui $rt, upper16(value)
// -> ori $rt, $rt, lower16(value)

// la $rt, label
// For a fixed absolute label address:
// -> lui $rt, upper16(address_of_label)
// -> ori $rt, $rt, lower16(address_of_label)

// abs $rd, $rs
// -> sra  $at, $rs, 31
// -> xor  $rd, $rs, $at
// -> subu $rd, $rd, $at

// neg $rd, $rs
// -> sub $rd, $zero, $rs

// negu $rd, $rs
// -> subu $rd, $zero, $rs

// not $rd, $rs
// -> nor $rd, $rs, $zero

// blt $rs, $rt, label
// -> slt $at, $rs, $rt
// -> bne $at, $zero, label

// bgt $rs, $rt, label
// -> slt $at, $rt, $rs
// -> bne $at, $zero, label

// ble $rs, $rt, label
// -> slt $at, $rt, $rs
// -> beq $at, $zero, label

// bge $rs, $rt, label
// -> slt $at, $rs, $rt
// -> beq $at, $zero, label

// sge $rd, $rs, $rt
// -> slt  $rd, $rs, $rt
// -> xori $rd, $rd, 1

// sgt $rd, $rs, $rt
// -> slt $rd, $rt, $rs


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



