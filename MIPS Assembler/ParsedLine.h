//
// Created by Carter on 10/17/2026.
//

#pragma once


#include <string>
#include <vector>

using namespace std;

struct ParsedLine {
    string label;
    string mnemonic;
    vector<string> operands;
    int lineNumber;
};