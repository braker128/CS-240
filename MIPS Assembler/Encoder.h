//
// Created by Carter on 10/17/2026.
//

#pragma once

class Encoder {
public:

    Encoder();


    int getOpcode();
    int getSourceRegister();
    int getTargetRegister();
    int getDestinationRegister();
    int getShiftAmount();
    int getFunction();
    int getImmediate();
    int getAddress();


private:
};