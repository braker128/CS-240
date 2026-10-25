//
// Created by Carter on 10/17/2026.
//

#include "Parser.h"
#include <iostream>
#include <sstream>
#include <vector>

#include "ParsedLine.h"

using namespace std;

ParsedLine Parser::parseLine(const string& line, int lineNumber) {

    // remove comments
    string cleanLine = line.substr(0, line.find('#'));

    // remove commas (',' -> ' ')
    for (char& c : cleanLine) {
        if (c == ',') {
            c = ' ';
        }
    }
    istringstream stream(cleanLine);

    // variables
    string mnemonic;
    vector<string> operands; // dynamic string array of operands
    ParsedLine parsed;

    stream >> mnemonic; // first word of stream

    // skips empty lines
    if (mnemonic.empty()) {
        return ParsedLine{};
    }

    // checks for labels
    if (!mnemonic.empty() && mnemonic.back() == ':') {
        parsed.label = mnemonic.substr(0, mnemonic.find(':'));
        mnemonic.clear();
        stream >> mnemonic;
    }

    string operand; // variable to store operands to before putting them into the string array

    while (stream >> operand) { // whitespace separated elements
        operands.push_back(operand); // adds next word to the vector
    }

    parsed.mnemonic = mnemonic;
    parsed.operands = operands;
    parsed.lineNumber = lineNumber;

    // cout << cleanLine << endl; // Print full lines

    return parsed;
}
