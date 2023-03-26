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
	input CDB_PACKET  cdb_packet_in,

	output RT_PACKET rt_packet_out
);

	
	assign rt_packet_out.NPC = cdb_packet_in.NPC;
	assign rt_packet_out.reg_value = cdb_packet_in.reg_value;
	assign rt_packet_out.reg_tag = cdb_packet_in.reg_tag;
	assign rt_packet_out.take_branch = cdb_packet_in.NPC;

endmodule // module wb_stage
`endif // __WB_STAGE_SV__
