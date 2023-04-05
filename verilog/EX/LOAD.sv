`ifndef __LOAD_SV__
`define __LOAD_SV__

`include "sys_defs.svh"

module LOAD (
    //input
    input                       clock,  // system clock
    input                       reset,  // system reset
    input [`XLEN-1:0]           opa,
    input [`XLEN-1:0]           opb,
    input IS_PACKET             is_packet_in,
    input                       start,
    input [`XLEN-1:0]           Dmem2proc_data,
    input [3:0]                 mem2proc_response,
    input [3:0]                 mem2proc_tag,

    //outout
    output logic [1:0]          proc2Dmem_command,
    output MEM_SIZE             proc2Dmem_size,
    output logic [`XLEN-1:0]    proc2Dmem_addr, // Address sent to data-memory

    output logic [`XLEN-1:0]    mem_result_out, //the result from the mem
    output IS_PACKET            is_packet_out,
    output logic                busy,
    output logic                done   
);

IS_PACKET is_packet;
IS_PACKET next_is_packet;

assign proc2Dmem_command  = (is_packet_in.rd_mem) ? BUS_LOAD : BUS_NONE;

assign proc2Dmem_addr    = opa + opb;

assign 

always_comb begin
    next_is_packet = '{{`XLEN{1'b0}},
		{`XLEN{1'b0}},
		{`XLEN{1'b0}},
		{`XLEN{1'b0}},
		OPA_IS_RS1,
		OPB_IS_RS2,
		`NOP,
		1'b0,
		ALU_ADD,
		1'b0, // rd_mem
		1'b0, // wr_mem
		1'b0, // cond
		1'b0, // uncond
		1'b0, // halt
		1'b0, // illegal
		1'b0, // csr_op
		1'b0, // valid
		1'b1,
		ALU
		}; // or a nop instruction
    if (start)
        next_is_packet = is_packet_in;
    else if (busy) 
        next_is_packet = is_packet;
end




always_comb begin
		mem_result_out = opa + opb;
		if (is_packet_in.rd_mem) begin
			if (~is_packet_in.mem_size[2]) begin //is this an signed/unsigned load?
				if (is_packet_in.mem_size[1:0] == 2'b0)
					mem_result_out = {{(`XLEN-8){Dmem2proc_data[7]}}, Dmem2proc_data[7:0]};
				else if (is_packet_in.mem_size[1:0] == 2'b01)
					mem_result_out = {{(`XLEN-16){Dmem2proc_data[15]}}, Dmem2proc_data[15:0]};
				else mem_result_out = Dmem2proc_data;
			end else begin
				if (is_packet_in.mem_size[1:0] == 2'b0)
					mem_result_out = {{(`XLEN-8){1'b0}}, Dmem2proc_data[7:0]};
				else if (is_packet_in.mem_size[1:0] == 2'b01)
					mem_result_out = {{(`XLEN-16){1'b0}}, Dmem2proc_data[15:0]};
				else mem_result_out = Dmem2proc_data;
			end
		end
	end

endmodule
`endif