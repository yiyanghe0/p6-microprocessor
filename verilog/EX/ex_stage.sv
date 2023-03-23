//////////////////////////////////////////////////////////////////////////
//                                                                      //
//   Modulename :  ex_stage.v                                           //
//                                                                      //
//  Description :  instruction execute (EX) stage of the pipeline;      //
//                 given the instruction command code CMD, select the   //
//                 proper input A and B for the ALU, compute the result,//
//                 and compute the condition for branches, and pass all //
//                 the results down the pipeline. MWB                   //
//                                                                      //
//                                                                      //
//////////////////////////////////////////////////////////////////////////

`ifndef __EX_STAGE_SV__
`define __EX_STAGE_SV__
`define mul_num 2

`include "sys_defs.svh"


//
// BrCond module
//
// Given the instruction code, compute the proper condition for the
// instruction; for branches this condition will indicate whether the
// target is taken.
//
// This module is purely combinational
//



module ex_stage (
	input clock, // system clock
	input reset, // system reset
	input IS_PACKET is_packet_in,

	output EX_OUT_PACKET ex_packet_out
);

	// Pass-throughs
	assign ex_packet_out.NPC          = is_packet_in.NPC;
	assign ex_packet_out.rs2_value    = is_packet_in.rs2_value;
	assign ex_packet_out.rd_mem       = is_packet_in.rd_mem;
	assign ex_packet_out.wr_mem       = is_packet_in.wr_mem;
	assign ex_packet_out.dest_reg_idx = is_packet_in.dest_reg_idx;
	assign ex_packet_out.halt         = is_packet_in.halt;
	assign ex_packet_out.illegal      = is_packet_in.illegal;
	assign ex_packet_out.csr_op       = is_packet_in.csr_op;
	assign ex_packet_out.valid        = is_packet_in.valid;
	assign ex_packet_out.mem_size     = is_packet_in.inst.r.funct3;


	logic [`XLEN-1:0] 		opa_mux_out, opb_mux_out;

	//multiplier parameters //1
	logic [`mul_num-1:0]	mul_start1;
	logic 					mcand_sign1;
	logic 					mplier_sign1;
	logic [`XLEN-1:0] 		mcand1;
	logic [`XLEN-1:0]		mplier1;
	logic [(2*`XLEN)-1:0] 	product1;
	logic 					done1;

	//multiplier parameters //2
	logic [`mul_num-1:0]	mul_start2;
	logic 					mcand_sign2;
	logic 					mplier_sign2;
	logic [`XLEN-1:0] 		mcand2;
	logic [`XLEN-1:0]		mplier2;
	logic [(2*`XLEN)-1:0] 	product2;
	logic 					done2;
	logic ALU_FUNC 			ALU_FUNC_ALU;
	logic ALU_FUNC			ALUC_FUNC_MUL;

	//mux to determine if mutiplier or ALU
	




	// ALU opA mux
	always_comb begin
		opa_mux_out = `XLEN'hdeadfbac; // dead facebook
		case (is_packet_in.opa_select)
			OPA_IS_RS1:  opa_mux_out = is_packet_in.rs1_value;
			OPA_IS_NPC:  opa_mux_out = is_packet_in.NPC;
			OPA_IS_PC:   opa_mux_out = is_packet_in.PC;
			OPA_IS_ZERO: opa_mux_out = 0;
		endcase
	end

	 // ALU opB mux
	always_comb begin
		// Default value, Set only because the case isnt full. If you see this
		// value on the output of the mux you have an invalid opb_select
		opb_mux_out = `XLEN'hfacefeed;
		case (is_packet_in.opb_select)
			OPB_IS_RS2:   opb_mux_out = is_packet_in.rs2_value;
			OPB_IS_I_IMM: opb_mux_out = `RV32_signext_Iimm(is_packet_in.inst);
			OPB_IS_S_IMM: opb_mux_out = `RV32_signext_Simm(is_packet_in.inst);
			OPB_IS_B_IMM: opb_mux_out = `RV32_signext_Bimm(is_packet_in.inst);
			OPB_IS_U_IMM: opb_mux_out = `RV32_signext_Uimm(is_packet_in.inst);
			OPB_IS_J_IMM: opb_mux_out = `RV32_signext_Jimm(is_packet_in.inst);
		endcase
	end

	// instantiate the ALU
	alu alu_0 (
		// Inputs
		.opa(opa_mux_out),
		.opb(opb_mux_out),
		.func(ALU_FUNC_ALU),

		// Output
		.result(ex_packet_out.alu_result)
	);

	 // instantiate the branch condition tester
	brcond brcond (
		// Inputs
		.rs1(is_packet_in.rs1_value),
		.rs2(is_packet_in.rs2_value),
		.func(is_packet_in.inst.b.funct3), // inst bits to determine check

		// Output
		.cond(brcond_result)
	);

	//declare mult1
	mult mult1 (
		.clock(clock),
		.reset(reset),
		.start(mul_start1),
		.mcand_sign(mcand_sign1),
		.mplier_sign(mplier_sign1),
		.mcand(mcand1),
		.mplier(mplier1),
		.product(product1),
		.done(done1)
	);

	//declare mult2
	mult mult2 (
		.clock(clock),
		.reset(reset),
		.start(mul_start2),
		.mcand_sign(mcand_sign2),
		.mplier_sign(mplier_sign2),
		.mcand(mcand2),
		.mplier(mplier2),
		.product(product2),
		.done(done2)
	);


	 // ultimate "take branch" signal:
	 // unconditional, or conditional and the condition is true
	assign ex_packet_out.take_branch = is_packet_in.uncond_branch
	                                   | (is_packet_in.cond_branch & brcond_result);

endmodule // module ex_stage
`endif // __EX_STAGE_SV__
