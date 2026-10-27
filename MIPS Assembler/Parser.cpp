//
// Created by Carter on 10/17/2026.
//

#include "Parser.h"
#include <iostream>
#include <stdexcept>
#include <vector>

#include "ParsedLine.h"

using namespace std;

ParsedLine Parser::parseLine(const string& line, int lineNumber) {
    // variables
    string mnemonic;
    vector<string> operands; // dynamic string array of operands
    ParsedLine parsed;

    vector<string> words;
    string word;
    char quote = 0;
    bool escaped = false;

    for (char c : line) {
        if (quote != 0) {
            word += c;
            if (escaped) { // like \"
                escaped = false;
            } else if (c == '\\') {
                escaped = true;
            } else if (c == quote) { // closing quote
                quote = 0;
            }
        }
        else if (c == '#') { // remove comments
            break;
        }
        else if (c == ' ' || c == '\t' || c == '\r' || c == ',') { // end of a word
            if (!word.empty()) {
                words.push_back(word);
                word.clear();
            }
        }
        else {
            if (c == '"' || c == '\'') { // opening quote
                quote = c;
            }
            word += c;
        }
    }

    if (!word.empty()) {
        words.push_back(word);
    }

    if (quote != 0) {
        throw runtime_error("Unterminated quote on line " + to_string(lineNumber));
    }

    // skips empty lines <3
    if (words.empty()) {
        return ParsedLine();
    }

    size_t index = 0; // next word

    mnemonic = words[index];
    index++;

    // LABELS
    if (mnemonic.back() == ':') {
        parsed.label = mnemonic.substr(0, mnemonic.find(':'));
        mnemonic.clear();

        if (index < words.size()) { // labels don't have mnemonics
            mnemonic = words[index];
            index++;
        }
    }

    while (index < words.size()) { // the rest are operands then
        operands.push_back(words[index]); // adds next words as operands
        index++;
    }

    parsed.mnemonic = mnemonic;
    parsed.operands = operands;
    parsed.lineNumber = lineNumber;

    // cout << line; // Print full lines

    return parsed;
}
