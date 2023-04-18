//////////////////////////////////////////////////////////////////////////
//                                                                      //
//   Modulename :  prefetch.sv                                          //
//                                                                      //
//  Description :  the instruction cache module that reroutes memory    //
//                 accesses to decrease misses                          //
//                                                                      //
//////////////////////////////////////////////////////////////////////////

`ifndef __PREFETCH_SV__
`define __PREFETCH_SV__

`include "sys_defs.svh"



module prefetch (
	input clock,
	input reset,

	// from memory
	input [3:0]  Imem2proc_response, // passed through from icache
	input [63:0] Imem2proc_data,
	input [3:0]  Imem2proc_tag,

	// from icache
	input [`XLEN-1:0] NPC,
    input enable, // high when prefetch enabled from icache
    input changed_addr, // should be (change_addr && miss) from icache
                       // when change_addr, clear all bits in prefetcher

	// to memory
	output logic [1:0]       proc2Imem_command,
	output logic [`XLEN-1:0] proc2Imem_addr,

	`ifdef TEST_MODE
        output PREFETCH_PACKET [`PREFETCH_LINES-1:0] show_prefetch_data,
	`endif	

	// to icache
    output logic [`XLEN-1:0] prefetch_icache_addr,
	output logic             prefetch_valid_out // when this is high
);

	PREFETCH_PACKET [`PREFETCH_LINES-1:0] prefetch_data;

	`ifdef TEST_MODE
		assign show_prefetch_data = prefetch_data;
	`endif	

    // from memory
    // needs to && enable
    logic update_mem_tag;
    always_comb begin
        update_mem_tag = 0;
        if (enable) begin
            for (int i = 0; i < `PREFETCH_LINES; i++) begin
                if (!prefetch_data[i].response_received)
                    update_mem_tag = 1;
            end
            if (changed_addr) update_mem_tag = 1;
        end
    end

    // to memory
    // gives out first prefetch_line addr if the prefetch_line has miss_outstanding (!response_received)
    // does not need to && enable since icache will also do this
    always_comb begin
        proc2Imem_command = BUS_NONE;
		proc2Imem_addr = 0;
        if (enable) begin
            for (int i = 0; i < `PREFETCH_LINES; i++) begin
                if (!prefetch_data[i].response_received) begin
                    proc2Imem_command = BUS_LOAD;
                    proc2Imem_addr = prefetch_data[i].addr;
                    break;
                end
            end
        end
    end

    // to icache

    always_comb begin
        prefetch_valid_out = 0;
        prefetch_icache_addr = 0;
        for (int i = 0; i < `PREFETCH_LINES; i++) begin
            if ((prefetch_data[i].mem_tag == Imem2proc_tag) && (prefetch_data[i].mem_tag != 0)) begin // this is corresponding line
                prefetch_valid_out = 1;
                prefetch_icache_addr = prefetch_data[i].addr;
                break;
            end
        end
    end



    // synopsys sync_set_reset "reset"
	always_ff @(posedge clock) begin
		if (reset) begin
			prefetch_data <= `SD 0;
		end 
        // from icache
        else if (changed_addr) begin // initialize addr when changed addr
            for (int i = 0; i < `DCACHE_LINES; i++) begin
                prefetch_data[i].addr <= `SD NPC + 8 * i;
                prefetch_data[i].mem_tag <= `SD 0;
                prefetch_data[i].response_received <= `SD 0;
            end
        end 
        else begin
			if (update_mem_tag && Imem2proc_response != 0) begin
				for (int i = 0; i < `DCACHE_LINES; i++) begin
                    if (!prefetch_data[i].response_received) begin
                        prefetch_data[i].response_received <= `SD 1;
                        prefetch_data[i].mem_tag <= `SD Imem2proc_response;
                        break;
                    end
                end
			end
		end
	end


endmodule // module prefetch

`endif // __PREFETCH_SV__
