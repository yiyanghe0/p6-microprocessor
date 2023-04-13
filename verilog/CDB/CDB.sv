`ifndef CDB_SV
`define CDB_SV

`include "sys_defs.svh"

module CDB(
    input EX_PACKET ex_packet_in,
    input correct_predict,
    input ex_no_output,

    output CDB_PACKET cdb_packet_out
);
    assign cdb_packet_out.reg_tag.tag 	  = ex_packet_in.dest_reg_idx;
    assign cdb_packet_out.reg_tag.valid   = (ex_packet_in.is_ZEROREG || ex_no_output) ? 0 : 1;    // 1 - have write back value, not tag valid bit
    assign cdb_packet_out.no_output       = ex_no_output; 
    assign cdb_packet_out.reg_value       = ex_packet_in.uncond_branch ? ex_packet_in.PC +4 : ex_packet_in.alu_result;   // for jal / jalr
    assign cdb_packet_out.correct_PC      = (ex_packet_in.take_branch) ? ex_packet_in.alu_result : ex_packet_in.PC + 4;
    assign cdb_packet_out.PC              = ex_packet_in.PC;
    assign cdb_packet_out.correct_predict = correct_predict;
    assign cdb_packet_out.take_branch     = ex_packet_in.take_branch;
    assign cdb_packet_out.halt            = ex_packet_in.halt;
    assign cdb_packet_out.illegal         = ex_packet_in.illegal;


endmodule

`endif
