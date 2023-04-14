`ifndef __FIFO_SV__
`define __FIFO_SV__

`define FIFO_LEN 8
`define DEBUG

`include "sys_defs.svh"

module FIFO(
    input clock,
    input reset,
    input EX_PACKET ex_packet1,
    input EX_PACKET ex_packet2,
    input EX_PACKET ex_packet3,

    `ifdef DEBUG
    output EX_PACKET [`FIFO_LEN-1:0] fifo_storage,
    output logic [$clog2(`FIFO_LEN):0] pointer,
    `endif

    output EX_PACKET ex_packet_out,
    output logic no_output // no_output = 1 -> nothing output; no_output = 0 -> valid output
);
    `ifndef DEBUG
    EX_PACKET [`FIFO_LEN-1:0] fifo_storage;
    `endif
    EX_PACKET [`FIFO_LEN-1:0] next_fifo_storage;

    // pointer == `FIFO_LEN -> empty
    `ifndef DEBUG
    logic [$clog2(`FIFO_LEN):0] pointer;
    `endif
    logic [$clog2(`FIFO_LEN):0] next_pointer;

    logic is_empty1;
    logic is_empty2;
    logic is_empty3;

    logic empty;

    assign empty = (pointer == `FIFO_LEN) ? 1 : 0;

    assign is_empty1 = ((ex_packet1.NPC          == 0) &&
                        (ex_packet1.PC           == 0) &&
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
                        (ex_packet1.alu_result   == 0) &&
                        (ex_packet1.is_ZEROREG   == 1) &&
                        (ex_packet1.uncond_branch == 0)) ? 1: 0;

    assign is_empty2 = ((ex_packet2.NPC          == 0) &&
                        (ex_packet2.PC           == 0) &&
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
                        (ex_packet2.alu_result   == 0) &&
                        (ex_packet2.is_ZEROREG   == 1) &&
                        (ex_packet2.uncond_branch == 0)) ? 1: 0;

    assign is_empty3 = ((ex_packet3.NPC          == 0) &&
                        (ex_packet3.PC           == 0) &&
                        (ex_packet3.rs2_value    == 0) &&
                        (ex_packet3.rd_mem       == 0) &&
                        (ex_packet3.wr_mem       == 0) &&
                        (ex_packet3.dest_reg_idx == 0) &&
                        (ex_packet3.halt         == 0) &&
                        (ex_packet3.illegal      == 0) &&
                        (ex_packet3.csr_op       == 0) &&
                        (ex_packet3.valid        == 0) &&
                        (ex_packet3.mem_size     == 0) &&
                        (ex_packet3.take_branch  == 0) &&
                        (ex_packet3.alu_result   == 0) &&
                        (ex_packet3.is_ZEROREG   == 1) &&
                        (ex_packet3.uncond_branch == 0)) ? 1: 0;
    
    

    always_comb begin
        //all the packets are empty
        if (is_empty1 && is_empty2 && is_empty3) begin
            next_pointer = (empty) ? pointer :
                                     (pointer == 0) ? `FIFO_LEN : (pointer - 1);
        end
        //two packets are empty
        else if ((!is_empty1 && is_empty2 && is_empty3) || (is_empty1 && !is_empty2 && is_empty3) || 
        (is_empty1 && is_empty2 && !is_empty3)) begin
            next_pointer = pointer;
        end
        //one packet is empty
        else if ((is_empty1 && !is_empty2 && !is_empty3) || (!is_empty1 && is_empty2 && !is_empty3) || 
        (!is_empty1 && !is_empty2 && is_empty3)) begin
            next_pointer = (empty) ? 0 : (pointer + 1);
        end
        //three packets are not empty
        else begin
            // should not fill up the fifo!!!
            next_pointer = (empty) ? 1 : (pointer + 2);
        end
    end

    always_comb begin
        next_fifo_storage = fifo_storage;

        if (empty) begin
            //three packaets are not empty and the storage is empty
            if (!is_empty1 && !is_empty2 && !is_empty3) begin
                next_fifo_storage[0] = ex_packet2;
                next_fifo_storage[1] = ex_packet3;
            end
            //packet1 is empty and others are not
            else if (is_empty1 && !is_empty2 && !is_empty3) begin
                next_fifo_storage[0] = ex_packet3;
            end
            //packet2 is empty and others are not
            else if (!is_empty1 && is_empty2 && !is_empty3) begin
                next_fifo_storage[0] = ex_packet3;
            end
            //packet3 is empty and others are not
            else if (!is_empty1 && !is_empty2 && is_empty3) begin
                next_fifo_storage[0] = ex_packet2;
            end
        //the storage is not empty
        end
        else begin
            for (int i = 0; i < pointer; i++) begin
                next_fifo_storage[i] = fifo_storage[i+1];
            end
            //packet1 is not empty and others are empty
            if (!is_empty1 && is_empty2 && is_empty3) begin
                next_fifo_storage[pointer] = ex_packet1;
            end
            //packet2 is not empty and others are empty
            else if (is_empty1 && !is_empty2 && is_empty3) begin
                next_fifo_storage[pointer] = ex_packet2;
            end
            //packet3 is not empty and others are empty
            else if (is_empty1 && is_empty2 && !is_empty3) begin
                next_fifo_storage[pointer] = ex_packet3;
            end
            //pakcet1 and packet2 are not empty, and packet3 is empty
            else if (!is_empty1 && !is_empty2 && is_empty3) begin
                next_fifo_storage[pointer] = ex_packet1;
                next_fifo_storage[pointer+1] = ex_packet2;
            end
            //pakcet1 and packet3 are not empty, and packet2 is empty
            else if (!is_empty1 && is_empty2 && !is_empty3) begin
                next_fifo_storage[pointer] = ex_packet1;
                next_fifo_storage[pointer+1] = ex_packet3;
            end
            //pakcet2 and packet3 are not empty, and packet1 is empty
            else if (is_empty1 && !is_empty2 && !is_empty3) begin
                next_fifo_storage[pointer] = ex_packet2;
                next_fifo_storage[pointer+1] = ex_packet3;
            end
            //All the packets are not empty
            else if (!is_empty1 && !is_empty2 && !is_empty3) begin
                next_fifo_storage[pointer] = ex_packet1;
                next_fifo_storage[pointer+1] = ex_packet2;
                next_fifo_storage[pointer+2] = ex_packet3;
            end
        end
    end

    //select which packet should be popped out
    always_comb begin
        if (empty) begin
            //no input and the FIFO is empty
            if (is_empty1 && is_empty2 && is_empty3) begin
                no_output = 1;
                ex_packet_out.NPC           = 0;
                ex_packet_out.PC            = 0;
                ex_packet_out.rs2_value     = 0;
                ex_packet_out.rd_mem        = 0;
                ex_packet_out.wr_mem        = 0;
                ex_packet_out.dest_reg_idx  = 0;
                ex_packet_out.halt          = 0;
                ex_packet_out.illegal       = 0;
                ex_packet_out.csr_op        = 0;
                ex_packet_out.valid         = 0;
                ex_packet_out.mem_size      = 0;
                ex_packet_out.take_branch   = 0;
                ex_packet_out.alu_result    = 0;
                ex_packet_out.is_ZEROREG    = 1;
                ex_packet_out.uncond_branch = 0;
            end
            //packet1 is not empty and others are empty
            else if (!is_empty1 && is_empty2 && is_empty3) begin
                no_output = 0;
                ex_packet_out = ex_packet1;
            end
            //packet2 is not empty and others are empty
            else if (is_empty1 && !is_empty2 && is_empty3) begin
                no_output = 0;
                ex_packet_out = ex_packet2;
            end
            //packet3 is not empty and others are empty
            else if (is_empty1 && is_empty2 && !is_empty3) begin
                no_output = 0;
                ex_packet_out = ex_packet3;
            end
            //pakcet1 and packet2 are not empty, and packet3 is empty => pop out packet1
            else if (!is_empty1 && !is_empty2 && is_empty3) begin
                no_output = 0;
                ex_packet_out = ex_packet1;
            end
            //pakcet1 and packet3 are not empty, and packet2 is empty => pop out packet1
            else if (!is_empty1 && is_empty2 && !is_empty3) begin
                no_output = 0;
                ex_packet_out = ex_packet1;
            end
            //pakcet2 and packet3 are not empty, and packet1 is empty => pop out packet2
            else if (is_empty1 && !is_empty2 && !is_empty3) begin
                no_output = 0;
                ex_packet_out = ex_packet2;
            end
            //All the packets are not empty => pop out packet1
            else begin
                no_output = 0;
                // Always assume ex_packet1 first out
                // Put ex_packet2 and ex_packet3 into fifo_storage
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
                fifo_storage[i].NPC             <= `SD 0;
                fifo_storage[i].PC              <= `SD 0;
                fifo_storage[i].rs2_value       <= `SD 0;
                fifo_storage[i].rd_mem          <= `SD 0;
                fifo_storage[i].wr_mem          <= `SD 0;
                fifo_storage[i].dest_reg_idx    <= `SD 0;
                fifo_storage[i].halt            <= `SD 0;
                fifo_storage[i].illegal         <= `SD 0;
                fifo_storage[i].csr_op          <= `SD 0;
                fifo_storage[i].valid           <= `SD 0;
                fifo_storage[i].mem_size        <= `SD 0;
                fifo_storage[i].take_branch     <= `SD 0;
                fifo_storage[i].alu_result      <= `SD 0;
                fifo_storage[i].is_ZEROREG      <= `SD 1;
                fifo_storage[i].uncond_branch   <= `SD 0;
            end
        end
        else begin
            pointer <= `SD next_pointer;
            fifo_storage <= `SD next_fifo_storage;
        end
    end

endmodule

`endif