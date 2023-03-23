/////////////////////////////////////////////////////////////////////////
//                                                                     //
//   Modulename :  mult.sv                                             //
//                                                                     //
//  Description :  A pipelined multiplier module with parameterized    //
//                 number of stages, as seen in project 2.             //
//                 Shouldn't need any changes for project 4.           //
//                                                                     //
/////////////////////////////////////////////////////////////////////////

`ifndef __ALU_SV__
`define __ALU_SV__

`include "sys_defs.svh"


module alu (
	input [`XLEN-1:0] opa,
	input [`XLEN-1:0] opb,
	ALU_FUNC          func,

	output logic [`XLEN-1:0] result,
	output logic		busy
);

	wire signed [`XLEN-1:0]   signed_opa, signed_opb;

	assign signed_opa = opa;
	assign signed_opb = opb;
//	assign signed_mul = signed_opa * signed_opb;
//	assign unsigned_mul = opa * opb;
//	assign mixed_mul = signed_opa * opb;

	always_comb begin
		case (func)
			ALU_ADD:      result = opa + opb;
			ALU_SUB:      result = opa - opb;
			ALU_AND:      result = opa & opb;
			ALU_SLT:      result = signed_opa < signed_opb;
			ALU_SLTU:     result = opa < opb;
			ALU_OR:       result = opa | opb;
			ALU_XOR:      result = opa ^ opb;
			ALU_SRL:      result = opa >> opb[4:0];
			ALU_SLL:      result = opa << opb[4:0];
			ALU_SRA:      result = signed_opa >>> opb[4:0]; // arithmetic from logical shift
		/*	ALU_MUL:      result = signed_mul[`XLEN-1:0];
			ALU_MULH:     result = signed_mul[2*`XLEN-1:`XLEN];
			ALU_MULHSU:   result = mixed_mul[2*`XLEN-1:`XLEN];
			ALU_MULHU:    result = unsigned_mul[2*`XLEN-1:`XLEN];
		*/
			default:      result = `XLEN'hfacebeec;  // here to prevent latches
		endcase
	end

endmodule // alu


`endif //__ALU_SV__
