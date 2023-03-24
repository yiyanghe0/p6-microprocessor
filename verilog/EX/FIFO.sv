`ifndef __FIFO_SV__
`define __FIFO_SV__

`define FIFO_LEN 8

`include "sys_defs.svh"

module FIFO(
    input clock,
    input reset,
    input EX_PACKET ex_packet1,
    input EX_PACKET ex_packet2,

    output EX_PACKET ex_packet_out,
    output logic no_output // no_output = 1 -> nothing output; no_output = 0 -> valid output
);
    EX_PACKET [`FIFO_LEN-1:0] fifo_storage;
    EX_PACKET [`FIFO_LEN-1:0] next_fifo_storage;

    // pointer == `FIFO_LEN -> empty
    logic [$clog2(`FIFO_LEN):0] pointer;
    logic [$clog2(`FIFO_LEN):0] next_pointer;

    logic is_empty1;
    logic is_empty2;

    logic empty;

    assign empty = (pointer == `FIFO_LEN) ? 1 : 0;

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
            next_pointer = (empty) ? pointer :
                                     (pointer == 0) ? `FIFO_LEN : (pointer - 1);
        end
        else if (is_empty1 || is_empty2) begin
            next_pointer = pointer;
        end
        else begin
            // should not fill up the fifo!!!
            next_pointer = (empty) ? 0 : (pointer + 1);
        end
    end

    always_comb begin
        if (empty) begin
            if (is_empty1 || is_empty2) // Originally empty, either one or two incoming packets empty, next fifo storage still empty
                next_fifo_storage = fifo_storage;
            else
                next_fifo_storage[0] = ex_packet2;
        end
        else begin
            for (int i = 0; i < pointer; i++) begin
                next_fifo_storage[i] = fifo_storage[i+1];
            end

            if (is_empty1 && is_empty2) begin
                for (int i = pointer; i < `FIFO_LEN; i++) begin
                    next_fifo_storage[i] = fifo_storage[i];
                end
            end
            else if (is_empty2) begin
                next_fifo_storage[pointer] = ex_packet1;

                for (int i = pointer + 1; i < `FIFO_LEN; i++) begin
                    next_fifo_storage[i] = fifo_storage[i];
                end
            end
            else if (is_empty1) begin
                next_fifo_storage[pointer] = ex_packet2;

                for (int i = pointer + 1; i < `FIFO_LEN; i++) begin
                    next_fifo_storage[i] = fifo_storage[i];
                end
            end
            else begin
                next_fifo_storage[pointer] = ex_packet1;
                next_fifo_storage[pointer+1] = ex_packet2;

                for (int i = pointer + 2; i < `FIFO_LEN; i++) begin
                    next_fifo_storage[i] = fifo_storage[i];
                end
            end
        end
    end

    always_comb begin
        if (empty) begin
            if (is_empty1 && is_empty2) begin
                no_output = 1;
                ex_packet_out.NPC          = 0;
                ex_packet_out.rs2_value    = 0;
                ex_packet_out.rd_mem       = 0;
                ex_packet_out.wr_mem       = 0;
                ex_packet_out.dest_reg_idx = 0;
                ex_packet_out.halt         = 0;
                ex_packet_out.illegal      = 0;
                ex_packet_out.csr_op       = 0;
                ex_packet_out.valid        = 0;
                ex_packet_out.mem_size     = 0;
                ex_packet_out.take_branch  = 0;
                ex_packet_out.alu_result   = 0;
            end
            else if (is_empty2) begin
                no_output = 0;
                ex_packet_out = ex_packet1;
            end
            else if (is_empty1) begin
                no_output = 0;
                ex_packet_out = ex_packet2;
            end
            else begin
                no_output = 0;
                // Always assume ex_packet1 first out
                // Put ex_packet2 into fifo_storage
                ex_packet_out = ex_packet1;
            end
        end
        else begin
            no_output = 0;
            ex_packet_out = fifo_storage[0];
        end
    end

    //synopsys sync_set_reset "reset"
    always_ff @(posedge clock) begin
        if (reset) begin
            pointer <= `SD `FIFO_LEN; // empty
            for (int i = 0; i < `FIFO_LEN; i++) begin
                fifo_storage[i].NPC          = 0;
                fifo_storage[i].rs2_value    = 0;
                fifo_storage[i].rd_mem       = 0;
                fifo_storage[i].wr_mem       = 0;
                fifo_storage[i].dest_reg_idx = 0;
                fifo_storage[i].halt         = 0;
                fifo_storage[i].illegal      = 0;
                fifo_storage[i].csr_op       = 0;
                fifo_storage[i].valid        = 0;
                fifo_storage[i].mem_size     = 0;
                fifo_storage[i].take_branch  = 0;
                fifo_storage[i].alu_result   = 0;
            end
        end
        else begin
            pointer <= `SD next_pointer;
            fifo_storage <= `SD next_fifo_storage;
        end
    end

endmodule

`endif