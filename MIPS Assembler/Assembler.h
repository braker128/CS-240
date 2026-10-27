//
// Created by Carter on 10/17/2026.
//

#pragma once
#include <cstdint>
#include <unordered_map>

#include "ParsedLine.h"

using namespace std;

class Assembler {
public:
    vector<ParsedLine> expandPseudo(const ParsedLine& parsed);
    void firstPass(const vector<ParsedLine>& parsedLines);
    vector<uint32_t> secondPass();

    const unordered_map<string, uint32_t>& getSymbols() const { return symbols; }
    const vector<ParsedLine>& getTextInstructions() const { return textInstructions; }

private:
    unordered_map<string, uint32_t> symbols;  // label -> address
    vector<ParsedLine> textInstructions;      // expanded .text instructions, in address order

    uint32_t labelAddress(const string& label, int lineNumber) const;
};