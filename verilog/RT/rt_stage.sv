/////////////////////////////////////////////////////////////////////////
//                                                                     //
//   Modulename :  rt_stage.v                                          //
//                                                                     //
//  Description :  generate squash signal                              //
//                                                                     //
//                                                                     //
/////////////////////////////////////////////////////////////////////////

`ifndef __RT_STAGE_SV__
`define __RT_STAGE_SV__

`include "sys_defs.svh"

module rt_stage (
	input clock,
	input reset,
	input CDB_PACKET cdb_packet_in,

	output logic [`XLEN-1:0] rt_npc_out
);
	logic [`XLEN-1:0] next_rt_npc;
	logic mispredict; // 1 - mispredict

	assign mispredict = !cdb_packet_in.correct_predict;
	
	assign next_rt_npc = (mispredict) ? cdb_packet_in.correct_PC : rt_npc_out;

	// synopsys sync_set_reset "reset"
	always_ff @(posedge clock) begin
		if (reset)
			rt_npc_out <= `SD 0;
		else
			rt_npc_out <= `SD next_rt_npc;
	end

endmodule // module wb_stage
`endif // __WB_STAGE_SV__
