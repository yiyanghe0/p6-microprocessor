`define DEBUG
`define FIFO_LEN 8

module FIFO_tb;
    logic clock,reset;
    EX_PACKET ex_packet1;
    EX_PACKET ex_packet2;

    EX_PACKET ex_packet_out;
    logic     no_output;

    EX_PACKET [`FIFO_LEN-1:0] fifo_storage;
    logic [$clog2(`FIFO_LEN):0] pointer;

    FIFO FIFO_0 (
        .clock(clock),
        .reset(reset),
        .ex_packet1(ex_packet1),
        .ex_packet2(ex_packet2),

        //output
        .fifo_storage(fifo_storage),
        .pointer(pointer),

        .ex_packet_out(ex_packet_out),
        .no_output(no_output)
    );

    task exit_on_error;
        input correct_no_output;
        input [`XLEN-1:0] correct_alu_result;

        begin
            $display("@@@ Incorrect at time %4.0f", $time);
            $display("@@@ Expected no_output: %b; Actual issued inst: %b", correct_no_output, no_output);
            $display("@@@ Expected output packet alu: %d; Actual output packet alu: %d", correct_alu_result, ex_packet_out.alu_result);
            $display("@@@ ----------------------------------------- @@@");

            $display("@@@ Current FIFO contents:");
            for (int i = 0; i < `FIFO_LEN; i++) begin
                $display("@@@ [%1d] packet alu: %d", i, fifo_storage[i].alu_result);
            end
            
            $display("@@@failed");
            $finish;
        end
    endtask

    task check_func;
        input correct_no_output;
        input [`XLEN-1:0] correct_alu_result;

        begin 
            #1 assert (no_output == correct_no_output)                        else exit_on_error(correct_no_output,correct_alu_result);
            assert (ex_packet_out.alu_result == correct_alu_result)           else exit_on_error(correct_no_output,correct_alu_result);
        end
    endtask

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

        check_func(1, 0);

        @(negedge clock);
        //packet 1 not empty, packet 2 is empty
        ex_packet1.alu_result   = 100;
        check_func(0, 100);

        @(negedge clock);
        //packet 2 not empty, packet 1 is empty
        ex_packet1.alu_result   = 0;
        ex_packet2.alu_result   = 200;
        check_func(0, 200);

        @(negedge clock);
        //both two packets are not empty
        ex_packet1.alu_result   = 300;
        ex_packet2.alu_result   = 400;
        check_func(0, 300);

        @(negedge clock);
        //packet 1 not empty, packet 2 is empty
        ex_packet1.alu_result   = 500;
        ex_packet2.alu_result   = 0;
        check_func(0, 400);

        @(negedge clock);
        //packet 2 not empty, packet 1 is empty
        ex_packet1.alu_result   = 0;
        ex_packet2.alu_result   = 600;
        check_func(0, 500);

        @(negedge clock);
        //both two packets are not empty
        ex_packet1.alu_result   = 700;
        ex_packet2.alu_result   = 800;
        check_func(0, 600);

        @(negedge clock);
        //both two packets are empty
        ex_packet1.alu_result   = 0;
        ex_packet2.alu_result   = 0;
        check_func(0, 700);

        @(negedge clock);
        check_func(0, 800);

        @(negedge clock);
        check_func(1, 0);

        $display("@@@passed");
        $finish;
    end
    




endmodule