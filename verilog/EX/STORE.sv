`ifndef __STORE_SV__
`define __STORE_SV__

`include "sys_defs.svh"

module STORE (
    //input
    input                       clock,  // system clock
    input                       reset,  // system reset
    input [`XLEN-1:0]           opa,
    input [`XLEN-1:0]           opb,
    input IS_PACKET             is_packet_in,
    input                       start,
    input                       finish,

    input                       rob_start,

    //outout
    output logic [1:0]          proc2Dcache_command,
    output logic [`XLEN-1:0]    proc2Dcache_addr, // Address sent to data-memory
    output logic [63:0]         proc2Dcache_data,
    output logic [2:0]          store_mem_size,
    output IS_PACKET            is_packet_out,
    output logic                busy,
    output logic                done            
);

//internal logic
IS_PACKET 				is_packet;
IS_PACKET 				next_is_packet;

logic [1:0]				command;
logic [1:0]				next_command;

logic [`XLEN-1:0]   	addr;
logic [`XLEN-1:0]    	next_addr;


logic 					next_busy;


//address

assign done = finish && (start || busy);

//if Dcache hits, pass through the is_packet_in
always_comb begin
	//proc2Dcache_command = command;
	if (start) begin
		is_packet_out 		= is_packet_in;
		proc2Dcache_command = (is_packet_in.wr_mem && rob_start) ? BUS_STORE : BUS_NONE;
		proc2Dcache_addr	= opa + opb;
        proc2Dcache_data    = is_packet_in.rs2_value;
        store_mem_size      = is_packet_in.mem_size;
	end
	else begin
		is_packet_out 		= is_packet;
		proc2Dcache_command = rob_start ? command : BUS_NONE;
		proc2Dcache_addr	= addr;
        proc2Dcache_data    = is_packet.rs2_value;
        store_mem_size      = is_packet.mem_size;
	end
end

//always_ff for the is_packet
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
		ALU,
		3'b111  // mem_size
		}; // or a nop instruction
	next_command	   = BUS_NONE;
	next_addr		   = 0;
    if (start) begin
        next_is_packet = is_packet_in;
		next_command   = (is_packet_in.wr_mem) ? BUS_STORE : BUS_NONE;
		next_addr	   = opa + opb;
	end
    else if (busy) begin
        next_is_packet = is_packet;
		next_command   = command;
		next_addr      = addr;
	end
end

//busy bit
always_comb begin 
	if (start)
		next_busy = 1;
	else if (done)
		next_busy = 0;
	else 
		next_busy = busy;
end

//the always_ff bolock for is_packet
always_ff @(posedge clock) begin
	if (reset) begin
		busy <= `SD 0;
		is_packet <= `SD '{{`XLEN{1'b0}},
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
			ALU,
			3'b111
		}; // or a nop instruction
        command <= `SD BUS_NONE;
        addr    <= `SD 0;
	end
	else begin
		busy 		<= `SD next_busy;
		is_packet	<= `SD next_is_packet;
		command 	<= `SD next_command;
		addr 		<= `SD next_addr;
	end
end


endmodule
`endif