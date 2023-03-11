

module testbench_rs_entry;
    logic clock;
    logic reset;
    ID_PACKET id_packet_in; // invalid if enable = 0
    MT2RS_PACKET mt2rs_packet_in; // invalid if enable = 0
    CDB_PACKET cdb_packet_in; 
    ROB2RS_PACKET rob2rs_packet_in; // invalid if enable = 0
    logic clear;
    logic enable;

    IS_PACKET entry_packet;
    logic busy;
    logic ready;

    RS_entry DUT_rs_entry(
        .clock(clock),
        .reset(reset),
        .id_packet_in(id_packet_in),
        .mt2rs_packet_in(mt2rs_packet_in),
        .cdb_packet_in(cdb_packet_in),
        .rob2rs_packet_in(rob2rs_packet_in),
        .clear(clear),
        .wr_en(enable),
        .entry_packet(entry_packet),
        .busy(busy),
        .ready(ready)

    );

    always begin
        #5;
        clock = ~clock;
    end

    task give_id_message;
        begin
            id_packet_in.NPC = $random(32);
            id_packet_in.PC = $random(32);
            id_packet_in.opa_select = $random(2);
            id_packet_in.opb_select = $random(4);
            id_packet_in.dest_reg_idx = $random(4);
            id_packet_in.alu_func = $random(5);
            id_packet_in.rd_mem = $random(1);
            id_packet_in.wr_mem = $random(1);
            id_packet_in.cond_branch = $random(1);
            id_packet_in.halt = $random(1);
            id_packet_in.illegal = $random(1);
            id_packet_in.csr_op = $random(1);
            id_packet_in.valid = $random(1);
        end
    endtask


    task exit_on_error;
        input correct_busy, correct_ready;
        begin
            $display("@@@ Incorrect at time %4.0f", $time);
            $display("@@@ Time:%4.0f enable:%b busy:%b ready:%b INST:%8h", $time, enable, busy, ready, entry_packet.inst.inst);
            $display("@@@ expected busy: %b, expected ready: %b", correct_busy, correct_ready);
            $display("@@@failed");
            $finish;
        end
    endtask

    task check_id_packet;
        input correct_busy, correct_ready;
        input [31:0] correct_rs1;
        input [31:0] correct_rs2;
        begin 
            assert (busy == correct_busy)                                   else exit_on_error(correct_busy,correct_ready);
            assert (ready == correct_ready)                                 else exit_on_error(correct_busy,correct_ready);
            assert (id_packet_in.NPC == entry_packet.NPC)                   else exit_on_error(correct_busy,correct_ready);
            assert (id_packet_in.PC == entry_packet.PC)                     else exit_on_error(correct_busy,correct_ready);
            assert (entry_packet.rs1_value == correct_rs1)                  else exit_on_error(correct_busy,correct_ready);
            assert (entry_packet.rs2_value == correct_rs2)                  else exit_on_error(correct_busy,correct_ready);
            assert (id_packet_in.opa_select == entry_packet.opa_select)     else exit_on_error(correct_busy,correct_ready);
            assert (id_packet_in.opb_select == entry_packet.opb_select)     else exit_on_error(correct_busy,correct_ready);
            assert (id_packet_in.alu_func == entry_packet.alu_func)         else exit_on_error(correct_busy,correct_ready);
            assert (id_packet_in.rd_mem == entry_packet.rd_mem)             else exit_on_error(correct_busy,correct_ready);
            assert (id_packet_in.wr_mem == entry_packet.wr_mem)             else exit_on_error(correct_busy,correct_ready);
            assert (id_packet_in.cond_branch == entry_packet.cond_branch)   else exit_on_error(correct_busy,correct_ready);
            assert (id_packet_in.halt == entry_packet.halt)                 else exit_on_error(correct_busy,correct_ready);
            assert (id_packet_in.illegal == entry_packet.illegal)           else exit_on_error(correct_busy,correct_ready);
            assert (id_packet_in.csr_op == entry_packet.csr_op)             else exit_on_error(correct_busy,correct_ready);
            assert (id_packet_in.valid == entry_packet.valid)               else exit_on_error(correct_busy,correct_ready);
        end
    endtask

    //i1: add r1 r1 f1
    //i2: add r2 r2 f2
    //i3: add r3 r3 f3

    initial begin
        //$monitor("TIME:%4.0f busy:%b ready:%b", $time, busy, ready);
        clock = 0;
        reset = 1;
        @(negedge clock);
        reset = 0;
        //inst1 
        enable = 1;
        //id
        give_id_message();
        id_packet_in.inst.inst = 32'hABCDEF12;
        id_packet_in.rs1_value = 1;
        id_packet_in.rs2_value = 1;
        //mt
        mt2rs_packet_in.rs1_tag = 0; // reg file
        mt2rs_packet_in.rs2_tag = 0;
        mt2rs_packet_in.rs1_ready = 0;
        mt2rs_packet_in.rs2_ready = 0;
        //cdb
        cdb_packet_in.reg_tag = 0;
        cdb_packet_in.reg_value = 0;
        //rob
        rob2rs_packet_in.rob_entry = 1;
        rob2rs_packet_in.rs1_value = 0;
        rob2rs_packet_in.rs2_value = 0;
        //clear
        clear = 0;
        @(negedge clock);
        assert(busy == 1) else $display("@@@FAILED@@@");
        assert(ready == 1) else $display("@@@FAILED@@@");
        assert(entry_packet.inst.inst == 32'hABCDEF12) else $display("@@@FAILED@@@");
        check_id_packet(1,1,1,1);
        enable = 0;

        @(negedge clock);
        assert(busy == 1) else $display("@@@FAILED@@@");
        assert(entry_packet.inst.inst == 32'hABCDEF12) else $display("@@@FAILED@@@");
        check_id_packet(1,1,1,1);

        clear = 1;
        @(negedge clock);
        assert(busy == 0) else $display("@@@FAILED@@@");

         //inst2
        enable = 1;
        //id
        give_id_message();
        id_packet_in.rs1_value = 2;
        id_packet_in.rs2_value = 2;

        //mt
        mt2rs_packet_in.rs1_tag = 1;  // t1 t2 is blank, v1 v2 in rob
        mt2rs_packet_in.rs2_tag = 1;
        mt2rs_packet_in.rs1_ready = 1;
        mt2rs_packet_in.rs2_ready = 1;
        //cdb
        cdb_packet_in.reg_tag = 0;
        cdb_packet_in.reg_value = 0;
        //rob
        rob2rs_packet_in.rob_entry = 2;
        rob2rs_packet_in.rs1_value = 0;
        rob2rs_packet_in.rs2_value = 0;
        //clear
        clear = 0;
        @(negedge clock);
        $display("rs1 = %32b", entry_packet.rs1_value);
        $display("rs2 = %32b", entry_packet.rs2_value);
        assert(busy == 1) else $display("@@@FAILED@@@");
        assert(ready == 1) else $display("@@@FAILED@@@");
        check_id_packet(1,1,0,0);

        enable = 0;

        @(negedge clock);
        assert(busy == 1) else $display("@@@FAILED@@@");
        check_id_packet(1,1,0,0);
        clear = 1;
        @(negedge clock);
        assert(busy == 0) else $display("@@@FAILED@@@");
        @(negedge clock);


        //inst3
        enable = 1;
        //id
        give_id_message();
        id_packet_in.inst.inst = 32'hABCDEF12;
        id_packet_in.rs1_value = 3;
        id_packet_in.rs2_value = 3;
        //mt
        mt2rs_packet_in.rs1_tag = 1;  // t1 t2 is waiting
        mt2rs_packet_in.rs2_tag = 1;
        mt2rs_packet_in.rs1_ready = 0;
        mt2rs_packet_in.rs2_ready = 0;
        //cdb
        cdb_packet_in.reg_tag = 0;
        cdb_packet_in.reg_value = 0;
        //rob
        rob2rs_packet_in.rob_entry = 3;
        rob2rs_packet_in.rs1_value = 0;
        rob2rs_packet_in.rs2_value = 0;
        //clear
        clear = 0;

        @(negedge clock);
        assert(busy == 1) else $display("@@@FAILED@@@");
        assert(ready == 0) else $display("@@@FAILED@@@");
        $display("rs1 = %32b", entry_packet.rs1_value);
        $display("rs2 = %32b", entry_packet.rs2_value);
        check_id_packet(1,0,3,3);
        enable = 0;
        cdb_packet_in.reg_tag = 1;
        cdb_packet_in.reg_value = 1;

        @(negedge clock);
        assert(busy == 1) else $display("@@@FAILED@@@");
        assert(ready == 1) else $display("@@@FAILED@@@");
        assert(entry_packet.inst.inst == 32'hABCDEF12) else $display("@@@FAILED@@@");
        check_id_packet(1,1,1,1);
        clear = 1;
        cdb_packet_in.reg_tag = 0;
        cdb_packet_in.reg_value = 0;

        @(negedge clock);
        assert(busy == 0) else $display("@@@FAILED@@@");
        @(negedge clock);


        //inst4
        enable = 1;
        //id
        give_id_message();
        id_packet_in.rs1_value = 4;
        id_packet_in.rs2_value = 4;

        //mt
        mt2rs_packet_in.rs1_tag = 1;  // t1 t2 is waiting
        mt2rs_packet_in.rs2_tag = 1;
        mt2rs_packet_in.rs1_ready = 0;
        mt2rs_packet_in.rs2_ready = 0;
        //cdb
        cdb_packet_in.reg_tag = 0;
        cdb_packet_in.reg_value = 0;
        //rob
        rob2rs_packet_in.rob_entry = 4;
        rob2rs_packet_in.rs1_value = 0;
        rob2rs_packet_in.rs2_value = 0;
        //clear
        clear = 0;

        @(negedge clock);
        assert(busy == 1) else $display("@@@FAILED@@@");
        assert(ready == 0) else $display("@@@FAILED@@@");
        check_id_packet(1,0,4,4);


        @(negedge clock);
        assert(busy == 1) else $display("@@@FAILED@@@");
        assert(ready == 0) else $display("@@@FAILED@@@");
        check_id_packet(1,0,4,4);
        enable = 0;
        cdb_packet_in.reg_tag = 1;
        cdb_packet_in.reg_value = 1;

        @(negedge clock);
        assert(busy == 1) else $display("@@@FAILED@@@");
        assert(ready == 1) else $display("@@@FAILED@@@");
        check_id_packet(1,1,1,1);
        clear = 1;
        cdb_packet_in.reg_tag = 0;
        cdb_packet_in.reg_value = 0;

        @(negedge clock);
        assert(busy == 0) else $display("@@@FAILED@@@");
        @(negedge clock);


        // tight test
        //inst5 
        enable = 1;
        //id
        give_id_message();
        id_packet_in.rs1_value = 5;
        id_packet_in.rs2_value = 5;

        //mt
        mt2rs_packet_in.rs1_tag = 0; // reg file
        mt2rs_packet_in.rs2_tag = 0;
        mt2rs_packet_in.rs1_ready = 0;
        mt2rs_packet_in.rs2_ready = 0;
        //cdb
        cdb_packet_in.reg_tag = 0;
        cdb_packet_in.reg_value = 0;
        //rob
        rob2rs_packet_in.rob_entry = 5;
        rob2rs_packet_in.rs1_value = 0;
        rob2rs_packet_in.rs2_value = 0;
        //clear
        clear = 0;
        @(negedge clock);
        assert(busy == 1) else $display("@@@FAILED@@@");
        assert(ready == 1) else $display("@@@FAILED@@@");
        check_id_packet(1,1,5,5);
        enable = 0;

        @(negedge clock);
        assert(busy == 1) else $display("@@@FAILED@@@");
        check_id_packet(1,1,5,5);
        clear = 1;

        //inst6
        enable = 1;
        //id
        give_id_message();
        id_packet_in.rs1_value = 6;
        id_packet_in.rs2_value = 6;

        //mt
        mt2rs_packet_in.rs1_tag = 1;  // t1 t2 is blank, v1 v2 in rob
        mt2rs_packet_in.rs2_tag = 1;
        mt2rs_packet_in.rs1_ready = 1;
        mt2rs_packet_in.rs2_ready = 1;
        //cdb
        cdb_packet_in.reg_tag = 0;
        cdb_packet_in.reg_value = 0;
        //rob
        rob2rs_packet_in.rob_entry = 6;
        rob2rs_packet_in.rs1_value = 16;
        rob2rs_packet_in.rs2_value = 16;
        //clear
        @(negedge clock);
        assert(busy == 1) else $display("@@@FAILED@@@");
        check_id_packet(1,1,16,16);

        clear = 0;

        
        @(negedge clock);
        assert(busy == 1) else $display("@@@FAILED@@@");
        assert(ready == 1) else $display("@@@FAILED@@@");
        check_id_packet(1,1,16,16);
        enable = 0;

        @(negedge clock);
        assert(busy == 1) else $display("@@@FAILED@@@");
        check_id_packet(1,1,16,16);
        clear = 1;
        @(negedge clock);
        assert(busy == 0) else $display("@@@FAILED@@@");
        @(negedge clock);


        //inst7
        enable = 1;
        //id
        give_id_message();
        id_packet_in.rs1_value = 7;
        id_packet_in.rs2_value = 7;
        //mt
        mt2rs_packet_in.rs1_tag = 2; // one tag
        mt2rs_packet_in.rs2_tag = 3;
        mt2rs_packet_in.rs1_ready = 0;
        mt2rs_packet_in.rs2_ready = 1;
        //cdb
        cdb_packet_in.reg_tag = 0;
        cdb_packet_in.reg_value = 0;
        //rob
        rob2rs_packet_in.rob_entry = 7;
        rob2rs_packet_in.rs1_value = 0;
        rob2rs_packet_in.rs2_value = 0;
        //clear
        clear = 0;
        @(negedge clock);
        assert(busy == 1) else $display("@@@FAILED@@@");
        assert(ready == 0) else $display("@@@FAILED@@@");
        check_id_packet(1,0,7,0);
        enable = 0;
        @(negedge clock);
        cdb_packet_in.reg_tag = 2;
        cdb_packet_in.reg_value = 10;

        @(negedge clock);
        assert(busy == 1) else $display("@@@FAILED@@@");
        assert(ready == 1) else $display("@@@FAILED@@@");
        check_id_packet(1,1,10,0);
        clear = 1;
        @(negedge clock);
        assert(busy == 0) else $display("@@@FAILED@@@");

         //inst8
        enable = 1;
        //id
        give_id_message();
        id_packet_in.rs1_value = 8;
        id_packet_in.rs2_value = 8;
        //mt
        mt2rs_packet_in.rs1_tag = 3;  // t1 t2 is blank, v1 v2 in rob
        mt2rs_packet_in.rs2_tag = 4;
        mt2rs_packet_in.rs1_ready = 0;
        mt2rs_packet_in.rs2_ready = 0;
        //cdb
        cdb_packet_in.reg_tag = 0;
        cdb_packet_in.reg_value = 0;
        //rob
        rob2rs_packet_in.rob_entry = 8;
        rob2rs_packet_in.rs1_value = 0;
        rob2rs_packet_in.rs2_value = 0;
        //clear
        clear = 0;
        @(negedge clock);
        assert(busy == 1) else $display("@@@FAILED@@@");
        assert(ready == 0) else $display("@@@FAILED@@@");
        check_id_packet(1,0,8,8);
        enable = 0;
        cdb_packet_in.reg_tag = 4;
        cdb_packet_in.reg_value = 10;
        @(negedge clock);
        assert(busy == 1) else $display("@@@FAILED@@@");
        assert(ready == 0) else $display("@@@FAILED@@@");
        check_id_packet(1,0,8,10);
        cdb_packet_in.reg_tag = 3;
        cdb_packet_in.reg_value = 10;
        @(negedge clock);
        assert(busy == 1) else $display("@@@FAILED@@@");
        assert(ready == 1) else $display("@@@FAILED@@@");
        check_id_packet(1,1,10,10);
        clear = 1;
        @(negedge clock);
        assert(busy == 0) else $display("@@@FAILED@@@");

        $display("@@@PASSED@@@");
        $finish;
    end

endmodule