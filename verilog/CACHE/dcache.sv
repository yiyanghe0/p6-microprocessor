`define TEST_MODE
`include "sys_defs.svh"


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
	input [1:0]		  mem_size, // BYTE = 2'h0, HALF = 2'h1, WORD = 2'h2, DOUBLE = 2'h3

	// to memory
	output logic [1:0]       proc2Dmem_command,
	output logic [`XLEN-1:0] proc2Dmem_addr,
    output logic [63:0]      proc2Dmem_data,

	`ifdef TEST_MODE
		output DCACHE_PACKET [`DCACHE_LINES-1:0] show_dcache_data,
	`endif 

	// to ex stage
	output logic [63:0] Dcache_data_out, // value is memory[proc2Dcache_addr]
	output logic        Dcache_valid_out, // when this is high
	output logic 		finished		// finished current instruction


);

    DCACHE_PACKET [`DCACHE_LINES-1:0] dcache_data;
	`ifdef TEST_MODE
		assign show_dcache_data = dcache_data;
	`endif 

    // note: cache tags, not memory tags
	logic [`DCACHE_LINE_BITS - 1:0] current_index, last_index;
	logic [12-`DCACHE_LINE_BITS:0]  current_tag, last_tag;
	assign {current_tag, current_index} = proc2Dcache_addr[15:3];

	// case tags
	/* 6 cases:
	 * 0: BUS_NONE: do nothing
	 * 1: hit load (hit && command == LOAD): directly return data
	 * 2: hit store (hit && command == STORE): change dirty to 1, write data in cache
	 * 3: miss load not dirty (!hit && command == LOAD && !cache.dirty): assign command = load, addr = addr_in
	 * 4: miss store not dirty (!hit && command == STORE && !cache.dirty): change dirty to 1, write data in cache
	 * 5: miss load dirty: writeback = 1, command = store, addr = cache_addr, then change dirty to 0 and execute 3
	 * 6: miss store dirty: writeback = 1, command = store, addr = cache_addr, then change dirty to 0 and execute 4
	 */
	logic hit; // found memory address in dcache
	logic writeback; // need to writeback
	logic writeback_finished; // high when writeback is finished

	// control signals
	assign hit 					= dcache_data[current_index].valid && (dcache_data[current_index].tags == current_tag); // valid && tag match
	assign writeback 			= dcache_data[current_index].valid && (dcache_data[current_index].tags != current_tag) && dcache_data[current_index].dirty; // dirty && valid && not hit
	assign writeback_finished 	= writeback && (Dmem2proc_response != 0); //current in writeback, and received memory response


	logic [3:0] current_mem_tag;
	logic miss_outstanding; // whether a miss has received its response tag to wait on

	logic got_mem_data;
	assign got_mem_data = (current_mem_tag == Dmem2proc_tag) && (current_mem_tag != 0);

	logic changed_addr;
	assign changed_addr = (current_index != last_index) || (current_tag != last_tag);

	logic update_mem_tag;
	assign update_mem_tag = changed_addr || miss_outstanding || got_mem_data;

	logic unanswered_miss; // if we have a new miss or still waiting for the response tag
	assign unanswered_miss = (proc2Dcache_command == BUS_NONE) ? 0 : (changed_addr ? (!(hit || (proc2Dcache_command == BUS_STORE && !dcache_data[current_index].dirty)))
	                            													: miss_outstanding && (Dmem2proc_response == 0));

	assign finished = hit;


	// case 1
	// data always comes from dcache
	logic [63:0] loaded_data;
	assign loaded_data = dcache_data[current_index].data; // !!! change according to mem_size
	assign Dcache_valid_out = hit && (proc2Dcache_command == BUS_LOAD);
	always_comb begin
		Dcache_data_out = loaded_data;
		case(mem_size)
			2'b00: begin
				Dcache_data_out = {56'b0, loaded_data[proc2Dcache_addr[2:0]]};
			end
			2'b01: begin
				Dcache_data_out = {48'b0, loaded_data[proc2Dcache_addr[2:1]]};
			end
			2'b10: begin
				Dcache_data_out = {32'b0, loaded_data[proc2Dcache_addr[2]]};
			end
			2'b11:
				Dcache_data_out = loaded_data;
		endcase
	end

	// signals to memory
	always_comb begin
		proc2Dmem_command = BUS_NONE;
		proc2Dmem_addr = 0;
		proc2Dmem_data = 0;
		
		if (changed_addr || proc2Dcache_command == BUS_NONE || hit || (proc2Dcache_command == BUS_STORE && !dcache_data[current_index].dirty)) begin // case 0, 1, 2, 4, changed addr
			proc2Dmem_command = BUS_NONE;
			proc2Dmem_addr = 0;
			proc2Dmem_data = 0;
		end
		// not hit
		else if (!writeback && (proc2Dcache_command == BUS_LOAD)) begin // case 3
			proc2Dmem_command = BUS_LOAD;
			proc2Dmem_addr = {proc2Dcache_addr[31:3],3'b0};
			proc2Dmem_data = 0;
		end
		else if (writeback) begin // case 5, 6
			proc2Dmem_command = BUS_STORE;
			proc2Dmem_addr = {dcache_data[current_index].tags,current_index,3'b0};
			proc2Dmem_data = dcache_data[current_index].data;
		end

	end

	// synopsys sync_set_reset "reset"
	always_ff @(posedge clock) begin
		if (reset) begin
			last_index       <= `SD -1; // These are -1 to get ball rolling when
			last_tag         <= `SD -1; // reset goes low because addr "changes"
			current_mem_tag  <= `SD 0;
			miss_outstanding <= `SD 0;
			dcache_data      <= `SD 0; // set all cache data to 0 (including valid bits)
		end else begin
			last_index       <= `SD current_index;
			last_tag         <= `SD current_tag;
			miss_outstanding <= `SD unanswered_miss;

			if (update_mem_tag) begin
				current_mem_tag <= `SD Dmem2proc_response;
			end
			if (got_mem_data) begin // If data came from memory, meaning tag matches
				dcache_data[current_index].data   <= `SD Dmem2proc_data;
				dcache_data[current_index].tags   <= `SD current_tag;
				dcache_data[current_index].valid  <= `SD 1;
				dcache_data[current_index].dirty  <= `SD 0;
			end

			if (proc2Dcache_command == BUS_STORE && (hit || !dcache_data[current_index].valid)) begin
				$display();
				case(mem_size)
					2'b00:
						dcache_data[current_index].data[proc2Dcache_addr[2:0]] <= `SD proc2Dcache_data[7:0];
					2'b01: 
						dcache_data[current_index].data[proc2Dcache_addr[2:1]] <= `SD proc2Dcache_data[15:0];
					2'b10: 
						dcache_data[current_index].data[proc2Dcache_addr[2]] <= `SD proc2Dcache_data[31:0];
					2'b11:
						dcache_data[current_index].data <= `SD proc2Dcache_data;
				endcase
				// dcache_data[current_index].data   <= `SD proc2Dcache_data;
				dcache_data[current_index].dirty  <= `SD 1;
				dcache_data[current_index].valid  <= `SD 1;
				// finished <= `SD 1;
			end
			
			if (writeback_finished) begin
				dcache_data[current_index].dirty  <= `SD 0;
			end
		end
	end

endmodule