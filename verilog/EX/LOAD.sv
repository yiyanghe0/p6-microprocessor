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
    input [`XLEN-1:0]           Dcache2proc_data, //could be wrong length
	input 						finish,

    //outout
    output logic [1:0]          proc2Dcache_command,
    output MEM_SIZE             proc2Dcache_size,
    output logic [`XLEN-1:0]    proc2Dcache_addr, // Address sent to data-memory

    output logic [`XLEN-1:0]    Dcache_result_out, //the result from the mem
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

assign proc2Dcache_command 	= command;
assign proc2Dcache_addr  	= addr;

//assign proc2Dcache_command  = (is_packet_out.rd_mem) ? BUS_LOAD : BUS_NONE;
//sign proc2Dcache_addr     = opa + opb;

assign done = finish & (busy | start);

//if Dcache hits, pass through the is_packet_in
always_comb begin
	if (start) begin
		is_packet_out 		= is_packet_in;
		proc2Dcache_command = (is_packet_in.rd_mem) ? BUS_LOAD : BUS_NONE;
		proc2Dcache_addr	= opa + opb;
	end
	else begin
		is_packet_out 		= is_packet;
		proc2Dcache_command = command;
		proc2Dcache_addr	= addr;
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
		ALU
		}; // or a nop instruction
	next_command	   = BUS_NONE;
	next_addr		   = 0;
    if (start) begin
        next_is_packet = is_packet_in;
		next_command   = (is_packet_in.rd_mem) ? BUS_LOAD : BUS_NONE;
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
			ALU
		}; // or a nop instruction
	end
	else begin
		busy 		<= `SD next_busy;
		is_packet	<= `SD next_is_packet;
		command 	<= `SD next_command;
		addr 		<= `SD next_addr;
	end
end

always_comb begin
	Dcache_result_out = 0;
	if (done) begin
		if (~is_packet_out.mem_size[2]) begin //is this an signed/unsigned load?
			if (is_packet_out.mem_size[1:0] == 2'b0)
				Dcache_result_out = {{(`XLEN-8){Dcache2proc_data[7]}}, Dcache2proc_data[7:0]};
			else if (is_packet_out.mem_size[1:0] == 2'b01)
				Dcache_result_out = {{(`XLEN-16){Dcache2proc_data[15]}}, Dcache2proc_data[15:0]};
			else Dcache_result_out = Dcache2proc_data;
		end else begin
			if (is_packet_out.mem_size[1:0] == 2'b0)
				Dcache_result_out = {{(`XLEN-8){1'b0}}, Dcache2proc_data[7:0]};
			else if (is_packet_out.mem_size[1:0] == 2'b01)
				Dcache_result_out = {{(`XLEN-16){1'b0}}, Dcache2proc_data[15:0]};
			else Dcache_result_out = Dcache2proc_data;
		end
	end
end

endmodule
`endif