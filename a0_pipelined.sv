module lab1 #
(
	parameter WIDTHIN = 16,		// Input format is Q2.14 (2 integer bits + 14 fractional bits = 16 bits)
	parameter WIDTHOUT = 32,	// Intermediate/Output format is Q7.25 (7 integer bits + 25 fractional bits = 32 bits)
	// Taylor coefficients for the first five terms in Q2.14 format
	parameter [WIDTHIN-1:0] A0 = 16'b01_00000000000000, // a0 = 1
	parameter [WIDTHIN-1:0] A1 = 16'b01_00000000000000, // a1 = 1
	parameter [WIDTHIN-1:0] A2 = 16'b00_10000000000000, // a2 = 1/2
	parameter [WIDTHIN-1:0] A3 = 16'b00_00101010101010, // a3 = 1/6
	parameter [WIDTHIN-1:0] A4 = 16'b00_00001010101010, // a4 = 1/24
	parameter [WIDTHIN-1:0] A5 = 16'b00_00000010001000  // a5 = 1/120
)
(
	input clk,
	input reset,	
	
	input i_valid,
	input i_ready,
	output o_valid,
	output o_ready,
	
	input [WIDTHIN-1:0] i_x,
	output [WIDTHOUT-1:0] o_y
);
//Output value could overflow (32-bit output, and 16-bit inputs multiplied
//together repeatedly).  Don't worry about that -- assume that only the bottom
//32 bits are of interest, and keep them.

logic [79:0] x;				// Register to hold input x's in the pipeline
logic [5:0]valid_Q2;			// Output of register y is valid

// signal for enabling sequential circuit elements
logic enable;

// Signals for computing the y output
logic [WIDTHOUT-1:0] m0_out; // A5 * x 
logic [WIDTHOUT-1:0] a0_out; // A5 * x + A4
logic [WIDTHOUT-1:0] m1_out; // (A5 * x + A4) * x
logic [WIDTHOUT-1:0] a1_out; // (A5 * x + A4) * x + A3
logic [WIDTHOUT-1:0] m2_out; // ((A5 * x + A4) * x + A3) * x
logic [WIDTHOUT-1:0] a2_out; // ((A5 * x + A4) * x + A3) * x + A2
logic [WIDTHOUT-1:0] m3_out; // (((A5 * x + A4) * x + A3) * x + A2) * x
logic [WIDTHOUT-1:0] a3_out; // (((A5 * x + A4) * x + A3) * x + A2) * x + A1
logic [WIDTHOUT-1:0] m4_out; // ((((A5 * x + A4) * x + A3) * x + A2) * x + A1) * x
logic [WIDTHOUT-1:0] a4_out; // ((((A5 * x + A4) * x + A3) * x + A2) * x + A1) * x + A0
logic [WIDTHOUT-1:0] y_D;

// compute y value
mult16x16 Mult0 (.clk(clk), .i_dataa(A5), 		.i_datab(x[15:0]), 	.o_res(m0_out), .enable(i_ready));
addr32p16 Addr0 (.clk(clk), .i_dataa(m0_out), 	.i_datab(A4), 			.o_res(a0_out), .enable(i_ready));

mult32x16 Mult1 (.clk(clk), .i_dataa(a0_out), 	.i_datab(x[31:16]), 	.o_res(m1_out), .enable(i_ready));
addr32p16 Addr1 (.clk(clk), .i_dataa(m1_out), 	.i_datab(A3), 			.o_res(a1_out), .enable(i_ready));

mult32x16 Mult2 (.clk(clk), .i_dataa(a1_out), 	.i_datab(x[47:32]), 	.o_res(m2_out), .enable(i_ready));
addr32p16 Addr2 (.clk(clk), .i_dataa(m2_out), 	.i_datab(A2), 			.o_res(a2_out), .enable(i_ready));

mult32x16 Mult3 (.clk(clk), .i_dataa(a2_out), 	.i_datab(x[63:48]), 	.o_res(m3_out), .enable(i_ready));
addr32p16 Addr3 (.clk(clk), .i_dataa(m3_out), 	.i_datab(A1), 			.o_res(a3_out), .enable(i_ready));

mult32x16 Mult4 (.clk(clk), .i_dataa(a3_out), 	.i_datab(x[79:64]), 	.o_res(m4_out), .enable(i_ready));
addr32p16 Addr4 (.clk(clk), .i_dataa(m4_out), 	.i_datab(A0), 			.o_res(a4_out), .enable(i_ready));

