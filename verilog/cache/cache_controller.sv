`ifndef __CACHE_CONTROLLER_SV__
`define __CACHE_CONTROLLER_SV__

`include "sys_defs.svh"


module cache_controller(
    input clock, reset,
    // from memory
	input [3:0]  mem2proc_response, // this should be zero unless we got a response
	input [63:0] mem2proc_data,
	input [3:0]  mem2proc_tag,

    // to memory
	output logic [1:0]       proc2mem_command,
	output logic [`XLEN-1:0] proc2mem_addr,
    output logic [63:0]      proc2Dmem_data,

    // from Icache
    input  [1:0]       Icache2ctrl_command,
	input  [`XLEN-1:0] Icache2ctrl_addr,

    // to Icache
	output logic [3:0]  ctrl2Icache_response,
	output logic [63:0] ctrl2Icache_data,
	output logic [3:0]  ctrl2Icache_tag,

    // from Dcache
    input  [1:0]       Dcache2ctrl_command,
	input  [`XLEN-1:0] Dcache2ctrl_addr,
    input  [63:0]      Dcache2ctrl_data,

    // to Dcache
    output logic [3:0]  ctrl2Dcache_response,
	output logic [63:0] ctrl2Dcache_data,
	output logic [3:0]  ctrl2Dcache_tag
);

    logic d_request;
    logic last_d_request;
    assign d_request = (Dcache2ctrl_command != BUS_NONE);

    always_comb begin
        ctrl2Dcache_data = mem2proc_data;
        ctrl2Dcache_tag = mem2proc_tag;
        
        ctrl2Icache_data = mem2proc_data;
        ctrl2Icache_tag = mem2proc_tag;

        if (d_request) begin // assign memory output to Dcache, and clear Icache output
            proc2mem_command = Dcache2ctrl_command;
            proc2mem_addr = Dcache2ctrl_addr;
            proc2Dmem_data = Dcache2ctrl_data;
        end
        else begin
            proc2mem_command = Icache2ctrl_command;
            proc2mem_addr = Icache2ctrl_addr;
            proc2Dmem_data = 0;
        end

        if (last_d_request || d_request) begin
            ctrl2Icache_response = 0;
            ctrl2Dcache_response = mem2proc_response;
        end else begin
            ctrl2Icache_response = mem2proc_response;
            ctrl2Dcache_response = 0;
        end
    end

    always_ff @(posedge clock) begin
        if (reset) last_d_request <= `SD 0;
        else last_d_request <= `SD d_request;
    end




endmodule



`endif // __CACHE_CONTROLLER_SV__