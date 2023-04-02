/////////////////////////////////////////////////////////////////////////
//                                                                     //
//   Modulename :  pipeline.v                                          //
//                                                                     //
//  Description :  Top-level module of the verisimple pipeline;        //
//                 This instantiates and connects the 5 stages of the  //
//                 Verisimple pipeline togeather.                      //
//                                                                     //
//                                                                     //
/////////////////////////////////////////////////////////////////////////

`ifndef __PIPELINE_SV__
`define __PIPELINE_SV__


`include "sys_defs.svh"

module pipeline (
	input        clock,             // System clock
	input        reset,             // System reset
	input [3:0]  mem2proc_response, // Tag from memory about current request
	input [63:0] mem2proc_data,     // Data coming back from memory
	input [3:0]  mem2proc_tag,      // Tag from memory about current reply

	output logic [1:0]       proc2mem_command, // command sent to memory
	output logic [`XLEN-1:0] proc2mem_addr,    // Address sent to memory
	output logic [63:0]      proc2mem_data,    // Data sent to memory
`ifndef CACHE_MODE
	output MEM_SIZE          proc2mem_size,    // data size sent to memory
`endif

	output logic [3:0]       pipeline_completed_insts,
	output EXCEPTION_CODE    pipeline_error_status,
	output logic [4:0]       pipeline_commit_wr_idx,
	output logic [`XLEN-1:0] pipeline_commit_wr_data,
	output logic             pipeline_commit_wr_en,
	output logic [`XLEN-1:0] pipeline_commit_NPC,

	// testing hooks (these must be exported so we can test
	// the synthesized version) data is tested by looking at
	// the final values in memory

	// Outputs from IF-Stage
	output logic [`XLEN-1:0] if_NPC_out,
	output logic [31:0]      if_IR_out,
	output logic             if_valid_inst_out,

	// Outputs from IF/ID Pipeline Register
	output logic [`XLEN-1:0] if_id_NPC,
	output logic [31:0]      if_id_IR,
	output logic             if_id_valid_inst,

	// Outputs from IS/EX Pipeline Register
	output logic [`XLEN-1:0] is_ex_NPC,
	output logic [31:0]      is_ex_IR,
	output logic             is_ex_valid_inst,

	// Outputs from EX/CP Pipeline Register
	output logic [`XLEN-1:0] ex_cp_NPC,
	output logic [31:0]      ex_cp_IR,
	output logic             ex_cp_valid_inst,

	// Outputs from MEM/WB Pipeline Register
	output logic [`XLEN-1:0] mem_wb_NPC,
	output logic [31:0]      mem_wb_IR,
	output logic             mem_wb_valid_inst
);

	// Pipeline register enables
	logic if_id_enable, is_ex_enable, ex_cp_enable;

	// Stall logic
	logic if_stall, dp_is_stall;

	// Outputs from IF-Stage
	logic [`XLEN-1:0] proc2Imem_addr;
	IF_ID_PACKET if_packet;

	// Outputs from IF/DP Pipeline Register
	IF_ID_PACKET if_id_packet;

	// Outputs from DP_IS stage
	ROB2REG_PACKET rob_retire_packet;
	IS_PACKET is_packet;
	logic squash;
	logic dp_is_structural_hazard;		// 1 - structural hazard

	// Outputs from DP_IS/EX Pipeline Register
	IS_PACKET is_ex_packet;

	// Outputs from EX-Stage
	EX_PACKET ex_packet;
	logic ex_valid;
	logic ex_structural_hazard;
	logic ex_no_output;

	assign ex_structural_hazard = ~ex_valid;

	// Outputs from EX/CP Pipeline Register
	EX_PACKET ex_cp_packet;
	logic ex_cp_no_output;

	// Outputs from CP-Stage
	CDB_PACKET cp_packet;

	// Outputs from RT-Stage
	logic [`XLEN-1:0] rt_npc;

	// Outputs to interact with mem.sv
	logic [`XLEN-1:0] mem_result_out;
	logic [`XLEN-1:0] proc2Dmem_addr;
	logic [`XLEN-1:0] proc2Dmem_data;
	logic [1:0]       proc2Dmem_command;