assign y_D = a4_out;

// Combinational logic
always_comb begin
	// signal for enable
	enable = i_ready;
end

// Infer the registers
always_ff @(posedge clk or posedge reset) begin
	if (reset) begin
		valid_Q2[0] <= 1'b0;		
		x[15:0] <= 16'b0;
	end else if (enable) begin
		// propagate the valid value
		valid_Q2[0] 	<= i_valid;
		
		// read in new x value
		x[15:0] <= i_x;
	end
end

//Loop to generate the appropriate number of shift modules for the valid signal
generate
genvar i;
	for (i=0; i<5; i=i+1) begin : valid_shift
		valid_shift #(1) shift(.clk(clk), .i_data(valid_Q2[i]), .reset(reset),
		.enable(i_ready), .o_data(valid_Q2[i+1]));
	end
endgenerate

//Loop to generate the appropriate number of shift modules for input x
generate
	for (i=0; i<4; i=i+1) begin : input_shift
		valid_shift #(16) shift2(.clk(clk), .i_data(x[(i+1)*16-1:(i*16)]), .reset(reset), 
		.enable(i_ready), .o_data(x[(i+2)*16-1:((i+1)*16)]));	
	end
endgenerate
		
// assign outputs
assign o_y = a4_out;

// ready for inputs as long as receiver is ready for outputs */
assign o_ready = i_ready;   
		
// the output is valid as long as the corresponding input was valid and 
//	the receiver is ready. If the receiver isn't ready, the computed output
//	will still remain on the register outputs and the circuit will resume
//  normal operation when the receiver is ready again (i_ready is high)
assign o_valid = valid_Q2[5] & i_ready;	

endmodule

/*******************************************************************************************/

// Multiplier module for the first 16x16 multiplication
module mult16x16 (
	input clk,
	input enable,
	input  [15:0] i_dataa,
	input  [15:0] i_datab,
	output [31:0] o_res
);

logic [31:0] result;

always_ff @(posedge clk) begin
	if (enable)
		result = i_dataa * i_datab;
end

// The result of Q2.14 x Q2.14 is in the Q4.28 format. Therefore we need to change it
// to the Q7.25 format specified in the assignment by shifting right and padding with zeros.
assign o_res = {3'b000, result[31:3]};

endmodule

/*******************************************************************************************/

//Shift Register to pass valid signal
module valid_shift #
(
	parameter WIDTH = 16
	)
(
	input clk,
	input [WIDTH-1:0] i_data,
	input reset,
	input enable,
	output [WIDTH-1:0] o_data
);

logic [WIDTH-1:0] temp_output, temp_output2;

always_ff @(posedge clk) begin
	if (reset) begin
		temp_output <= {WIDTH{1'b0}};
	end
	else begin
		if (enable == 1'b1) begin
			temp_output <= i_data;
			temp_output2 <= temp_output;
		end			
	end	
end

assign o_data = temp_output2;

endmodule

/*******************************************************************************************/

// Multiplier module for all the remaining 32x16 multiplications
module mult32x16 (
	input clk,
	input enable,
	input  [31:0] i_dataa,
	input  [15:0] i_datab,
	output [31:0] o_res
);

logic [47:0] result;

always_ff @(posedge clk) begin
	if (enable)
		result = i_dataa * i_datab;
end

// The result of Q7.25 x Q2.14 is in the Q9.39 format. Therefore we need to change it
// to the Q7.25 format specified in the assignment by selecting the appropriate bits
// (i.e. dropping the most-significant 2 bits and least-significant 14 bits).
assign o_res = result[45:14];

endmodule

/*******************************************************************************************/

// Adder module for all the 32b+16b addition operations 
module addr32p16 (
	input clk,
	input enable,	
	input [31:0] i_dataa,
	input [15:0] i_datab,
	output [31:0] o_res
);

logic [31:0] temp_res;
// The 16-bit Q2.14 input needs to be aligned with the 32-bit Q7.25 input by zero padding
always_ff @(posedge clk) begin
	if (enable)
		temp_res = i_dataa + {5'b00000, i_datab, 11'b00000000000};
end

assign o_res = temp_res;

endmodule

/*******************************************************************************************/
