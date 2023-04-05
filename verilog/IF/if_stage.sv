/////////////////////////////////////////////////////////////////////////
//                                                                     //
//   Modulename :  if_stage.v                                          //
//                                                                     //
//  Description :  instruction fetch (IF) stage of the pipeline;       //
//                 fetch instruction, compute next PC location, and    //
//                 send them down the pipeline.                        //
//                                                                     //
//                                                                     //
/////////////////////////////////////////////////////////////////////////

// `ifndef __IF_STAGE_SV__
// `define __IF_STAGE_SV__

// `include "sys_defs.svh"

// module if_stage (
// 	input             clock,              // system clock
// 	input             reset,              // system reset
// 	input             squash,             // from rob, when to squash
//     input             stall,              // stalls
//     input [`XLEN-1:0] rt_npc,             // from retire stage

// 	input [63:0]      Imem2proc_data,     // Data coming back from instruction-memory
// 	input [1:0]		  proc2Dmem_command,

// 	output logic [`XLEN-1:0] proc2Imem_addr, // Address sent to Instruction memory
// 	output IF_ID_PACKET      if_packet_out   // Output data packet from IF going to ID, see sys_defs for signal information
// );

// 	logic [`XLEN-1:0] PC_reg; // PC we are currently fetching
// 	logic [`XLEN-1:0] PC_plus_4;

// 	// address of the instruction we're fetching (Mem gives us 64 bits, so 3 0s at the end)
// 	assign proc2Imem_addr = {PC_reg[`XLEN-1:3], 3'b0};

// 	// this mux is because the Imem gives us 64 bits not 32 bits
// 	assign if_packet_out.inst = PC_reg[2] ? Imem2proc_data[63:32] : Imem2proc_data[31:0];

// 	assign PC_plus_4 = PC_reg + 4; // default next PC value

// 	assign if_packet_out.PC  = PC_reg;
// 	assign if_packet_out.NPC = PC_plus_4; // Pass PC+4 down pipeline w/instruction
//     //assign if_packet_out.valid = ~stall;

// 	// synopsys sync_set_reset "reset"
// 	always_ff @(posedge clock) begin
// 		if (reset) begin
// 			PC_reg <= `SD 0;                // initial PC value is 0
// 		end else if (squash) begin
// 			PC_reg <= `SD rt_npc; // update to a taken branch
// 		end else if (if_packet_out.valid) begin
// 			PC_reg <= `SD PC_plus_4;        // or transition to next PC if valid
// 		end else begin
// 			PC_reg <= `SD PC_reg;
// 		end
			
// 	end

// 	// This state controls the stall signal that artificially forces fetch
// 	// to stall until the previous instruction has completed
// 	// For project 3, start by setting this to always be 1
// 	// synopsys sync_set_reset "reset"
// 	always_comb begin
// 		if (proc2Dmem_command == BUS_NONE && (!stall))
// 			if_packet_out.valid = 1;
// 		else
// 			if_packet_out.valid = 0;
// 	end

// endmodule // module if_stage
// `endif // __IF_STAGE_SV__

module fetch_stage (
    input                       clock,
    input                       reset,
    input   [31:0]              cache_data,         // <- icache.Icache_data_out
    input                       cache_valid,        // <- Icache_valid_out
    input                       take_branch,        // taken-branch signal
	input   [`XLEN-1:0]         target_pc,          // target pc: use if take_branch is TRUE
    input                       dis_stall,

    // output  logic               hit_but_stall,      // -> icache.hit_but_stall
    // output  logic [1:0]         shift,              // -> icache.shift
    output  [`XLEN-1:0]    proc2Icache_addr,   // -> icache.proc2Icache_addr
    output  IF_ID_PACKET[2:0]   if_packet_out,       // output data from fetch stage to dispatch stage

    //branch predictor
    output                      fetch_EN,
    output        [`XLEN-1:0]   fetch_pc

);

    logic   [`XLEN-1:0]    PC_reg;             // the three PC we are currently fetching
    logic   [`XLEN-1:0]    next_PC;            // the next three PC we are gonna fetch

    // logic   [1:0]               first_hit;
    // logic   [1:0]               first_stall;

	// the next_PC[2] (smallest PC) is:
    //  1. target_PC, if take branch
    //  2. PC_reg[2], if no branch and the current PC_reg[2] is not in the cache
	//  3. PC_reg[1], if no branch and the current PC_reg[1] is not in the cache
    //  4. PC_reg[0], if no branch and the current PC_reg[0] is not in the cache
    //  5. PC_reg[0] + 4 = PC_reg[2] + 12, if no branch and all three PCs are in the cache
	assign next_PC = take_branch     ? target_pc :     // if take_branch, go to the target PC
                        dis_stall   ? PC_reg :                     
                        ~cache_valid ? PC_reg :     // and the third inst
                        PC_reg + 4;

    // assign shift = take_branch     ? 2'd0 :
    //                 dis_stall[2]    ? 2'd0 :
    //                 ~cache_valid[2] ? 2'd0 :
    //                 dis_stall[1]    ? 2'd1 :
    //                 ~cache_valid[1] ? 2'd1 :
    //                 dis_stall[0]    ? 2'd2 :
    //                 ~cache_valid[0] ? 2'd2 :
    //                 2'd0;

    // assign first_hit = cache_valid[2] ? 2'd2 :
    //                    cache_valid[1] ? 2'd1 :
    //                    cache_valid[0] ? 2'd0 :
    //                    2'd3;

    // assign first_stall = dis_stall[2] ? 2'd2 :
    //                      dis_stall[1] ? 2'd1 :
    //                      dis_stall[0] ? 2'd0 :
    //                      2'd3;       

    // assign hit_but_stall = first_hit == 2'd2 && first_stall != 2'd3 && PC_reg[first_hit][`XLEN-1:3] == PC_reg[first_stall][`XLEN-1:3];

    // Pass PC and NPC down pipeline w/instruction
    assign if_packet_out.NPC = PC_reg + 4;
	assign if_packet_out.PC  = PC_reg;

    // Assign the valid bits of output
    assign if_packet_out.valid = cache_valid ? 1'b1 : 1'b0;

    // Assign the inst part of output
    assign if_packet_out.inst  = ~cache_valid[0] ? 32'b0 : cache_data;

    assign proc2Icache_addr = PC_reg;

    // branch predictor
    assign fetch_EN = take_branch ? 0 : if_packet_out.valid;
    assign fetch_pc = if_packet_out.PC;


    // synopsys sync_set_reset "reset"
    always_ff @(posedge clock) begin
        if(reset) begin
			PC_reg <= `SD {`XLEN'd0, `XLEN'd4, `XLEN'd8};       // initial PC value
        end
		else begin
			PC_reg <= `SD next_PC; // transition to next PC
        end
    end

endmodule