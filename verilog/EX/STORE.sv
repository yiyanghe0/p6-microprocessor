`ifndef __STORE_SV__
`define __STORE_SV__

`include "sys_defs.svh"

module STORE (
    //input
    input               clock,
    input               reset,
    input IS_PACKET     is_packet_in,  // write memory? (from decoder)
    input [`XLEN-1:0]   Dmem2proc_data,
    input [`XLEN-1:0]   opa,
    input [`XLEN-1:0]   opb,

    //output
    output logic [1:0] proc2Dmem_command,
    // output MEM_SIZE proc2Dmem_size,
	output logic [`XLEN-1:0] proc2Dmem_addr, // Address sent to data-memory
	output logic [`XLEN-1:0] proc2Dmem_data  // Data sent to data-memory
);

//!!!
assign proc2Dmem_command =
		(is_packet_in.wr_mem & is_packet_in.valid) ? BUS_STORE :
		(is_packet_in.rd_mem & is_packet_in.valid) ? BUS_LOAD :
		BUS_NONE;

// only the 2 LSB to determine the size;
//assign proc2Dmem_size = MEM_SIZE'(ex_mem_packet_in.mem_size[1:0]);
// assign proc2Dmem_size = MEM_SIZE'(is_packet_in.inst.r.funct3[1:0]);

// The memory address is calculated by the ALU
//data
assign proc2Dmem_data = is_packet_in.rs2_value;
//address
assign proc2Dmem_addr = opa + opb;

endmodule
`endif