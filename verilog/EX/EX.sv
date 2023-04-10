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
`define MUL_NUM 2

`include "sys_defs.svh"
`include "ISA.svh"


//
// BrCond module
//
// Given the instruction code, compute the proper condition for the
// instruction; for branches this condition will indicate whether the
// target is taken.
//
// This module is purely combinational
//

module EX (
	input 			clock, // system clock
	input 			reset, // system reset
	input IS_PACKET is_packet_in,
	input [63:0]	Dcache2proc_data,
	input 			Dcache_finish,

	output EX_PACKET ex_packet_out,
	output logic 	MUL_valid, // if MUL_valid = 0, mult encountered structural hazard and has to stall
	output logic 	LOAD_valid, //if LOAD_valid = 0, LOAD encountered structural hazard and has to stall
	output logic 	no_output,  // no_output = 1 -> nothing output; no_output = 0 -> valid output
	output EX2BTB_PACKET ex2btb_packet_out,
	output logic correct_predict, // BTB made correct prediction
	//LOAD output
	output logic [1:0]          proc2Dcache_command,
	output logic [`XLEN-1:0]    proc2Dcache_addr,
	output logic [63:0]			proc2Dcache_data,
	output logic [2:0]          proc2Dcache_mem_size
);
	
	logic [`XLEN-1:0] 					opa_mux_out, opb_mux_out;

	//ALU parameter
	logic 								ALU_start;
	logic [`XLEN-1:0]					ALU_result;
	logic 								ALU_done;
	IS_PACKET							ALU_is_packet;

	//Branch parameter
	logic								BRANCH_start;
	logic [`XLEN-1:0]					BRANCH_addr;
	logic 								brcond_result;
	logic 								BRANCH_done;
	IS_PACKET							BRANCH_is_packet;

	//MULTIPLIER parameter
	logic [`MUL_NUM-1:0]				MUL_start;
	logic [`MUL_NUM-1:0][`XLEN-1:0]		MUL_product;
	logic [`MUL_NUM-1:0]				MUL_done;
	logic [`MUL_NUM-1:0]				MUL_busy;
	IS_PACKET [`MUL_NUM-1:0]			MUL_is_packet;

	//Store parameter
	logic								STORE_start;
	logic [`XLEN-1:0]					STORE_addr;
	logic 								STORE_done;
	IS_PACKET							STORE_is_packet;
	//Load parameter
	logic								LOAD_start;
	logic 								LOAD_done;
	IS_PACKET							LOAD_is_packet;
	logic [63:0]						LOAD_result;
	
	logic								LOAD_busy;

	logic [2:0]                         load_mem_size;

	//mux to determine if mutiplier or ALU or LD or ST
	assign proc2Dcache_data = 0;
	assign proc2Dcache_mem_size = load_mem_size;     // !!!temp value
	assign ALU_start 	= (is_packet_in.channel == ALU) ? 1 : 0;
	assign BRANCH_start = (is_packet_in.channel == BR)  ? 1 : 0;
	assign STORE_start  = (is_packet_in.channel == ST)  ? 1 : 0;
	assign LOAD_start	= (is_packet_in.channel == LD)  ? 1 : 0;


	always_comb begin
		MUL_start = 0;
		MUL_valid = 0;

		for (int i = 0; i < `MUL_NUM; i++) begin
			if ((MUL_busy[i] == 0)) begin
				MUL_start[i] = (is_packet_in.channel == MULT);
				MUL_valid = (((MUL_busy | MUL_start) & ~MUL_done) == {`MUL_NUM{1'b1}}) ? 0 : 1;
				break;
			end
		end
	end

	//Load valid 
	assign	LOAD_valid = ((LOAD_busy | LOAD_start) & ~LOAD_done) == 1 ? 0 : 1;
	

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
	ALU alu_0 (
		// Inputs
		.opa(opa_mux_out),
		.opb(opb_mux_out),
		.func(is_packet_in.alu_func),
		.start(ALU_start),
		.is_packet_in(is_packet_in),

		// Output
		.result(ALU_result),
		.done(ALU_done),
		.is_packet_out(ALU_is_packet)
	);

	 // instantiate the branch condition tester
	BRANCH BRANCH_0 (
		// Inputs
		.opa(opa_mux_out),
		.opb(opb_mux_out),
		.rs1(is_packet_in.rs1_value),
		.rs2(is_packet_in.rs2_value),
		.func(is_packet_in.inst.b.funct3),
		.start(BRANCH_start),
		.is_packet_in(is_packet_in),

		//output
		.braddr(BRANCH_addr),
		.cond(brcond_result),
		.done(BRANCH_done),
		.is_packet_out(BRANCH_is_packet)
	);

	//MULTIPLIER_0 (two MULTIPLIERs)
	MULTIPLIER MULTIPLIER_0 [`MUL_NUM-1:0] (
		.opa(opa_mux_out),
		.opb(opb_mux_out),
		.func(is_packet_in.alu_func),
		.clock(clock),
		.reset(reset),
		.start(MUL_start),
		.is_packet_in(is_packet_in),

		//output
		.product(MUL_product),
		.done(MUL_done),
		.busy(MUL_busy),
		.is_packet_out(MUL_is_packet)
	);

	assign STORE_done = 0;
	// ex_packet1 - one of alu or branch; ex_packet2 - one of multiplier -one of Load
	EX_PACKET ex_packet1, ex_packet2, ex_packet3;

	// Pass-throughs
	assign ex_packet1.NPC          = (ALU_done) ? ALU_is_packet.NPC :
												  (BRANCH_done) ? BRANCH_is_packet.NPC : 0;

	assign ex_packet1.PC		   = (ALU_done) ? ALU_is_packet.PC :
												  (BRANCH_done) ? BRANCH_is_packet.PC : 0;

	assign ex_packet1.rs2_value    = (ALU_done) ? ALU_is_packet.rs2_value :
												  (BRANCH_done) ? BRANCH_is_packet.rs2_value : 0;
									
	assign ex_packet1.rd_mem       = (ALU_done) ? ALU_is_packet.rd_mem :
												  (BRANCH_done) ? BRANCH_is_packet.rd_mem : 0;

	assign ex_packet1.wr_mem       = (ALU_done) ? ALU_is_packet.wr_mem :
												  (BRANCH_done) ? BRANCH_is_packet.wr_mem : 0;

	assign ex_packet1.dest_reg_idx = (ALU_done) ? ALU_is_packet.dest_reg_idx :
												  (BRANCH_done) ? BRANCH_is_packet.dest_reg_idx : 0;

	assign ex_packet1.halt         = (ALU_done) ? ALU_is_packet.halt :
												  (BRANCH_done) ? BRANCH_is_packet.halt : 0;

	assign ex_packet1.illegal      = (ALU_done) ? ALU_is_packet.illegal :
												  (BRANCH_done) ? BRANCH_is_packet.illegal : 0;
												  
	assign ex_packet1.csr_op       = (ALU_done) ? ALU_is_packet.csr_op :
												  (BRANCH_done) ? BRANCH_is_packet.csr_op : 0;

	assign ex_packet1.valid        = (ALU_done) ? ALU_is_packet.valid :
												  (BRANCH_done) ? BRANCH_is_packet.valid : 0;

	assign ex_packet1.mem_size     = (ALU_done) ? ALU_is_packet.inst.r.funct3 :
												  (BRANCH_done) ? BRANCH_is_packet.inst.r.funct3 : 0;

	assign ex_packet1.take_branch  = (ALU_done) ? 0 :
												  (BRANCH_done) ? (is_packet_in.uncond_branch | (is_packet_in.cond_branch & brcond_result)) : 0;   // !!! Do we really need that?

	assign ex_packet1.alu_result   = (ALU_done) ? ALU_result :
												  (BRANCH_done) ? BRANCH_addr : 0;

	assign ex_packet1.is_ZEROREG   = (ALU_done) ? ALU_is_packet.is_ZEROREG :
												  (BRANCH_done) ? BRANCH_is_packet.is_ZEROREG : 1;


	always_comb begin
		ex_packet2.NPC          = 0;
		ex_packet2.PC           = 0;
		ex_packet2.rs2_value    = 0;
		ex_packet2.rd_mem       = 0;
		ex_packet2.wr_mem       = 0;
		ex_packet2.dest_reg_idx = 0;
		ex_packet2.halt         = 0;
		ex_packet2.illegal      = 0;
		ex_packet2.csr_op       = 0;
		ex_packet2.valid        = 0;
		ex_packet2.mem_size     = 0;
		ex_packet2.take_branch  = 0;
		ex_packet2.alu_result   = 0;
		ex_packet2.is_ZEROREG	= 1;

		for (int i = 0; i < `MUL_NUM; i++) begin
			if (MUL_done[i]) begin
				ex_packet2.NPC          = MUL_is_packet[i].NPC;
				ex_packet2.PC           = MUL_is_packet[i].PC;
				ex_packet2.rs2_value    = MUL_is_packet[i].rs2_value;
				ex_packet2.rd_mem       = MUL_is_packet[i].rd_mem;
				ex_packet2.wr_mem       = MUL_is_packet[i].wr_mem;
				ex_packet2.dest_reg_idx = MUL_is_packet[i].dest_reg_idx;
				ex_packet2.halt         = MUL_is_packet[i].halt;
				ex_packet2.illegal      = MUL_is_packet[i].illegal;
				ex_packet2.csr_op       = MUL_is_packet[i].csr_op;
				ex_packet2.valid        = MUL_is_packet[i].valid;
				ex_packet2.mem_size     = MUL_is_packet[i].inst.r.funct3;
				ex_packet2.take_branch  = 0;
				ex_packet2.alu_result   = MUL_product[i];
				ex_packet2.is_ZEROREG	= MUL_is_packet[i].is_ZEROREG;

				break;
			end
		end
	end

	//packet3 assignment
	assign ex_packet3.NPC          = (LOAD_done) ? LOAD_is_packet.NPC :
												   (STORE_done) ? STORE_is_packet.NPC : 0;

	assign ex_packet3.PC		   = (LOAD_done) ? LOAD_is_packet.PC :
												   (STORE_done) ? STORE_is_packet.PC : 0;

	assign ex_packet3.rs2_value    = (LOAD_done) ? LOAD_is_packet.rs2_value :
												   (STORE_done) ? STORE_is_packet.rs2_value : 0;

	assign ex_packet3.rd_mem       = (LOAD_done) ? LOAD_is_packet.rd_mem :
												   (STORE_done) ? STORE_is_packet.rd_mem : 0;

	assign ex_packet3.wr_mem       = (LOAD_done) ? LOAD_is_packet.wr_mem :
												   (STORE_done) ? STORE_is_packet.wr_mem : 0;

	assign ex_packet3.dest_reg_idx = (LOAD_done) ? LOAD_is_packet.dest_reg_idx :
												   (STORE_done) ? STORE_is_packet.dest_reg_idx : 0;

	assign ex_packet3.halt         = (LOAD_done) ? LOAD_is_packet.halt :
												   (STORE_done) ? STORE_is_packet.halt : 0;

	assign ex_packet3.illegal      = (LOAD_done) ? LOAD_is_packet.illegal :
												   (STORE_done) ? STORE_is_packet.illegal : 0;
												  
	assign ex_packet3.csr_op       = (LOAD_done) ? LOAD_is_packet.csr_op :
												   (STORE_done) ? STORE_is_packet.csr_op : 0;

	assign ex_packet3.valid        = (LOAD_done) ? LOAD_is_packet.valid :
												   (STORE_done) ? STORE_is_packet.valid : 0;

	assign ex_packet3.mem_size     = (LOAD_done) ? LOAD_is_packet.inst.i.funct3 :
												   (STORE_done) ? STORE_is_packet.inst.s.funct3 : 0;

	assign ex_packet3.take_branch  = 0;

	assign ex_packet3.alu_result   = (LOAD_done) ? LOAD_result : 0;
												  
	assign ex_packet3.is_ZEROREG   = (LOAD_done) ? LOAD_is_packet.is_ZEROREG :
												   (STORE_done) ? STORE_is_packet.is_ZEROREG : 1;



	FIFO f0(
		.clock(clock),
		.reset(reset),
		.ex_packet1(ex_packet1),
		.ex_packet2(ex_packet2),
		.ex_packet3(ex_packet3),

		.ex_packet_out(ex_packet_out),
		.no_output(no_output)
	);

	assign ex2btb_packet_out.PC = ex_packet_out.PC;
	assign ex2btb_packet_out.target_pc = ex_packet_out.alu_result;
	assign ex2btb_packet_out.valid = ex_packet_out.valid;
	assign ex2btb_packet_out.taken = ex_packet_out.take_branch;

	assign correct_predict = ((ex_packet_out.take_branch) == (ex_packet_out.NPC == ex_packet_out.alu_result)) || !ex_packet_out.valid;


	// instantiate the STORE address generator
	// STORE STORE_0 (
	// 	//input
	// 	.opa(opa_mux_out),
	// 	.opb(opb_mux_out),
	// 	.is_packet_in(is_packet_in),
	// 	.start(STORE_start),
	// 	//output
	// 	.addr_result(STORE_addr),
	// 	.STORE_is_packet(STORE_is_packet),
	// 	.done(STORE_done)
	// );
	

	// instantiate the LOAD module
	LOAD LOAD_0 (
		//input
		.clock(clock),
		.reset(reset),
		.opa(opa_mux_out),
		.opb(opb_mux_out),
		.is_packet_in(is_packet_in),
		.start(LOAD_start),
		.Dcache2proc_data(Dcache2proc_data),
		.finish(Dcache_finish),
		//output
		.proc2Dcache_command(proc2Dcache_command),
		.proc2Dcache_addr(proc2Dcache_addr),
		.Dcache_result_out(LOAD_result),
		.load_mem_size(load_mem_size),
		.is_packet_out(LOAD_is_packet),
		.busy(LOAD_busy),
		.done(LOAD_done)
	);


endmodule // module ex_stage
`endif // __EX_STAGE_SV__
