//
// Created by Carter on 10/17/2026.
//

#pragma once
#include <cstdint>
#include <string>
#include "ParsedLine.h"


class Encoder {
public:
    uint32_t encode(const ParsedLine& instruction);

private:
    int registerNumber(const string& reg);
};