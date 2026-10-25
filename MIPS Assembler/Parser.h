//
// Created by Carter on 10/17/2026.
//

#pragma once
#include <string>

#include "ParsedLine.h"

using namespace std;
class Parser {
    public:
    ParsedLine parseLine(const string& line, int lineNumber);
};

