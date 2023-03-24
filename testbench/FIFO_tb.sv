
`include "sys_defs.svh"

module FIFO_tb;
    logic clock,reset
    EX_PACKET ex_packet1;
    EX_PACKET ex_packet2;

    EX_PACKET ex_packet_out;
    logic     null;

    FIFO FIFO_0 (
        .clock(clock),
        .reset(reset),
        .ex_packet1(ex_packet1),
        .ex_packet2(ex_packet2),

        //output
        .ex_packet_out(ex_packet_out),
        .null(null)
    );

    always begin
        #5;
        clock = ~clock;
    end

    //start testing
    initial begin
        clock = 0;
        reset = 1;
        @(negedge clock);
        reset = 0;
        
        //initial packet1
        ex_packet1.NPC          = 0;
		ex_packet1.rs2_value    = 0;
		ex_packet1.rd_mem       = 0;
		ex_packet1.wr_mem       = 0;
		ex_packet1.dest_reg_idx = 0;
		ex_packet1.halt         = 0;
		ex_packet1.illegal      = 0;
		ex_packet1.csr_op       = 0;
		ex_packet1.valid        = 0;
		ex_packet1.mem_size     = 0;
		ex_packet1.take_branch  = 0;
		ex_packet1.alu_result   = 0;

        //initial packet2
        ex_packet2.NPC          = 0;
		ex_packet2.rs2_value    = 0;
		ex_packet2.rd_mem       = 0;
		ex_packet2.wr_mem       = 0;
		ex_packet2.dest_reg_idx = 0;
		ex_packet2.halt         = 0;
		ex_packet2.illegal      = 0;
		ex_packet2.csr_op       = 0;
		ex_packet2.valid        = 0;
		ex_packet2.mem_size     = 0;
		ex_packet2.take_branch  = 0;
		ex_packet2.alu_result   = 0;

        @(negedge clock);
        assert(null == 1) else begin 
            $display("expected null == 1, actual null == 0");
            $finish;
        end

        //packet 1 not empty, packet 2 is empty
        ex_packet1.alu_result   = 100;
        @(negedge clock);

        assert(null == 0) else begin 
            $display("expected null == 0, actual null == 1");
            $finish;
        end
        assert(ex_packet_out.alu_result  == 100) else begin 
            $display("expected alu_result == 100, actual alu_result == %d", ex_packet_out.alu_result);
            $finish;
        end

        //packet 2 not empty, packet 1 is empty
        ex_packet1.alu_result   = 0;
        ex_packet2.alu_result   = 200;

        @(negedge clock);

        assert(null == 0) else begin 
            $display("expected null == 0, actual null == 1");
            $finish;
        end
        assert(ex_packet_out.alu_result  == 200) else begin 
            $display("expected alu_result == 200, actual alu_result == %d", ex_packet_out.alu_result);
            $finish;
        end

        //both two packets are not empty
        ex_packet1.alu_result   = 300;
        ex_packet2.alu_result   = 400;

        @(negedge clock);

        assert(null == 0) else begin 
            $display("expected null == 0, actual null == 1");
            $finish;
        end
        assert(ex_packet_out.alu_result  == 300) else begin 
            $display("expected alu_result == 300, actual alu_result == %d", ex_packet_out.alu_result);
            $finish;
        end

        //packet 1 not empty, packet 2 is empty
        ex_packet1.alu_result   = 500;
        ex_packet2.alu_result   = 0;

        @(negedge clock);

        assert(null == 0) else begin 
            $display("expected null == 0, actual null == 1");
            $finish;
        end
        assert(ex_packet_out.alu_result  == 400) else begin 
            $display("expected alu_result == 400, actual alu_result == %d", ex_packet_out.alu_result);
            $finish;
        end

        $display("@@@Passed!");
        $finish;
    end
    




endmodule