`ifdef CDB_SV
`define CDB_SV

`include "sys_defs.svh"

module CDB(
    input EX_
    input logic [`REG_LEN-1:0] mem_wb_dest_reg_idx,
    input logic [`XLEN-1:0] mem_wb_result_in,
    input valid,
    output CDB_PACKET cdb_packet_out
);
    assign cdb_packet_out.reg_tag.tag = mem_wb_dest_reg_idx;
    assign cdb_packet_out.reg_tag.valid = valid;
    assign cdb_packet_out.reg_value = mem_wb_result_in;
endmodule

`endif