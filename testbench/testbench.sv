/////////////////////////////////////////////////////////////////////////
//                                                                     //
//   Modulename :  testbench.v                                         //
//                                                                     //
//  Description :  Testbench module for the verisimple pipeline;       //
//                                                                     //
//                                                                     //
/////////////////////////////////////////////////////////////////////////

`include "sys_defs.svh"



/* PIPEPRINT_UNUSED: no pipe_print for project 4, although feel free to write your own
// these link to the pipe_print.c file in this directory, and are used below to print
// detailed output to the pipeline_output_file, initialized by open_pipeline_output_file()
import "DPI-C" function void open_pipeline_output_file(string file_name);
import "DPI-C" function void print_header(string str);
import "DPI-C" function void print_cycles();
import "DPI-C" function void print_stage(string div, int inst, int npc, int valid_inst);
import "DPI-C" function void print_reg(int wb_reg_wr_data_out_hi, int wb_reg_wr_data_out_lo,
                                       int wb_reg_wr_idx_out, int wb_reg_wr_en_out);
import "DPI-C" function void print_membus(int proc2mem_command, int mem2proc_response,
                                          int proc2mem_addr_hi, int proc2mem_addr_lo,
                                          int proc2mem_data_hi, int proc2mem_data_lo);
import "DPI-C" function void print_close();
*/

module testbench;
	// used to parameterize which files are used for memory and writeback/pipeline outputs
	// "./simv" uses program.mem, writeback.out, and pipeline.out
	// but now "./simv +MEMORY=<my_program>.mem" loads <my_program>.mem instead
	// use +WRITEBACK=<my_program>.wb and +PIPELINE=<my_program>.ppln for those outputs as well
	string program_memory_file;
	string writeback_output_file;
	string pipeline_output_file;
	/* PIPEPRINT_UNUSED
	string pipeline_output_file;
	*/

	// variables used in the testbench
	logic        clock;
	logic        reset;
	logic [31:0] clock_count;
	logic [31:0] instr_count;
	int          wb_fileno;
	int          pipe_output;   // used for function pipeline_output
	logic [63:0] debug_counter; // counter used for when pipeline infinite loops, forces termination

	logic [1:0]       proc2mem_command;
	logic [`XLEN-1:0] proc2mem_addr;
	logic [63:0]      proc2mem_data;
	logic [3:0]       mem2proc_response;
	logic [63:0]      mem2proc_data;
	logic [3:0]       mem2proc_tag;
