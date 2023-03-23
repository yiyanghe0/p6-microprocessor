
module testbench_map_table;
    logic clock;
    logic reset;
    logic wr_en;
    RS2MT_PACKET rs2mt_packet_in;
    CDB_PACKET cdb_packet_in;
    MT2RS_PACKET mt2rs_packet_out;
    ROB2MT_PACKET rob2mt_packet_in;
    logic [10:0] instr;

    MAP_TABLE DUT_map_table(
        .clock(clock),
        .reset(reset),
        .wr_en(wr_en),
        .rs2mt_packet_in(rs2mt_packet_in),
        .cdb_packet_in(cdb_packet_in),
        .rob2mt_packet_in(rob2mt_packet_in),
        .mt2rs_packet_out(mt2rs_packet_out)
    );

    always begin
        #5;
        clock = ~clock;
    end

    task generate_rs_package;
        input [`REG_LEN-1:0] rs1;
        input [`REG_LEN-1:0] rs2;
        input [`REG_LEN-1:0] dest;
        input [$clog2(`ROB_LEN)-1:0] dest_tag;
        input dest_valid;
        begin
            rs2mt_packet_in.rs1_idx = rs1;
            rs2mt_packet_in.rs2_idx = rs2;
            rs2mt_packet_in.dest_reg_idx = dest;
            rs2mt_packet_in.dest_reg_tag.tag = dest_tag;
            rs2mt_packet_in.dest_reg_tag.valid = dest_valid;
        end
    endtask

    task generate_cdb_package;
        input [$clog2(`ROB_LEN)-1:0] cdb_tag;
        input cdb_valid;
        input [`XLEN-1:0] cdb_value;
        begin
            cdb_packet_in.reg_tag.tag = cdb_tag;
            cdb_packet_in.reg_tag.valid = cdb_valid;
            cdb_packet_in.reg_value = cdb_value;
        end
    endtask

    task generate_rob_package;
        input clear;
        input [$clog2(`ROB_LEN)-1:0] rob_entry;
        begin
            rob2mt_packet_in.retire = clear;
            rob2mt_packet_in.head_idx = rob_entry;
        end
    endtask

    task exit_on_error_rs1;
        input [$clog2(`ROB_LEN)-1:0] correct_tag;
        input correct_valid;
        input correct_ready;
        begin
            $display("@@@ Incorrect at time %4.0f, rs1 outputs wrong value", $time);
            $display("@@@ Current values: tag: %d valid: %b ready: %b", 
            mt2rs_packet_out.rs1_tag.tag, mt2rs_packet_out.rs1_tag.valid, mt2rs_packet_out.rs1_ready);
            $display("@@@ Correct values: tag: %d valid: %b ready: %b", correct_tag, correct_valid, correct_ready);
            $display("@@@ FAILED");
            $finish;
        end
    endtask

    task exit_on_error_rs2;
        input [$clog2(`ROB_LEN)-1:0] correct_tag;
        input correct_valid;
        input correct_ready;
        begin
            $display("@@@ Incorrect at time %4.0f, rs2 outputs wrong value", $time);
            $display("@@@ Current values: tag: %d valid: %b ready: %b", 
            mt2rs_packet_out.rs2_tag.tag, mt2rs_packet_out.rs2_tag.valid, mt2rs_packet_out.rs2_ready);
            $display("@@@ Correct values: tag: %d valid: %b ready: %b", correct_tag, correct_valid, correct_ready);
            $display("@@@ FAILED");
            $finish;
        end
    endtask

    task check_rs1;
        input [$clog2(`ROB_LEN)-1:0] correct_tag;
        input correct_valid;
        input correct_ready;
        begin
            assert(mt2rs_packet_out.rs1_tag.tag == correct_tag && mt2rs_packet_out.rs1_tag.valid == correct_valid && mt2rs_packet_out.rs1_ready == correct_ready)
            else exit_on_error_rs1(correct_tag, correct_valid, correct_ready);
        end
    endtask

    task check_rs2;
        input [$clog2(`ROB_LEN)-1:0] correct_tag;
        input correct_valid;
        input correct_ready;
        begin
            assert(mt2rs_packet_out.rs2_tag.tag == correct_tag && mt2rs_packet_out.rs2_tag.valid == correct_valid && mt2rs_packet_out.rs2_ready == correct_ready)
            else exit_on_error_rs2(correct_tag, correct_valid, correct_ready);
        end
    endtask

    initial begin
        $monitor("Time:%4.0f Instr:%3d running", $time, instr);
        clock = 0;
        reset = 1;
        // 0:0
        // 1:0
        // 2:0
        // 3:0
        // 4:0
        // 5:0
        @(negedge clock);
        reset = 0;
        wr_en = 1;
        // instr 1 f1 f2 f1
        // 0:0
        // 1:0
        // 2:0
        // 3:0
        // 4:0
        // 5:0

        instr = 1;
        generate_rs_package(1,2,1,0,1); // f1 f2 f1
        generate_cdb_package(0,0,0);
        generate_rob_package(0,0);
        #1
        check_rs1(0,0,0); //no tag not valid not ready
        check_rs2(0,0,0); 

        @(negedge clock);
        // instr 2 f1 f2 f3
        // 0:0
        // 1:0.
        // 2:0
        // 3:0
        // 4:0
        // 5:0
        
        instr = 2;
        generate_rs_package(1,2,3,1,1);
        generate_cdb_package(0,1,10);
        #1
        check_rs1(0,1,0);
        check_rs2(0,0,0); 

        @(negedge clock);
        // instr 3 f3 f4 f2
        // 0:0
        // 1:0+
        // 2:0
        // 3:1.
        // 4:0
        // 5:0
        
        instr = 3;
        generate_rs_package(3,4,2,2,1);
        generate_cdb_package(0,0,0);
        #1
        check_rs1(1,1,0);
        check_rs2(0,0,0); 

        @(negedge clock);
        // instr 4 f1 f2 f5
        // 0:0
        // 1:0+
        // 2:2.
        // 3:1.
        // 4:0
        // 5:0
        
        instr = 4;
        generate_rs_package(1,2,5,3,1);
        generate_cdb_package(0,0,0);
        #1
        check_rs1(0,1,1);
        check_rs2(2,1,0); 

        @(negedge clock);
        // instr 5 f3 f3 f3 (stall)
        // 0:0
        // 1:0+
        // 2:2.
        // 3:1.
        // 4:0
        // 5:3.
        wr_en = 0;
        instr = 5;
        generate_rs_package(3,3,3,4,0); //stall rs structrual hazard
        generate_cdb_package(2,1,8);

        @(negedge clock);
        // instr 6 f3 f3 f3
        // 0:0
        // 1:0+
        // 2:2+
        // 3:1.
        // 4:0
        // 5:3.
        wr_en = 1;
        instr = 6;
        generate_rs_package(3,3,3,4,1);
        generate_cdb_package(0,0,8);
        #1
        check_rs1(1,1,0);
        check_rs2(1,1,0); 

        @(negedge clock);
        // instr 7 f2 f3 f0
        // 0:0
        // 1:0+
        // 2:2+
        // 3:4.
        // 4:0
        // 5:3.
        instr = 7;
        generate_rs_package(2,3,0,5,1);
        generate_cdb_package(1,1,5);
        #1
        check_rs1(2,1,1);
        check_rs2(4,1,0);

        @(negedge clock);
        // instr 8 f3 f4 f5
        // 0:5.
        // 1:0+
        // 2:2+
        // 3:4.
        // 4:0
        // 5:3.
        instr = 8;
        generate_rs_package(3,4,5,6,1);
        generate_cdb_package(3,1,5);
        #1
        check_rs1(4,1,0);
        check_rs2(0,0,0);
        
        @(negedge clock);
        // instr 9 f3 f5 f2
        // 0:5.
        // 1:0+
        // 2:2+
        // 3:4.
        // 4:0
        // 5:6.
        instr = 9;
        generate_rs_package(3,5,2,7,1);
        generate_cdb_package(5,0,8);
        #1
        check_rs1(4,1,0);
        check_rs2(6,1,0);

        @(negedge clock);
        // instr 10 f0 f3 f4
        // 0:5.
        // 1:0+
        // 2:7.
        // 3:4.
        // 4:0
        // 5:6.
        instr = 10;
        generate_rs_package(0,3,4,8,1);
        generate_cdb_package(6,0,8);
        #1
        check_rs1(5,1,0);
        check_rs2(4,1,0);

        @(negedge clock);
        // instr 11 f1 f2 f5
        // 0:5.
        // 1:0+
        // 2:7.
        // 3:4.
        // 4:8.
        // 5:6.
        instr = 11;
        generate_rs_package(1,2,5,9,1);
        generate_cdb_package(7,1,8);
        #1
        check_rs1(0,1,1);
        check_rs2(7,1,0);

        @(negedge clock);
        // instr 12 f1 f4 f5
        // 0:5.
        // 1:0+
        // 2:7+
        // 3:4.
        // 4:8.
        // 5:9.
        instr = 12;
        generate_rs_package(1,4,5,10,1);
        generate_cdb_package(6,1,8);
        #1
        check_rs1(0,1,1);
        check_rs2(8,1,0);

        @(negedge clock);
        // instr 13 f0 f5 f1
        // 0:5.
        // 1:0+
        // 2:7+
        // 3:4.
        // 4:8.
        // 5:10.
        instr = 13;
        generate_rs_package(0,5,1,11,1);
        generate_cdb_package(4,1,8);
        #1
        check_rs1(5,1,0);
        check_rs2(10,1,0);

        @(negedge clock);
        // instr 14 f3 f4 f2
        // 0:5.
        // 1:11.
        // 2:7+
        // 3:4+
        // 4:8.
        // 5:10.
        instr = 14;
        generate_rs_package(3,4,2,12,0);
        generate_cdb_package(9,1,8);
        #1
        check_rs1(4,1,1);
        check_rs2(8,1,0);

        @(negedge clock);
        // instr 15 f0 f2 f0
        // 0:5.
        // 1:11.
        // 2:7+
        // 3:4+
        // 4:8.
        // 5:10.
        instr = 15;
        generate_rs_package(0,2,0,13,0);
        generate_cdb_package(0,0,0);
        generate_rob_package(1,7);
        #1
        check_rs1(5,1,0);
        check_rs2(7,1,1);

        @(negedge clock);
        // instr 16 f0 f2 f4
        // 0:5.
        // 1:11.
        // 2:0
        // 3:4+
        // 4:8.
        // 5:10.
        instr = 16;
        generate_rs_package(0,2,4,13,1);
        generate_cdb_package(11,1,6);
        generate_rob_package(1,4);
        #1
        check_rs1(5,1,0);
        check_rs2(0,0,0);

        @(negedge clock);
        // instr 17 f0 f3 f4
        // 0:5.
        // 1:11+
        // 2:0
        // 3:0
        // 4:13.
        // 5:10.
        instr = 17;
        generate_rs_package(0,3,4,14,1);
        generate_cdb_package(10,1,7);
        generate_rob_package(1,3);
        #1
        check_rs1(5,1,0);
        check_rs2(0,0,0);

        @(negedge clock);
        // instr 18 f0 f3 f4
        // 0:5.
        // 1:11+
        // 2:0
        // 3:0
        // 4:14.
        // 5:10+
        instr = 18;
        generate_rs_package(0,3,1,15,1);
        generate_cdb_package(14,1,6);
        generate_rob_package(1,11);
        #1
        check_rs1(5,1,0);
        check_rs2(0,0,0);

        @(negedge clock);
        // instr 19 f0 f1 f4
        // 0:5.
        // 1:15.
        // 2:0
        // 3:0
        // 4:14+
        // 5:10+
        instr = 19;
        generate_rs_package(0,1,4,16,0);
        generate_cdb_package(0,0,0);
        generate_rob_package(0,0);
        #1
        check_rs1(5,1,0);
        check_rs2(15,1,0);

        @(negedge clock);
        reset = 1;
        @(negedge clock);
        reset = 0;
        #1
        check_rs1(0,0,0);
        check_rs2(0,0,0);
        $display("@@@PASSED");
        $finish;
    end

endmodule