`ifdef CDB_SV
`define CDB_SV

`include "sys_defs.svh"

module CDB(
    input EX_PACKET ex_packet_in,
    output CDB_PACKET cdb_packet_out
);
    assign cdb_packet_out.reg_tag.tag 	= ex_packet_in.dest_reg_idx;
    assign cdb_packet_out.reg_tag.valid = (ex_packet_in.is_ZEROREG) ? 0 : 1;
    assign cdb_packet_out.reg_value     = ex_packet_in.alu_result;
    assign cdb_packet_out.NPC 		    = ex_packet_in.NPC;
    assign cdb_packet_out.take_branch   = ex_packet_in.take_branch;
endmodule

`endif