`ifndef CACHE_MODE
	MEM_SIZE          proc2mem_size;
`endif

	logic [3:0]       pipeline_completed_insts;
	EXCEPTION_CODE    pipeline_error_status;
	logic [4:0]       pipeline_commit_wr_idx;
	logic [`XLEN-1:0] pipeline_commit_wr_data;
	logic             pipeline_commit_wr_en;
	logic [`XLEN-1:0] pipeline_commit_PC;

	logic [`XLEN-1:0] if_NPC_out;
	logic [31:0]      if_IR_out;
	logic             if_valid_inst_out;
	logic [`XLEN-1:0] if_id_NPC;
	logic [31:0]      if_id_IR;
	logic             if_id_valid_inst;
	logic [`XLEN-1:0] is_ex_NPC;
	logic [31:0]      is_ex_IR;
	logic             is_ex_valid_inst;
	logic [`XLEN-1:0] ex_cp_NPC;
	logic [31:0]      ex_cp_IR;
	logic             ex_cp_valid_inst;
	logic [`XLEN-1:0] mem_wb_NPC;
	logic [31:0]      mem_wb_IR;
	logic             mem_wb_valid_inst;


	// Instantiate the Pipeline
	pipeline core (
		// Inputs
		.clock             (clock),
		.reset             (reset),
		.mem2proc_response (mem2proc_response),
		.mem2proc_data     (mem2proc_data),
		.mem2proc_tag      (mem2proc_tag),

		// Outputs
		.proc2mem_command (proc2mem_command),
		.proc2mem_addr    (proc2mem_addr),
		.proc2mem_data    (proc2mem_data),
`ifndef CACHE_MODE
		.proc2mem_size    (proc2mem_size),
`endif

		.pipeline_completed_insts (pipeline_completed_insts),
		.pipeline_error_status    (pipeline_error_status),
		.pipeline_commit_wr_data  (pipeline_commit_wr_data),
		.pipeline_commit_wr_idx   (pipeline_commit_wr_idx),
		.pipeline_commit_wr_en    (pipeline_commit_wr_en),
		.pipeline_commit_PC       (pipeline_commit_PC),

		.if_NPC_out        (if_NPC_out),
		.if_IR_out         (if_IR_out),
		.if_valid_inst_out (if_valid_inst_out),
		.if_id_NPC         (if_id_NPC),
		.if_id_IR          (if_id_IR),
		.if_id_valid_inst  (if_id_valid_inst),
		.is_ex_NPC         (is_ex_NPC),
		.is_ex_IR          (is_ex_IR),
		.is_ex_valid_inst  (is_ex_valid_inst),
		.ex_cp_NPC         (ex_cp_NPC),
		.ex_cp_IR          (ex_cp_IR),
		.ex_cp_valid_inst  (ex_cp_valid_inst),

		.mem_wb_NPC        (mem_wb_NPC),
		.mem_wb_IR         (mem_wb_IR),
		.mem_wb_valid_inst (mem_wb_valid_inst)
	);


	// Instantiate the Data Memory
	mem memory (
		// Inputs
		.clk              (clock),
		.proc2mem_command (proc2mem_command),
		.proc2mem_addr    (proc2mem_addr),
		.proc2mem_data    (proc2mem_data),
`ifndef CACHE_MODE
		.proc2mem_size    (proc2mem_size),
`endif

		// Outputs
		.mem2proc_response (mem2proc_response),
		.mem2proc_data     (mem2proc_data),
		.mem2proc_tag      (mem2proc_tag)
	);

	function pipeline_output;

		// $fdisplay(pipe_output, "\n ---------------------------Cycle %d---------------------------", clock_count);
		// $fdisplay(pipe_output, "\n System Halt is: %b", core.rob_retire_packet.halt);
		// $fdisplay(pipe_output, "\n squash is: %b", core.squash);

		// $fdisplay(pipe_output, "\n ----------------------PC----------------------");
		// $fdisplay(pipe_output, "IF_PC: %h, DP_PC: %h, IS_PC: %h, IS_EX_PC: %h, EX_PC: %h, CP_PC: %h, RT_PC: %h",
		// 		 core.if_packet.PC, core.DP_IS_0.id_packet.PC, core.is_packet.PC, core.is_ex_packet.PC, core.ex_packet.PC, core.cp_packet.PC , pipeline_commit_PC);

		// // $fdisplay(pipe_output, "\n ----------------------I cache----------------------");
		// // $fdisplay(pipe_output, "icache unanswer miss: %b, missed outstanding: %b, current tag: %b, last tag: %b, current index: %b, last index: %b, drequest: %b, changed addr: %b", core.icache_0.unanswered_miss, core.icache_0.miss_outstanding, core.icache_0.current_tag, core.icache_0.last_tag, core.icache_0.current_index, core.icache_0.last_index, core.cache_controller_0.d_request, core.icache_0.changed_addr);
		// // $fdisplay(pipe_output, "update mem tag: %b, current mem tag: %b, got mem data: %b", core.icache_0.update_mem_tag, core.icache_0.current_mem_tag, core.icache_0.got_mem_data);
		// // $fdisplay(pipe_output, "core => Icache address; %h", core.proc2Icache_addr); 
		// // $fdisplay(pipe_output, "Icache => core data: %h, valid; %b", core.Icache_data_out, core.Icache_valid_out); 
		// // $fdisplay(pipe_output, "Icache => controller  command: %b, addr: %h", core.Icache2ctrl_command, core.Icache2ctrl_addr);
		// // $fdisplay(pipe_output, "controller => icache  response: %b, data: %h, tag: %b, ", core.ctrl2Icache_response, core.ctrl2Icache_data, core.ctrl2Icache_tag);


		// // $fdisplay(pipe_output, "\n ----------------------Memory----------------------");
		// // $fdisplay(pipe_output, "Memory => controller  response: %b, data: %h, tag: %b, ", mem2proc_response, mem2proc_data, mem2proc_tag);
		// // $fdisplay(pipe_output, "controller => Memory  command: %b, data: %h, addr: %h, ", proc2mem_command, proc2mem_data, proc2mem_addr);


		// $fdisplay(pipe_output, "\n ----------------------D cache----------------------");
        // $fdisplay(pipe_output, "Dcache clear index: %h", core.dcache_0.clear_index);
        // $fdisplay(pipe_output, "Dcache data tag: %h", core.dcache_0.dcache_data[0].tags);
		// $fdisplay(pipe_output, "Dcache miss outstanding: %b, unswered miss: %b, changed addr: %b", core.dcache_0.miss_outstanding, core.dcache_0.unanswered_miss, core.dcache_0.changed_addr); 
		// $fdisplay(pipe_output, "Dcache writeback: %b, finish write back: %b", core.dcache_0.writeback, core.dcache_0.writeback_finished_reg);
		// $fdisplay(pipe_output, "update mem tag: %b, current mem tag: %b, got mem data: %b", core.dcache_0.update_mem_tag, core.dcache_0.current_mem_tag, core.dcache_0.got_mem_data);
		// $fdisplay(pipe_output, "core => Dcache address: %h, data: %h, command: %b, mem_size: %b", core.proc2Dcache_addr, core.proc2Dcache_data, core.proc2Dcache_command, core.proc2Dcache_mem_size); 
		// $fdisplay(pipe_output, "Dcache => core data: %h, finish: %b", core.Icache_data_out, core.Dcache_finish); 
		// $fdisplay(pipe_output, "Dcache => controller  command: %b, addr: %h, data: %h", core.Dcache2ctrl_command, core.Dcache2ctrl_addr, core.Dcache2ctrl_data);
		// $fdisplay(pipe_output, "controller => Dcache  response: %b, data: %h, tag: %b, ", core.ctrl2Dcache_response, core.ctrl2Dcache_data, core.ctrl2Dcache_tag);

		// // $fdisplay(pipe_output, "\n ----------------------IF_PACKET------------------------");
		// // $fdisplay(pipe_output, "|   inst    |    PC    |    NPC    |   valid   |");
		// // $fdisplay(pipe_output, "| %h  | %h  | %h  |   %b   |",
		// // 				core.if_packet.inst.inst,
		// // 				core.if_packet.PC,
		// // 				core.if_packet.NPC,
		// // 				core.if_packet.valid);	

		// // $fdisplay(pipe_output, "\n ----------------------IF_ID_PACKET------------------------");
		// // $fdisplay(pipe_output, "|   inst    |    PC    |    NPC    |   valid   | icache valid |");
		// // $fdisplay(pipe_output, "| %h  | %h  | %h  |   %b   |",
		// // 				core.if_id_packet.inst.inst,
		// // 				core.if_id_packet.PC,
		// // 				core.if_id_packet.NPC,
		// // 				core.if_id_packet.valid,
		// // 				core.if_id_Icache_valid_out);

		// // // $fdisplay(pipe_output, "\n ----------------------BTB-----------------------");
		// // // $fdisplay(pipe_output, "if_packet_in.PC: %h, if_packet_in.valid: %d", core.BTB_0.if_packet_in.PC, core.BTB_0.if_packet_in.valid);  
		// // // $fdisplay(pipe_output, "id_packet_in.PC: %h, id_packet_in.valid: %d", core.BTB_0.id_packet_in.PC, core.BTB_0.id_packet_in.valid);  
		// // // $fdisplay(pipe_output, "ex_packet_in.PC: %h ex_packet_in.valid: %d ex_packet_in.taken: %b ex_packet_in.target_pc: %h", core.BTB_0.ex_packet_in.PC, core.BTB_0.ex_packet_in.valid, 
		// // // 																												core.BTB_0.ex_packet_in.taken, core.BTB_0.ex_packet_in.target_pc);  
		// // // $fdisplay(pipe_output, "btb_packet_out.prediction: %b btb_packet_out.valid: %b btb_packet_out.target_pc: %h", core.BTB_0.btb_packet_out.prediction, core.BTB_0.btb_packet_out.valid, 
		// // // 																												core.BTB_0.btb_packet_out.target_pc);  

		// // $fdisplay(pipe_output, "\n ----------------------ID_PACKET------------------------");	
		// // $fdisplay(pipe_output, "|   Inst    |    PC    |    NPC     |  valid   |   mem size   |");
		// // $fdisplay(pipe_output, "|  %h  |  %h  |   %h  |   %b  |   %d   |",
		// // 						core.DP_IS_0.id_packet.inst.inst, 
		// // 						core.DP_IS_0.id_packet.PC, 
		// // 						core.DP_IS_0.id_packet.NPC, 
		// // 						core.DP_IS_0.id_packet.valid, 
		// // 						core.DP_IS_0.id_packet.mem_size);


		// // $fdisplay(pipe_output, "if_stall: %b, if_id_enable: %b", core.if_stall, core.if_id_enable);
		// // $fdisplay(pipe_output, "\n DP_IS_Stall: %b", core.dp_is_stall);
		// // $fdisplay(pipe_output, "DP_IS_Structural_Hazard: %b", core.dp_is_structural_hazard);
		// // $fdisplay(pipe_output, "mem_flag: %b", core.mem_flag);

		// $fdisplay(pipe_output, "\n ----------------------ROB-----------------------");
		// $fdisplay(pipe_output, "ROB_head: %d, ROB_tail: %d ROB Structural Hazard: %b, next ROB Structural Hazard: %b", core.DP_IS_0.ROB_0.head_idx, core.DP_IS_0.ROB_0.tail_idx, core.DP_IS_0.rob_struc_hazard, core.DP_IS_0.next_rob_struc_hazard);  
		// // $fdisplay(pipe_output, "is_init: %d", core.DP_IS_0.ROB_0.is_init);
		// $fdisplay(pipe_output, "ROB Index | REG ID | Value |  PC   |  Complete | Halt | Illegal");
		// for(int i=0; i<`ROB_LEN; i=i+1) begin
		// 	$fdisplay(pipe_output, "%d | %d | %h |   %h   |  %b   |   %b   |   %b | ",
		// 		i,
		// 		core.DP_IS_0.ROB_0.rob_entry_packet_out[i].dest_reg_idx,
		// 		core.DP_IS_0.ROB_0.rob_entry_packet_out[i].dest_reg_value,
		// 		core.DP_IS_0.ROB_0.rob_entry_packet_out[i].PC,
		// 		core.DP_IS_0.ROB_0.rob_entry_packet_out[i].valid,
		// 		core.DP_IS_0.ROB_0.rob_entry_packet_out[i].is_halt,
		// 		core.DP_IS_0.ROB_0.rob_entry_packet_out[i].is_illegal);
		// end

		// // $fdisplay(pipe_output, "\n ----------------------RS------------------------");	
		// // $fdisplay(pipe_output, "RS dispatch stall: %b, RS issue stall: %b", core.DP_IS_0.dispatch_stall, core.DP_IS_0.is_stall);
		// // $fdisplay(pipe_output, "RS Structural Hazard: %b", ~core.DP_IS_0.RS_struc_hazard_inv);
		// // $fdisplay(pipe_output, "RS Index | ROB Index | Wr_en | Busy |    Inst    |    PC     | Ready   |   Clear   |   Tag1   |   T1_v    |   Tag2   |   T2_v   |");

		// // for (int i = 0; i < `RS_LEN; i++) begin
        // //         $fdisplay(pipe_output, "|   [%1d]     |   %d   |   %d   |  %d   |   %h    |   %h    |   %d   |   %d   |    %d    |    %d    |     %d     |     %d     |",
        // //                  i, 
		// // 				 core.DP_IS_0.RS_0.rs_entry_packet_out[i].dest_reg_idx,
		// // 				 core.DP_IS_0.RS_0.rs_entry_enable[i], 
		// // 				 core.DP_IS_0.RS_0.rs_entry_busy[i], 
		// // 				 core.DP_IS_0.RS_0.rs_entry_packet_out[i].inst.inst, 
		// // 				 core.DP_IS_0.RS_0.rs_entry_packet_out[i].NPC-4,
		// // 				 core.DP_IS_0.RS_0.rs_entry_ready[i], 
		// // 				 core.DP_IS_0.RS_0.rs_entry_clear[i], 
		// // 				 core.DP_IS_0.RS_0.entry_rs1_tags[i].tag, 
		// // 				 core.DP_IS_0.RS_0.entry_rs1_tags[i].valid, 
		// // 				 core.DP_IS_0.RS_0.entry_rs2_tags[i].tag,
		// // 				 core.DP_IS_0.RS_0.entry_rs2_tags[i].valid);
        // // end

		// // // $fdisplay(pipe_output, "\n ----------------------ID_PACKET------------------------");	
		// // // $fdisplay(pipe_output, "decode valid: %b, illegal: %b", core.DP_IS_0.id_stage_0.decoder_0.valid_inst, core.DP_IS_0.id_stage_0.decoder_0.illegal);
		// // // $fdisplay(pipe_output, "if_id_packet.valid; %b, id_packet_valid: %b", core.if_id_packet.valid, core.DP_IS_0.id_packet.valid);

		// // $fdisplay(pipe_output, "\n ----------------------IS_PACKET------------------------");	
		// // $fdisplay(pipe_output, "| rs1_value  |  rs2_value  |  OPA  |  OPB  | alu_func  |  channel |   valid   |");
		// // $fdisplay(pipe_output, " %h  | %h  | %d  |   %d   |   %d  |  %d   |   %b   |",
		// // 				core.is_packet.rs1_value,
		// // 				core.is_packet.rs2_value,
		// // 				core.is_packet.opa_select,
		// // 				core.is_packet.opb_select,
		// // 				core.is_packet.alu_func,
		// // 				core.is_packet.channel,
		// // 				core.is_packet.valid);

		// // $fdisplay(pipe_output, "\n ----------------------STORE UNIT------------------------");
		// // $fdisplay(pipe_output, "STORE valid: %b", core.STORE_valid);
		// // $fdisplay(pipe_output, "opa: %h, opb: %h", core.ex_stage_0.opa_mux_out, core.ex_stage_0.opb_mux_out);
		// // $fdisplay(pipe_output, "start: %b, busy: %b, done; %b", core.ex_stage_0.STORE_start, core.ex_stage_0.STORE_busy, core.ex_stage_0.STORE_done);
		// // $fdisplay(pipe_output, "From Issue Stage: is_STORE: %b", core.is_ex_packet.wr_mem);
		// // $fdisplay(pipe_output, "To Dcache command: %b, addr: %h, data: %h, mem_size: %d", core.ex_stage_0.store2Dcache_command, core.ex_stage_0.store2Dcache_addr, core.ex_stage_0.proc2Dcache_data, core.ex_stage_0.store_mem_size);
		// // $fdisplay(pipe_output, "From Dcache finish: %b", core.Dcache_finish);

		// // $fdisplay(pipe_output, "\n ----------------------LOAD UNIT------------------------");
		// // $fdisplay(pipe_output, "LOAD valid: %b", core.LOAD_valid);
		// // $fdisplay(pipe_output, "opa: %h, opb: %h", core.ex_stage_0.opa_mux_out, core.ex_stage_0.opb_mux_out);
		// // $fdisplay(pipe_output, "start: %b, busy: %b, done; %b", core.ex_stage_0.LOAD_start, core.ex_stage_0.LOAD_busy, core.ex_stage_0.LOAD_done);
		// // $fdisplay(pipe_output, "From Issue Stage: is_load: %b", core.is_ex_packet.rd_mem);
		// // $fdisplay(pipe_output, "To Dcache command: %b, addr: %h, mem_size: %d", core.ex_stage_0.load2Dcache_command, core.ex_stage_0.load2Dcache_addr, core.ex_stage_0.load_mem_size);
		// // $fdisplay(pipe_output, "From Dcache data: %h, finish: %b", core.Dcache2proc_data, core.Dcache_finish);

		// // $fdisplay(pipe_output, "\n ----------------------MUL 0------------------------");
		// // $fdisplay(pipe_output, "start: %b, busy: %b, done; %b", core.ex_stage_0.MULTIPLIER_0[0].start, core.ex_stage_0.MULTIPLIER_0[0].busy, core.ex_stage_0.MULTIPLIER_0[0].done);

		// // $fdisplay(pipe_output, "\n ----------------------MUL 1------------------------");
		// // $fdisplay(pipe_output, "start: %b, busy: %b, done; %b", core.ex_stage_0.MULTIPLIER_0[1].start, core.ex_stage_0.MULTIPLIER_0[1].busy, core.ex_stage_0.MULTIPLIER_0[1].done);

		// // $fdisplay(pipe_output, "\n ----------------------FIFO-----------------------");
		// // $fdisplay(pipe_output, " pointer: %d", core.ex_stage_0.f0.pointer);
		// // $fdisplay(pipe_output, "@@@ FIFO contents:");
		// // for (int i = 0; i < 8; i++) begin
		// // 	$fdisplay(pipe_output, "@@@ [%1d] packet PC: %d", i, core.ex_stage_0.f0.fifo_storage[i].PC);
		// // end


		// // $fdisplay(pipe_output, "\n ----------------------EX_PACKET------------------------");	
		// // $fdisplay(pipe_output, " issue stall due to ex stage hazard: %b", core.is_stall);
		// // $fdisplay(pipe_output, " store_packet: wr_mem: %b, ex_packet3_wr_mem: %b", core.ex_stage_0.STORE_is_packet.wr_mem, core.ex_stage_0.ex_packet3.wr_mem);
		// // $fdisplay(pipe_output, " ex stage valid: %b", core.ex_valid); 
		// // $fdisplay(pipe_output, " ex stage no output: %b", core.ex_no_output); 
		// // $fdisplay(pipe_output, " ex stage mul busy: %b", core.ex_stage_0.MUL_busy);
		// // $fdisplay(pipe_output, " ex stage mul start: %b", core.ex_stage_0.MUL_start);
		// // $fdisplay(pipe_output, "| alu_result  |  take_branch  | ROB Index  |  rd_mem  | wr_mem  |   PC    |   NPC   |  uncond branch |");
		// // $fdisplay(pipe_output, " %h  |    %d    |    %d    |    %d    |    %d   |    %h    |  %h   |   %b   |",
		// // 				core.ex_packet.alu_result,
		// // 				core.ex_packet.take_branch,
		// // 				core.ex_packet.dest_reg_idx,
		// // 				core.ex_packet.rd_mem,
		// // 				core.ex_packet.wr_mem,
		// // 				core.ex_packet.PC,
		// // 				core.ex_packet.NPC,
		// // 				core.ex_packet.uncond_branch);

		// // $fdisplay(pipe_output, "\n ----------------------EX_PACKET 3------------------------");	
		// // $fdisplay(pipe_output, "| alu_result  |  rs2_value   |  take_branch  | ROB Index  |  rd_mem  | wr_mem  |");
		// // $fdisplay(pipe_output, " %h   |    %d     |    %b    |    %d    |    %b    |    %b   |",
		// // 				core.ex_stage_0.ex_packet3.alu_result,
		// // 				core.ex_stage_0.ex_packet3.rs2_value,
		// // 				core.ex_stage_0.ex_packet3.take_branch,
		// // 				core.ex_stage_0.ex_packet3.dest_reg_idx,
		// // 				core.ex_stage_0.ex_packet3.rd_mem,
		// // 				core.ex_stage_0.ex_packet3.wr_mem);

		// // // $fdisplay(pipe_output, "\n ----------------------MAP TABLE------------------------");	
		// // // $fdisplay(pipe_output, " |  REG Index |  ROB Tag  |  valid  |");
		// // // for(int i=0; i<32; i=i+1) begin
		// // // 	$fdisplay(pipe_output, " %d |  %d  |  %b  |", i, core.DP_IS_0.MT_0.map_table_entry_tag[i].tag, core.DP_IS_0.MT_0.map_table_entry_tag[i].valid);
		// // // end


		// // $fdisplay(pipe_output, "\n ----------------------CDB------------------------");	
		// // $fdisplay(pipe_output, "| ROB Index  |  Value  |  Valid  | take_branch  |  halt  | illegal  |");
		// // $fdisplay(pipe_output, " %d   |   %h   |   %b   |   %d   |    %d   |   %d  |",
		// // 				core.cp_packet.reg_tag.tag,
		// // 				core.cp_packet.reg_value,
		// // 				core.cp_packet.reg_tag.valid,
		// // 				core.cp_packet.take_branch,
		// // 				core.cp_packet.halt,
		// // 				core.cp_packet.illegal);

		// $fdisplay(pipe_output,"=====   Cache ram   =====");
        // $fdisplay(pipe_output,"|Entry(idx)|valid|dirty|      Tag |             data |");
        // for (int i=0; i<32; ++i) begin
        //     $fdisplay(pipe_output,"| %d | %b | %b | %d | %h |", i, core.dcache_0.dcache_data[i].valid, core.dcache_0.dcache_data[i].dirty, core.dcache_0.dcache_data[i].tags, core.dcache_0.dcache_data[i].data);
        // end
        // $fdisplay(pipe_output,"-------------------------------------------------");
    

		// // $fdisplay(pipe_output, "\n ----------------------RETIRE------------------------");	
		// // $fdisplay(pipe_output, "ROB retire packet PC: %h, halt: %b, illegal: %b", core.rob_retire_packet.PC, core.rob_retire_packet.halt, core.rob_retire_packet.illegal);
		// // $fdisplay(pipe_output, "ROB2REG packet    addr: %h, value: %h, valid: %b", core.rob_retire_packet.dest_reg_idx, core.rob_retire_packet.dest_reg_value, core.rob_retire_packet.valid);
		// // $fdisplay(pipe_output, "pipeline completed insts: %h", pipeline_completed_insts);



		// // // $fdisplay(pipe_output, "\n -------------------REG------------------------");	
		// // // $fdisplay(pipe_output, "        Index | Data |");
		// // // for(int i=0; i<32; i=i+1) begin
		// // // 	$fdisplay(pipe_output, " %d |  %h |", i,  core.DP_IS_0.id_stage_0.regf_0.registers[i]);
		// // // end
	endfunction



	// Generate System Clock
	always begin
		#(`CLOCK_PERIOD/2.0);
		clock = ~clock;
	end


	// Task to display # of elapsed clock edges
	task show_clk_count;
		real cpi;
		begin
			cpi = (clock_count + 1.0) / instr_count;
			$display("@@  %0d cycles / %0d instrs = %f CPI\n@@",
			          clock_count+1, instr_count, cpi);
			$display("@@  %4.2f ns total time to execute\n@@\n",
			          clock_count*`CLOCK_PERIOD);
		end
	endtask // task show_clk_count


	// Show contents of a range of Unified Memory, in both hex and decimal
	task show_mem_with_decimal;
		input [31:0] start_addr;
		input [31:0] end_addr;
		int showing_data;
		begin
			$display("@@@");
			showing_data=0;
			for(int k=start_addr;k<=end_addr; k=k+1)
				if (memory.unified_memory[k] != 0) begin
					$display("@@@ mem[%5d] = %x : %0d", k*8, memory.unified_memory[k],
					                                         memory.unified_memory[k]);
					showing_data=1;
				end else if(showing_data!=0) begin
					$display("@@@");
					showing_data=0;
				end
			$display("@@@");
		end
	endtask // task show_mem_with_decimal


	initial begin
		//$dumpvars;

		// set paramterized strings, see comment at start of module
		if ($value$plusargs("MEMORY=%s", program_memory_file)) begin
			$display("Loading memory file: %s", program_memory_file);
		end else begin
			$display("Loading default memory file: program.mem");
			program_memory_file = "program.mem";
		end
		if ($value$plusargs("WRITEBACK=%s", writeback_output_file)) begin
			$display("Using writeback output file: %s", writeback_output_file);
		end else begin
			$display("Using default writeback output file: writeback.out");
			writeback_output_file = "writeback.out";
		end
		
		// PIPEPRINT_UNUSED
		if ($value$plusargs("PIPELINE=%s", pipeline_output_file)) begin
			$display("Using pipeline output file: %s", pipeline_output_file);
		end else begin
			$display("Using default pipeline output file: pipeline.out");
			pipeline_output_file = "pipeline.out";
		end
		

		clock = 1'b0;
		reset = 1'b0;

		// Pulse the reset signal
		$display("@@\n@@\n@@  %t  Asserting System reset......", $realtime);
		reset = 1'b1;
		@(posedge clock);
		@(posedge clock);

		// store the compiled program's hex data into memory
		$readmemh(program_memory_file, memory.unified_memory);

		@(posedge clock);
		@(posedge clock);
		`SD;
		// This reset is at an odd time to avoid the pos & neg clock edges

		reset = 1'b0;
		$display("@@  %t  Deasserting System reset......\n@@\n@@", $realtime);

		wb_fileno = $fopen(writeback_output_file);
		pipe_output = $fopen(pipeline_output_file);		

		/* PIPEPRINT_UNUSED
		// Open pipeline output file AFTER throwing the reset otherwise the reset state is displayed
		open_pipeline_output_file(pipeline_output_file);
		print_header("                                                                            D-MEM Bus &\n");
		print_header("Cycle:      IF      |     ID      |     EX      |     MEM     |     WB      Reg Result");
		*/
	end


	// Count the number of posedges and number of instructions completed
	// till simulation ends
	always @(posedge clock) begin
		if(reset) begin
			clock_count <= `SD 0;
			instr_count <= `SD 0;
		end else begin
			clock_count <= `SD (clock_count + 1);
			instr_count <= `SD (instr_count + pipeline_completed_insts);
		end
	end

	always @(negedge clock) begin
		#1;
		pipeline_output();
	end	


	always @(negedge clock) begin
		if(reset) begin
			$display("@@\n@@  %t : System STILL at reset, can't show anything\n@@",
			         $realtime);
			debug_counter <= 0;
		end else begin
			`SD;
			`SD;

			/* PIPEPRINT_UNUSED
			 // print the piepline stuff via c code to the pipeline output file
			 print_cycles();
			 print_stage(" ", if_IR_out, if_NPC_out[31:0], {31'b0,if_valid_inst_out});
			 print_stage("|", if_id_IR,  if_id_NPC [31:0], {31'b0,if_id_valid_inst});
			 print_stage("|", is_ex_IR,  is_ex_NPC [31:0], {31'b0,is_ex_valid_inst});
			 print_stage("|", ex_cp_IR, ex_cp_NPC[31:0], {31'b0,ex_cp_valid_inst});
			 print_stage("|", mem_wb_IR, mem_wb_NPC[31:0], {31'b0,mem_wb_valid_inst});
			 print_reg(32'b0, pipeline_commit_wr_data[31:0],
				{27'b0,pipeline_commit_wr_idx}, {31'b0,pipeline_commit_wr_en});
			 print_membus({30'b0,proc2mem_command}, {28'b0,mem2proc_response},
				32'b0, proc2mem_addr[31:0],
				proc2mem_data[63:32], proc2mem_data[31:0]);
			*/

			// print the writeback information to writeback output file
			if(pipeline_completed_insts>0) begin
				if(pipeline_commit_wr_en)
					$fdisplay(wb_fileno, "PC=%x, REG[%d]=%x",
						pipeline_commit_PC,
						pipeline_commit_wr_idx,
						pipeline_commit_wr_data);
				else
					$fdisplay(wb_fileno, "PC=%x, ---",pipeline_commit_PC);
			end

			// deal with any halting conditions
			if(pipeline_error_status != NO_ERROR || debug_counter > 5000000) begin
				$display("@@@ Unified Memory contents hex on left, decimal on right: ");
				show_mem_with_decimal(0,`MEM_64BIT_LINES - 1);
				// 8Bytes per line, 16kB total

				$display("@@  %t : System halted\n@@", $realtime);

				case(pipeline_error_status)
					LOAD_ACCESS_FAULT:
						$display("@@@ System halted on memory error");
					HALTED_ON_WFI:
						$display("@@@ System halted on WFI instruction");
					ILLEGAL_INST:
						$display("@@@ System halted on illegal instruction");
					default:
						$display("@@@ System halted on unknown error code %x",
							pipeline_error_status);
				endcase
				$display("@@@\n@@");
				show_clk_count;
				/* PIPEPRINT_UNUSED
				print_close(); // close the pipe_print output file
				*/
				$fclose(wb_fileno);
				$fclose(pipe_output);

				#100 $finish;
			end
			debug_counter <= debug_counter + 1;
		end // if(reset)
	end

endmodule // module testbench