`ifndef CACHE_MODE
	MEM_SIZE          proc2Dmem_size;
`endif

	// Determine the command that must be sent to mem
	assign proc2Dmem_command = BUS_NONE;

	// only the 2 LSB to determine the size;
	assign proc2Dmem_size = MEM_SIZE'(ex_cp_packet.mem_size[1:0]);

	// The memory address is calculated by the ALU
	assign proc2Dmem_data = 0;

	assign proc2Dmem_addr = 0;

	// Outputs from MEM/WB Pipeline Register
	logic             mem_wb_halt;
	logic             mem_wb_illegal;
	logic [4:0]       mem_wb_dest_reg_idx;
	logic [`XLEN-1:0] mem_wb_result;
	logic             mem_wb_take_branch;

	// Outputs from WB-Stage (These loop back to the register file in ID)
	// logic [`XLEN-1:0] wb_reg_wr_data_out;
	// logic [4:0]       wb_reg_wr_idx_out;
	// logic             wb_reg_wr_en_out;

//////////////////////////////////////////////////
//                                              //
//               Testbench Outputs              //
//                                              //
//////////////////////////////////////////////////

	// !!!Need to change
	assign pipeline_completed_insts = {3'b0, mem_wb_valid_inst};
	// !!!Need to change
	assign pipeline_error_status = mem_wb_illegal            ? ILLEGAL_INST :
	                               mem_wb_halt               ? HALTED_ON_WFI :
	                               (mem2proc_response==4'h0) ? LOAD_ACCESS_FAULT :
	                               NO_ERROR;

	 assign pipeline_commit_wr_idx  = rob_retire_packet.dest_reg_idx;
	 assign pipeline_commit_wr_data = rob_retire_packet.dest_reg_value;
	 assign pipeline_commit_wr_en   = rob_retire_packet.valid;
	 assign pipeline_commit_NPC     = if_stage_0.PC_reg;

//////////////////////////////////////////////////
//                                              //
//                Memory Outputs                //
//                                              //
//////////////////////////////////////////////////

	always_comb begin
		if (proc2Dmem_command == BUS_NONE) begin // load an instruction from memory
			proc2mem_command = BUS_LOAD;
			proc2mem_addr    = proc2Imem_addr;
`ifndef CACHE_MODE
			proc2mem_size    = DOUBLE; // if it's an instruction, then load a double word (64 bits)
`endif
		end else begin // do a data operation with memory
			proc2mem_command = proc2Dmem_command;
			proc2mem_addr    = proc2Dmem_addr;
`ifndef CACHE_MODE
			proc2mem_size    = proc2Dmem_size;
`endif
		end
		proc2mem_data = {32'b0, proc2Dmem_data};
	end

//////////////////////////////////////////////////
//                                              //
//                  IF-Stage                    //
//                                              //
//////////////////////////////////////////////////

	// these are debug signals that are now included in the packet,
	// breaking them out to support the legacy debug modes
	assign if_NPC_out        = if_packet.NPC;
	assign if_IR_out         = if_packet.inst;
	assign if_valid_inst_out = if_packet.valid;

	assign if_stall = 0; // Temp value

	if_stage if_stage_0 (
		// Inputs
		.clock (clock),
		.reset (reset),
		.squash(squash),
		.stall (if_stall),
		.rt_npc(rt_npc),
		.Imem2proc_data(mem2proc_data),
		.proc2Dmem_command(BUS_NONE),		// !!!No memory operation for now

		// Outputs
		.proc2Imem_addr(proc2Imem_addr),
		.if_packet_out(if_packet)
	);

//////////////////////////////////////////////////
//                                              //
//            IF/ID Pipeline Register           //
//                                              //
//////////////////////////////////////////////////

	assign if_id_NPC        = if_id_packet.NPC;
	assign if_id_IR         = if_id_packet.inst;
	assign if_id_valid_inst = if_id_packet.valid;

	assign if_id_enable = 1'b1; // always enabled
	// synopsys sync_set_reset "reset"
	always_ff @(posedge clock) begin
		if (reset) begin
			if_id_packet.inst  <= `SD `NOP;
			if_id_packet.valid <= `SD `FALSE;
			if_id_packet.NPC   <= `SD 0;
			if_id_packet.PC    <= `SD 0;
		end else begin // if (reset)
			if (if_id_enable) begin
				if_id_packet <= `SD if_packet;
			end // if (if_id_enable)
		end
	end // always

//////////////////////////////////////////////////
//                                              //
//                  DP_IS-Stage                 //
//                                              //
//////////////////////////////////////////////////

	assign dp_is_stall = 0; // Temp value

	DP_IS DP_IS_0 (
		.clock (clock),
		.reset (reset),
		.stall (dp_is_stall),
		.if_id_packet_in(if_id_packet),
		.cdb_packet_in(cp_packet),

		.is_packet_out(is_packet),
		.rob_retire_packet(rob_retire_packet),
		.struc_hazard(dp_is_structural_hazard),
		.squash(squash)
	);

//////////////////////////////////////////////////
//                                              //
//            IS/EX Pipeline Register           //
//                                              //
//////////////////////////////////////////////////

	assign is_ex_NPC        = is_ex_packet.NPC;
	assign is_ex_IR         = is_ex_packet.inst;
	assign is_ex_valid_inst = is_ex_packet.valid;

	assign is_ex_enable = 1'b1; // always enabled
	// synopsys sync_set_reset "reset"
	always_ff @(posedge clock) begin
		if (reset) begin
			is_ex_packet <= `SD '{{`XLEN{1'b0}},
				{`XLEN{1'b0}},
				{`XLEN{1'b0}},
				{`XLEN{1'b0}},
				OPA_IS_RS1,
				OPB_IS_RS2,
				`NOP,
				`ZERO_REG,
				ALU_ADD,
				1'b0, // rd_mem
				1'b0, // wr_mem
				1'b0, // cond
				1'b0, // uncond
				1'b0, // halt
				1'b0, // illegal
				1'b0, // csr_op
				1'b0, // valid
                1'b1, // is_ZEROREG
                ALU   // channel
			};
		end else begin // if (reset)
			if (is_ex_enable) begin
				is_ex_packet <= `SD is_packet;
			end // if
		end // else: !if(reset)
	end // always

//////////////////////////////////////////////////
//                                              //
//                  EX-Stage                    //
//                                              //
//////////////////////////////////////////////////

	EX ex_stage_0 (
		// Inputs
		.clock(clock),
		.reset(reset),
		.is_packet_in(is_ex_packet),

		// Outputs
		.ex_packet_out(ex_packet),
		.valid(ex_valid),
		.no_output(ex_no_output)
	);

//////////////////////////////////////////////////
//                                              //
//           EX/CP Pipeline Register            //
//                                              //
//////////////////////////////////////////////////

	assign ex_cp_NPC        = ex_cp_packet.NPC;
	assign ex_cp_valid_inst = ex_cp_packet.valid;

	assign ex_cp_enable = 1'b1; // always enabled
	// synopsys sync_set_reset "reset"
	always_ff @(posedge clock) begin
		if (reset) begin
			ex_cp_IR     <= `SD `NOP;
			ex_cp_packet <= `SD 0;
			ex_cp_no_output <= `SD 1;
		end else begin
			if (ex_cp_enable) begin
				// these are forwarded directly from ID/EX registers, only for debugging purposes
				ex_cp_IR     <= `SD is_ex_IR;
				// EX outputs
				ex_cp_packet <= `SD ex_packet;
				ex_cp_no_output <= `SD ex_no_output;
			end // if
		end // else: !if(reset)
	end // always

//////////////////////////////////////////////////
//                                              //
//                  CP-Stage                    //
//                                              //
//////////////////////////////////////////////////

	CDB cp_stage_0 (
		// Inputs
		.ex_packet_in(ex_cp_packet),
		.ex_no_output(ex_cp_no_output),

		// Outputs
		.cdb_packet_out(cp_packet)
	);

//////////////////////////////////////////////////
//                                              //
//                  RT-Stage                    //
//                                              //
//////////////////////////////////////////////////

	rt_stage rt_stage_0 (
		// Inputs
		.clock(clock),
		.reset(reset),
		.cdb_packet_in(cp_packet),

		// Outputs
		.rt_npc_out(rt_npc)
	);

//////////////////////////////////////////////////
//                                              //
//                 MEM-Stage                    //
//                                              //
//////////////////////////////////////////////////

// 	mem_stage mem_stage_0 (
// 		// Inputs
// 		.clock(clock),
// 		.reset(reset),
// 		.ex_mem_packet_in(ex_mem_packet),
// 		.Dmem2proc_data(mem2proc_data[`XLEN-1:0]),

// 		// Outputs
// 		.mem_result_out(mem_result_out),
// 		.proc2Dmem_command(proc2Dmem_command),
// `ifndef CACHE_MODE
// 		.proc2Dmem_size(proc2Dmem_size),
// `endif
// 		.proc2Dmem_addr(proc2Dmem_addr),
// 		.proc2Dmem_data(proc2Dmem_data)
// 	);

//////////////////////////////////////////////////
//                                              //
//           MEM/WB Pipeline Register           //
//                                              //
//////////////////////////////////////////////////

	assign mem_wb_enable = 1'b1; // always enabled
	// synopsys sync_set_reset "reset"
	always_ff @(posedge clock) begin
		if (reset) begin
			mem_wb_NPC          <= `SD 0;
			mem_wb_IR           <= `SD `NOP;
			mem_wb_halt         <= `SD 0;
			mem_wb_illegal      <= `SD 0;
			mem_wb_valid_inst   <= `SD 0;
			mem_wb_dest_reg_idx <= `SD `ZERO_REG;
			mem_wb_take_branch  <= `SD 0;
			mem_wb_result       <= `SD 0;
		end else begin
			if (mem_wb_enable) begin
				// these are should come from retire stage!!!
				mem_wb_NPC          <= `SD ex_cp_packet.NPC;
				mem_wb_IR           <= `SD ex_cp_IR;
				mem_wb_halt         <= `SD ex_cp_packet.halt;
				mem_wb_illegal      <= `SD ex_cp_packet.illegal;
				mem_wb_valid_inst   <= `SD ex_cp_packet.valid;
				mem_wb_dest_reg_idx <= `SD ex_cp_packet.dest_reg_idx;
				mem_wb_take_branch  <= `SD ex_cp_packet.take_branch;
				// these are results of MEM stage
				mem_wb_result       <= `SD mem_result_out;
			end // if
		end // else: !if(reset)
	end // always

//////////////////////////////////////////////////
//                                              //
//                  WB-Stage                    //
//                                              //
//////////////////////////////////////////////////

	// wb_stage wb_stage_0 (
	// 	// Inputs
	// 	.clock(clock),
	// 	.reset(reset),
	// 	.mem_wb_NPC(mem_wb_NPC),
	// 	.mem_wb_result(mem_wb_result),
	// 	.mem_wb_dest_reg_idx(mem_wb_dest_reg_idx),
	// 	.mem_wb_take_branch(mem_wb_take_branch),
	// 	.mem_wb_valid_inst(mem_wb_valid_inst),

	// 	// Outputs
	// 	.reg_wr_data_out(wb_reg_wr_data_out),
	// 	.reg_wr_idx_out(wb_reg_wr_idx_out),
	// 	.reg_wr_en_out(wb_reg_wr_en_out)
	// );

endmodule // module verisimple
`endif // __PIPELINE_SV__
