/////////////////////////////////////////////////////////////////////////
//                                                                     //
//   Modulename :  regfile.v                                           //
//                                                                     //
//  Description :  This module creates the Regfile used by the ID and  //
//                 WB Stages of the Pipeline.                          //
//                                                                     //
/////////////////////////////////////////////////////////////////////////

`ifndef __REGFILE_SV__
`define __REGFILE_SV__

`include "sys_defs.svh"

module regfile (
	input [4:0]       rda_idx, rdb_idx, wr_idx, // read/write index
	input [`XLEN-1:0] wr_data,                  // write data
	input             wr_en, wr_clk,

	output logic [`XLEN-1:0] rda_out, rdb_out   // read data
);

	logic [31:0] [`XLEN-1:0] registers; // 32, 64-bit Registers

	wire [`XLEN-1:0] rda_reg = registers[rda_idx];
	wire [`XLEN-1:0] rdb_reg = registers[rdb_idx];

	// Read port A
	always_comb begin
		if (rda_idx == `ZERO_REG)
			rda_out = 0;
		else if (wr_en && (wr_idx == rda_idx))
			rda_out = wr_data;  // internal forwarding
		else
			rda_out = rda_reg;
	end

	// Read port B
	always_comb begin
		if (rdb_idx == `ZERO_REG)
			rdb_out = 0;
		else if (wr_en && (wr_idx == rdb_idx))
			rdb_out = wr_data;  // internal forwarding
		else
		  rdb_out = rdb_reg;
	end

	// Write port
	always_ff @(posedge wr_clk) begin
			if (wr_en) begin
				registers[wr_idx] <= `SD wr_data;
		end
	end

endmodule // regfile
`endif //__REGFILE_SV__
