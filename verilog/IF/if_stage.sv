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

`ifndef __IF_STAGE_SV__
`define __IF_STAGE_SV__

`include "sys_defs.svh"

module if_stage (
	input             clock,              // system clock
	input             reset,              // system reset
	input             squash,             // from rob, when to squash
    input             stall,              // stalls
    input [`XLEN-1:0] rt_npc,             // from retire stage

	input [63:0]      Imem2proc_data,     // Data coming back from instruction-memory
	input [1:0]		  proc2Dmem_command,

	output logic [`XLEN-1:0] proc2Imem_addr, // Address sent to Instruction memory
	output IF_ID_PACKET      if_packet_out   // Output data packet from IF going to ID, see sys_defs for signal information
);

	logic [`XLEN-1:0] PC_reg; // PC we are currently fetching
	logic [`XLEN-1:0] PC_plus_4;

	// address of the instruction we're fetching (Mem gives us 64 bits, so 3 0s at the end)
	assign proc2Imem_addr = {PC_reg[`XLEN-1:3], 3'b0};

	// this mux is because the Imem gives us 64 bits not 32 bits
	assign if_packet_out.inst = PC_reg[2] ? Imem2proc_data[63:32] : Imem2proc_data[31:0];

	assign PC_plus_4 = PC_reg + 4; // default next PC value

	assign if_packet_out.PC  = PC_reg;
	assign if_packet_out.NPC = PC_plus_4; // Pass PC+4 down pipeline w/instruction
    //assign if_packet_out.valid = ~stall;

	// synopsys sync_set_reset "reset"
	always_ff @(posedge clock) begin
		if (reset) begin
			PC_reg <= `SD 0;                // initial PC value is 0
		end else if (squash) begin
			PC_reg <= `SD rt_npc; // update to a taken branch
		end else if (if_packet_out.valid) begin
			PC_reg <= `SD PC_plus_4;        // or transition to next PC if valid
		end else begin
			PC_reg <= `SD PC_reg;
		end
			
	end

	// This state controls the stall signal that artificially forces fetch
	// to stall until the previous instruction has completed
	// For project 3, start by setting this to always be 1
	// synopsys sync_set_reset "reset"
	always_comb begin
		if (proc2Dmem_command == BUS_NONE && (!stall))
			if_packet_out.valid = 1;
		else
			if_packet_out.valid = 0;
	end

endmodule // module if_stage
`endif // __IF_STAGE_SV__
