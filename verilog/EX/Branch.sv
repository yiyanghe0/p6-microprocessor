/////////////////////////////////////////////////////////////////////////
//                                                                     //
//   Modulename :  mult.sv                                             //
//                                                                     //
//  Description :  A pipelined multiplier module with parameterized    //
//                 number of stages, as seen in project 2.             //
//                 Shouldn't need any changes for project 4.           //
//                                                                     //
/////////////////////////////////////////////////////////////////////////

`ifndef __Branch_SV__
`define __Branch_SV__

`include "sys_defs.svh"


module brcond (
	input [`XLEN-1:0] rs1,  // Value to check against condition
	input [`XLEN-1:0] rs2,
	input [2:0]       func, // Specifies which condition to check

	output logic cond, // 0/1 condition result (False/True)
	output logic busy
);

	logic signed [`XLEN-1:0] signed_rs1, signed_rs2;
	assign signed_rs1 = rs1;
	assign signed_rs2 = rs2;
	always_comb begin
		cond = 0;
		case (func)
			3'b000: cond = signed_rs1 == signed_rs2; // BEQ
			3'b001: cond = signed_rs1 != signed_rs2; // BNE
			3'b100: cond = signed_rs1 < signed_rs2;  // BLT
			3'b101: cond = signed_rs1 >= signed_rs2; // BGE
			3'b110: cond = rs1 < rs2;                // BLTU
			3'b111: cond = rs1 >= rs2;               // BGEU
		endcase
	end

endmodule // brcond
`endif
