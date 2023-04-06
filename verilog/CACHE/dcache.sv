`define TEST_MODE

`timescale 1ns/100ps

// internal macros, no other file should need these
`define DCACHE_LINES 32
`define DCACHE_LINE_BITS $clog2(`DCACHE_LINES)

typedef struct packed {
	logic [63:0]                  data;
	// 12:0 (13 bits) since only 16 bits of address exist in mem - and 3 are the block offset
	logic [12-`CACHE_LINE_BITS:0] tags;
	logic                         valid;
    logic                         dirty;
} DCACHE_PACKET;

module dcache(
    input clock,
    input reset,
    // from memory
	input [3:0]  Dmem2proc_response, // this should be zero unless we got a response
	input [63:0] Dmem2proc_data,
	input [3:0]  Dmem2proc_tag,

	// from ex stage
	input [`XLEN-1:0] proc2Dcache_addr,
    input [63:0]      proc2Dcache_data,
    input [1:0]       proc2Dcache_command, // 0: None, 1: Load, 2: Store

	// to memory
	output logic [1:0]       proc2Dmem_command,
	output logic [`XLEN-1:0] proc2Dmem_addr,
    output logic [63:0]      proc2Dmem_data,

	// to ex stage
	output logic [63:0] Dcache_data_out, // value is memory[proc2Dcache_addr]
	output logic        Dcache_valid_out, // when this is high
	output logic 		finished		// finished current instruction
);

    DCACHE_PACKET [`DCACHE_LINES-1:0] dcache_data;


    // note: cache tags, not memory tags
	logic [`DCACHE_LINE_BITS - 1:0] current_index, last_index;
	logic [12-`DCACHE_LINE_BITS:0]  current_tag, last_tag;
	logic hit;
	logic store_nwrite; // store and not needing to write back
	logic store_finished;

	assign {current_tag, current_index} = proc2Dcache_addr[15:3];

	// hit & load
	assign hit = dcache_data[current_index].valid && (dcache_data[current_index].tags == current_tag);
	assign Dcache_data_out = dcache_data[current_index].data;
	assign Dcache_valid_out = hit && (proc2Dcache_command == BUS_LOAD);

	// store command without needing to write back, 
	// Including hit store, and miss store with dirty == 0 (including not valid)
	assign store_nwrite = ((hit || !dcache_data[current_index].dirty || !dcache_data[current_index].valid) && proc2Dcache_command == BUS_STORE);
	
	// miss
	// keep sending memory requests until we receive a response tag or change addresses
	// command = dealing with previous command -> keep working on it / stop sending memory request
	//			 previous command -> response tag because dcache has priority over icache
	assign unanswered_miss = (proc2Dcache_command == BUS_NONE) ? 0 
									the current memory tag we might be waiting on
	logic miss_outstanding; // whether a miss has received its response tag to wait on

	logic got_mem_data;
	assign got_mem_data = (current_mem_tag == Dmem2proc_tag) && (current_mem_tag != 0);

	logic changed_addr;
	assign changed_addr = (current_index != last_index) || (current_tag != last_tag);

	// should set to zero if we changed_addr, but will keep resetting while we have a miss_outstanding
	// and will set to zero when we got_mem_data
	// (this is since Imem2proc_response should be zero if no request)
	logic update_mem_tag;
	assign update_mem_tag = changed_addr || miss_outstanding || got_mem_data;

	logic unanswered_miss; // if we have a new miss or still waiting for the response tag
	// we might need to wait for the response tag because dcache has priority over icache
	assign unanswered_miss = (proc2Dcache_command == BUS_NONE) ? 0 
																: changed_addr ? (!Dcache_valid_out && !store_nwrite)
	                            												: miss_outstanding && (Dmem2proc_response == 0);

	assign finished = (store_nwrite || got_mem_data);

    // synopsys sync_set_reset "reset"
	always_ff @(posedge clock) begin
		if (reset) begin
			last_index       <= `SD -1; // These are -1 to get ball rolling when
			last_tag         <= `SD -1; // reset goes low because addr "changes"
			current_mem_tag  <= `SD 0;
			miss_outstanding <= `SD 0;
			dcache_data      <= `SD 0; // set all cache data to 0 (including valid bits)
			store_finished   <= `SD 0;
		end else begin
			last_index       <= `SD current_index;
			last_tag         <= `SD current_tag;
			miss_outstanding <= `SD unanswered_miss;
			store_finished	 <= `SD 0;
			if (update_mem_tag) begin
				current_mem_tag <= `SD Dmem2proc_response;
			end
			if (got_mem_data) begin // If data came from memory, meaning tag matches
				dcache_data[current_index].data   <= `SD Dmem2proc_data;
				dcache_data[current_index].tags   <= `SD current_tag;
				dcache_data[current_index].valid  <= `SD 1;
				dcache_data[current_index].dirty  <= `SD 0;
			end
			if (store_nwrite) begin
				dcache_data[current_index].data   <= `SD proc2Dmem_data;
				dcache_data[current_index].dirty  <= `SD 1;
				store_finished					  <= `SD 1;
			end
			if (!hit && dcache[current_index].dirty && Dmem2proc_response != 0) begin //Finished writing back
				dcache[current_index].dirty 	  <= `SD 0;
				if (proc2Dcache_command == BUS_STORE)
					dcache[current_index].tags	  <= `SD current_tag; //If it is a store command, do not request from memory
			end
		end
	end

endmodule