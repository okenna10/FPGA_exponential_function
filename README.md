# Exponential Function FPGA Implementation

## Overview
This code implements the exponential function in hardware by calculating its Taylor expansion to the 5th degree. Two different implementations are utilized: a fully pipelined model, and a shared hardware model. The first is fully pipelined for maximum throughput and clock frequency. The shared hardware module is designed to minimize resource utilization with reasonable clock frequency tradeoff..

Inputs and coefficients are 16 bits wide in Q2.14 format and the output is 32 bits wide in Q7.25 format. 

## Fully Pipelined
There are 2 multiplier modules that perform fixed-point multiplication and an adder module. All these have registered outputs with single-cycle latency. A shift module propagates the valid signal for each input as well as the corresponding input for each stage of the operation. The design architecture is shown below.
![structure](https://github.com/okenna10/hwa0/assets/101345398/35266597-53f7-44f6-a957-7d70939ba367)

## Shared Hardware


