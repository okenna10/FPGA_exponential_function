# Exponential Function FPGA Implementation

## Overview
This code implements the exponential function in hardware by calculating its Taylor expansion to the 5th degree. Two different implementations are utilized: a fully pipelined model, and a shared hardware model. The first is fully pipelined for maximum throughput and clock frequency. The shared hardware module is designed to minimize resource utilization with a reasonable clock frequency tradeoff.

There are 2 multiplier modules (one 16x16 and one 16x32) that perform fixed-point multiplication and an adder module. All these have registered outputs with single-cycle latency. Inputs and coefficients are 16 bits wide in Q2.14 format and the output is 32 bits wide in Q7.25 format. 

i_ready is an input signal indicating that the receiving system is ready for valid output. o_ready is an output signal that provides backpressure to the input data stream. A testbench provided by the instructor provides input stimulus and the corresponding output. Output data is valid if it is within the margin of error stipulated. 

## Fully Pipelined
In this case, the necessary hardware is instantiated for each time it's needed in the design. A shift module propagates the valid signal for each input as well as the corresponding input needed for later stages of the operation. The design architecture is shown below.
![structure](https://github.com/okenna10/hwa0/assets/101345398/35266597-53f7-44f6-a957-7d70939ba367)

## Shared Hardware
In this case, each subcomponent is instantiated only once. An FSM controls the flow of data through the system. 
![image](https://github.com/okenna10/hwa0/assets/101345398/2be054b1-7de0-4854-911e-5dfac4888ba8)

## Note
This code was written as part of an assignment at Cornell Tech and base code was provided by Professor Dr Mohamed Abdelfattah
