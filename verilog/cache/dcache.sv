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
	input [2:0]		  mem_size, // BYTE = 2'h0, HALF = 2'h1, WORD = 2'h2, DOUBLE = 3'h4
	input 			  clear,  // clear dcache when program is ending

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
	 * 4: miss store not dirty (!hit && command == STORE && !cache.dirty): load correspone data, change dirty to 1, write data in cache
	 * 5: miss load dirty: writeback = 1, command = store, addr = cache_addr, then change dirty to 0 and execute 3
	 * 6: miss store dirty: writeback = 1, command = store, addr = cache_addr, then change dirty to 0 and execute 4
	 */
	logic hit; // found memory address in dcache
	logic writeback; // need to writeback
	logic writeback_finished; // high when writeback is finished
	logic writeback_finished_reg;
	logic st_miss_load;

	logic clear_finished;
	logic clear_all_finished;
	logic [`DCACHE_LINE_BITS-1:0] clear_index;

	// control signals
	assign hit 					 = dcache_data[current_index].valid && (dcache_data[current_index].tags == current_tag); // valid && tag match
	assign writeback 			 = dcache_data[current_index].valid && (dcache_data[current_index].tags != current_tag) && dcache_data[current_index].dirty; // dirty && valid && not hit
	assign writeback_finished 	 = writeback && (Dmem2proc_response != 0); //current in writeback, and received memory response
	assign st_miss_load			 = (!hit && proc2Dcache_command == BUS_STORE && !writeback);

	assign clear_finished 		 = clear && (Dmem2proc_response != 0);


	logic [3:0] current_mem_tag;
	logic miss_outstanding; // whether a miss has received its response tag to wait on

	logic got_mem_data;
	assign got_mem_data = (current_mem_tag == Dmem2proc_tag) && (current_mem_tag != 0);

	logic 		changed_addr;
	logic [1:0] last_command;
	assign changed_addr = (current_index != last_index) || (current_tag != last_tag) || (proc2Dcache_command != last_command);

	logic update_mem_tag;
	assign update_mem_tag = changed_addr || miss_outstanding || got_mem_data;

	logic unanswered_miss; // if we have a new miss or still waiting for the response tag
	assign unanswered_miss = (proc2Dcache_command == BUS_NONE) ? 0 : (changed_addr ? !hit : (miss_outstanding && (Dmem2proc_response == 0) || writeback_finished_reg));

	assign finished = (hit && !clear) || clear_all_finished;


	// case 1
	// data always comes from dcache
	logic [7:0][7:0] loaded_data_byte;
	logic [3:0][15:0] loaded_data_half;
	logic [1:0][31:0] loaded_data_word;
	logic [63:0] loaded_data;

	always_comb begin
		loaded_data_byte = dcache_data[current_index].data;
		loaded_data_half = dcache_data[current_index].data;
		loaded_data_word = dcache_data[current_index].data;
		loaded_data = dcache_data[current_index].data;
		if (proc2Dcache_command == BUS_STORE && (hit || !dcache_data[current_index].valid || !dcache_data[current_index].dirty)) begin
			case(mem_size)
				3'b000: begin
					loaded_data_byte[proc2Dcache_addr[2:0]] = proc2Dcache_data[7:0];
				end
				3'b001: begin
					loaded_data_half[proc2Dcache_addr[2:1]] = proc2Dcache_data[15:0];
				end
				3'b010: begin
					loaded_data_word[proc2Dcache_addr[2]] = proc2Dcache_data[31:0];
				end
				3'b100:
					loaded_data = loaded_data;
			endcase
		end
	end


	assign Dcache_valid_out = hit && (proc2Dcache_command == BUS_LOAD);
	always_comb begin
		Dcache_data_out = loaded_data;

		case(mem_size)
			3'b000: begin
				Dcache_data_out = {{56{loaded_data_byte[proc2Dcache_addr[2:0]][7]}}, loaded_data_byte[proc2Dcache_addr[2:0]]};
			end
			3'b001: begin
				Dcache_data_out = {{48{loaded_data_half[proc2Dcache_addr[2:1]][15]}}, loaded_data_half[proc2Dcache_addr[2:1]]};
			end
			3'b010: begin
				Dcache_data_out = {{32{loaded_data_word[proc2Dcache_addr[2]][31]}}, loaded_data_word[proc2Dcache_addr[2]]};
			end
			3'b100: begin
				Dcache_data_out = {56'b0, loaded_data_byte[proc2Dcache_addr[2:0]]};
			end
			3'b101: begin
				Dcache_data_out = {48'b0, loaded_data_half[proc2Dcache_addr[2:1]]};
			end
		endcase
	end

	// signals to memory
	always_comb begin
		proc2Dmem_command = BUS_NONE;
		proc2Dmem_addr = 0;
		proc2Dmem_data = 0;

		clear_all_finished = 0;
		clear_index = 0;
		if (clear) begin
			for (int i = 0; i < `DCACHE_LINES; i++) begin
				if (dcache_data[i].dirty) begin
					proc2Dmem_command = BUS_STORE;
					proc2Dmem_data = dcache_data[i].data;
					clear_index = i;
					proc2Dmem_addr = {dcache_data[i].tags,clear_index,3'b0};
					break;
				end
                if (i == `DCACHE_LINES - 1)
				    clear_all_finished = 1;
			end
		end
		
		else if (changed_addr || proc2Dcache_command == BUS_NONE || hit) begin // case 0, 1, 2, changed addr
			proc2Dmem_command = BUS_NONE;
			proc2Dmem_addr = 0;
			proc2Dmem_data = 0;
		end
		// not hit
		else if (((!writeback && (proc2Dcache_command == BUS_LOAD)) || st_miss_load) && miss_outstanding) begin // case 3, 4
			proc2Dmem_command = BUS_LOAD;
			proc2Dmem_addr = {proc2Dcache_addr[31:3],3'b0};
			proc2Dmem_data = 0;
		end
		else if (writeback  && miss_outstanding) begin // case 5, 6
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
			last_command     <= `SD 0;
		end else begin
			last_index       <= `SD current_index;
			last_tag         <= `SD current_tag;
			miss_outstanding <= `SD unanswered_miss;
			last_command     <= `SD proc2Dcache_command;


			if (update_mem_tag) begin
				current_mem_tag <= `SD Dmem2proc_response;
			end
			if (got_mem_data) begin // If data came from memory, meaning tag matches
				dcache_data[current_index].data   <= `SD Dmem2proc_data;
				dcache_data[current_index].tags   <= `SD current_tag;
				dcache_data[current_index].valid  <= `SD 1;
				dcache_data[current_index].dirty  <= `SD 0;
			end

			if (proc2Dcache_command == BUS_STORE && hit) begin
				case(mem_size)
					3'b000:
						dcache_data[current_index].data <= `SD loaded_data_byte;
					3'b001: 
						dcache_data[current_index].data <= `SD loaded_data_half;
					3'b010: 
						dcache_data[current_index].data <= `SD loaded_data_word;
					3'b100:
						dcache_data[current_index].data <= `SD proc2Dcache_data;
				endcase
				// dcache_data[current_index].tags   <= `SD current_tag;
				dcache_data[current_index].dirty  <= `SD 1;
				// dcache_data[current_index].valid  <= `SD 1;
				// finished <= `SD 1;
			end
			
			if (writeback_finished) begin
				dcache_data[current_index].dirty  <= `SD 0;
				writeback_finished_reg <= `SD 1;
			end
			else begin
				writeback_finished_reg <= `SD 0;
			end

			if (clear_finished) begin
				dcache_data[clear_index].dirty  <= `SD 0;
			end
		end
	end

endmodule
