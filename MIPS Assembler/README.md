# CS 240 - MIPS Assembler & Disassembler

Two C++ programs, both built from the top-level `../CMakeLists.txt`:

| Target              | Folder                | Input                          | Output                                   |
|---------------------|-----------------------|--------------------------------|------------------------------------------|
| `MIPS_ASSEMBLER`    | `MIPS Assembler/`     | `.asm`                         | `.mhc-ascii` and `.mhc-bin`              |
| `MIPS_DISASSEMBLER` | `MIPS Disassembler/`  | `.mhc-ascii` or `.mhc-bin`     | `<name>_DISASSEMBLED.asm`                |

Output files are written next to the input file.

Open the `CS-240` folder in CLion and run the `MIPS_ASSEMBLER` or `MIPS_DISASSEMBLER` configuration.

## Changing the Input File

Neither program takes command-line arguments. The input path is hardcoded at the top of each `main()`, so edit it and rebuild.

> **Note:** the paths in the repo point to `C:\Users\Carter\CLionProjects\CS-240\...`. Change them to wherever the repo lives on your machine.

### Assembler — `MIPS Assembler/main.cpp`

Set `baseName` to the path of your program **without** the `.asm` extension:

```cpp
string baseName = R"(C:\path\to\CS-240\MIPS Assembler\FizzBuzz)";
```

This reads `FizzBuzz.asm` and writes `FizzBuzz.mhc-ascii` and `FizzBuzz.mhc-bin`. It also prints the symbol table and each instruction's address and machine code to the console.

### Disassembler — `MIPS Disassembler/main.cpp`

Set `inputPath` to the **full** path of a `.mhc-ascii` or `.mhc-bin` file. The disassembler detects the format on its own:

```cpp
string inputPath = R"(C:\path\to\CS-240\MIPS Disassembler\FizzBuzz.mhc-ascii)";
```

This writes `FizzBuzz_DISASSEMBLED.asm` and prints the result to the console.