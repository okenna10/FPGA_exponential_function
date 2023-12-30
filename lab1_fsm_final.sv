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

//logic [WIDTHIN-1:0] x;	// Register to hold input X
logic [15:0] x;	// Register to hold input X
logic [WIDTHOUT-1:0] y_Q;	// Register to hold output Y
logic valid_Q1;		// Output of register x is valid

// signal for enabling sequential circuit elements
logic enable;
logic sel;
logic valid_val;
logic new_x;
logic [15:0] fsm_data_i, data_shift_i;
logic fsm_valid_i;

enum {a0=0, a1, a2, a3, a4} sel_a;
logic [WIDTHOUT-1:0] adder_input, constant;  

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

//FSM
typedef enum {start_state, s1, s2, s3, s4, s5, s6} state;
state current_state = start_state;
state next_state;
logic valid, fifo_full, fifo_empty;


always_ff @(posedge clk) begin
	if (reset)
		current_state <= start_state;
	else
		current_state <= next_state;
end


// State Logic
always_comb begin
	sel = 1'b0;
	sel_a = a4;
	new_x = 1'b1;
	valid = 1'b0;
	next_state = current_state;
	
	case (current_state)
		start_state: begin
			if (i_valid) begin
				next_state = s1;
			end
			new_x = 1'b1;
		end
		
		s1: begin
			new_x = 1'b0;
			fsm_data_i <= x;
			next_state = s2;
		end
		
		s2: begin
			sel = 1'b1;		
			sel_a = a4;
			next_state = s3;
			new_x = 1'b0;
		end
		
		s3: begin
			sel_a = a3;
			next_state = s4;
			new_x = 1'b0;
		end
		
		s4: begin
			sel_a = a2;
			next_state = s5;
			new_x = 1'b0;
		end
		
		s5: begin
			sel_a = a1;
			next_state = s6;
			new_x = 1'b0;
		end
		
		s6: begin
			sel_a = a0;
			valid = 1'b1;
			if (i_ready)
				next_state = start_state;	
			new_x = 1'b0;
		end
		
	endcase
end

mult16x16 Mult0 (.clk(clk), .i_dataa(A5), 			.i_datab(fsm_data_i), 			.o_res(m0_out));

addr32p16 Addr0 (.clk(clk), .i_dataa(adder_input),  .i_datab(constant), 	.o_res(a0_out), .enable(i_ready));

mult32x16 Mult1 (.clk(clk), .i_dataa(a0_out), 		.i_datab(fsm_data_i), 			.o_res(m1_out));

// Data path 
always @(sel, sel_a) 
begin
	if (sel == 1'b1)
		adder_input = m0_out;
	else
		adder_input = m1_out;
	
	case (sel_a)
		a4: constant = A4;
		a3: constant = A3;
		a2: constant = A2;
		a1: constant = A1;
		a0: constant = A0;
	endcase
end

// Combinational logic
always_comb begin
	// signal for enable
	enable = i_ready;
end

// Infer the registers
always_ff @(posedge clk or posedge reset) begin
	if (reset) begin
		valid_Q1 <= 1'b0;
		x	 <= 16'b0;
	end 
	else if (enable) begin
		// propagate the valid value
		valid_Q1 	<= i_valid;
		
		// read in new x value
		x <= i_x;
		
	end
end


// assign outputs
assign o_valid = valid;
assign o_y = a0_out;

// ready for inputs as long as receiver is ready for outputs 
assign o_ready = i_ready & new_x;   

// the output is valid as long as the corresponding input was valid and 
//	the receiver is ready. If the receiver isn't ready, the computed output
//	will still remain on the register outputs and the circuit will resume
//  normal operation when the receiver is ready again (i_ready is high)

endmodule

/*******************************************************************************************/

// Multiplier module for the first 16x16 multiplication
module mult16x16 (
	input clk,
	input  [15:0] i_dataa,
	input  [15:0] i_datab,
	output [31:0] o_res
);

logic [31:0] result;

//always_ff @(posedge clk) begin
always_comb begin
	result = i_dataa * i_datab;
end

// The result of Q2.14 x Q2.14 is in the Q4.28 format. Therefore we need to change it
// to the Q7.25 format specified in the assignment by shifting right and padding with zeros.
assign o_res = {3'b000, result[31:3]};

endmodule

/*******************************************************************************************/

// Multiplier module for all the remaining 32x16 multiplications
module mult32x16 (
	input clk,
	input  [31:0] i_dataa,
	input  [15:0] i_datab,
	output [31:0] o_res
);

logic [47:0] result;

always_comb begin
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


//always_ff @(posedge clk) begin
always_comb begin
	if (enable)
		temp_res = i_dataa + {5'b00000, i_datab, 11'b00000000000};
	//else
		//temp_res = {32{1'b0}};
end

assign o_res = temp_res;

endmodule

/*******************************************************************************************/
