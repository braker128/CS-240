# Test Evidence: Invalid Input Produces Useful Errors

Each file in `../Test Evidence/Assembler` and `../Test Evidence/Disassembler` is an invalid input. The output below is copied exactly from running the programs on those files (2026-10-29, CLion's bundled MinGW `c++`, C++14).

**How it was run:** the programs normally read a hardcoded path in `main.cpp`. For testing, they were compiled with that one line changed to read the path from the command line (`argv[1]`); nothing else changed. To reproduce one case in CLion, set `baseName` / `inputPath` to the test file and run.

## Assembler

| # | Test file | Invalid input | Output | Exit |
|---|-----------|---------------|--------|------|
| 1 | `does_not_exist` | File that doesn't exist | `Error opening file.` | 1 |
| 2 | `unknown_instruction.asm` | `foo $t0, $t1, $t2` | `Error: Unsupported instruction: foo on line 3` | 1 |
| 3 | `invalid_register.asm` | `add $t0, $t1, $t10` | `Error: Invalid register: $t10` | 1 |
| 4 | `wrong_operand_count.asm` | `add $t0, $t1` | `Error: Invalid add operands on line 2` | 1 |
| 5 | `undefined_label.asm` | `beq $t0, $zero, done` (no `done:`) | `Error: Undefined label: done on line 3` | 1 |
| 6 | `duplicate_label.asm` | `loop:` defined twice | `Error: Duplicate label: loop on line 4` | 1 |
| 7 | `invalid_li_value.asm` | `li $t0, abc` | `Error: Invalid li value abc on line 2` | 1 |
| 8 | `unsupported_directive.asm` | `value: .float 1.5` | `Error: Unsupported directive: .float on line 2` | 1 |
| 9 | `invalid_shift_amount.asm` | `sll $t0, $t1, 40` | `Error: Invalid shift amount on line 2` | 1 |
| 10 | `invalid_memory_operand.asm` | `lw $t0, 4$sp` | `Error: Undefined label: 4$sp on line 2` | 1 |
| 11 | `unterminated_quote.asm` | `msg: .asciiz "Hello` | `terminate called after throwing an instance of 'std::runtime_error'`<br>`  what():  Unterminated quote on line 2` | 3 |

## Disassembler

| # | Test file | Invalid input | Output | Exit |
|---|-----------|---------------|--------|------|
| 1 | `does_not_exist.mhc-bin` | File that doesn't exist | `Error: Could not open Disassembler/does_not_exist.mhc-bin` | 1 |
| 2 | `short_line.mhc-ascii` | 31-bit line | `Error: Invalid line in Disassembler/short_line.mhc-ascii: 0000000000000000000000000000001` | 1 |
| 3 | `partial_word.mhc-bin` | 6 bytes (not a multiple of 4) | `Error: Disassembler/partial_word.mhc-bin is not a whole number of 32-bit words` | 1 |
| 4 | `bad_character.mhc-ascii` | Line containing an `x` | `Error: Disassembler/bad_character.mhc-ascii is not a whole number of 32-bit words` | 1 |
| 5 | `empty.mhc-bin` | Empty file | `.text` (no error) | 0 |
| 6 | `unknown_opcode.mhc-bin` | Words `0xFFFFFFFF 0xFC000000` | Treated as `.data` bytes (no error) | 0 |
