`ifndef __FIFO_SV__
`define __FIFO_SV__

`define FIFO_LEN 8

`include "sys_defs.svh"

module FIFO(
    input EX_PACKET ex_packet1,
    input EX_PACKET ex_packet2,

    output EX_PACKET ex_packet_out
);
    EX_PACKET [`FIFO_LEN-1:0] fifo_storage;
    EX_PACKET [`FIFO_LEN-1:0] next_fifo_storage;

    logic [$clog2(`FIFO_LEN)-1:0] pointer;
    logic [$clog2(`FIFO_LEN)-1:0] next_pointer;

    logic is_empty1;
    logic is_empty2;

    assign is_empty1 = ((ex_packet1.NPC          == 0) &&
                        (ex_packet1.rs2_value    == 0) &&
                        (ex_packet1.rd_mem       == 0) &&
                        (ex_packet1.wr_mem       == 0) &&
                        (ex_packet1.dest_reg_idx == 0) &&
                        (ex_packet1.halt         == 0) &&
                        (ex_packet1.illegal      == 0) &&
                        (ex_packet1.csr_op       == 0) &&
                        (ex_packet1.valid        == 0) &&
                        (ex_packet1.mem_size     == 0) &&
                        (ex_packet1.take_branch  == 0) &&
                        (ex_packet1.alu_result   == 0)) ? 1 : 0;

    assign is_empty2 = ((ex_packet2.NPC          == 0) &&
                        (ex_packet2.rs2_value    == 0) &&
                        (ex_packet2.rd_mem       == 0) &&
                        (ex_packet2.wr_mem       == 0) &&
                        (ex_packet2.dest_reg_idx == 0) &&
                        (ex_packet2.halt         == 0) &&
                        (ex_packet2.illegal      == 0) &&
                        (ex_packet2.csr_op       == 0) &&
                        (ex_packet2.valid        == 0) &&
                        (ex_packet2.mem_size     == 0) &&
                        (ex_packet2.take_branch  == 0) &&
                        (ex_packet2.alu_result   == 0)) ? 1 : 0;

    always_comb begin
        if (is_empty1 && is_empty2) begin
        end
    end

endmodule

`endif