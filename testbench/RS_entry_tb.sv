

module testbench_rs_entry;
    logic clock;
    logic reset;
    ID_PACKET id_packet_in; // invalid if enable = 0
    MT2RS_PACKET mt2rs_packet_in; // invalid if enable = 0
    CDB_PACKET cdb_packet_in; 
    ROB2RS_PACKET rob2rs_packet_in; // invalid if enable = 0
    logic clear;
    logic enable;

    IS_PACKET is_packet_out;
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
        .entry_packet(is_packet_out),
        .busy(busy),
        .ready(ready)

    );

    always begin
        #5;
        clock = ~clock;
    end

    //i1: add r1 r1 f1
    //i2: add r2 r2 f2
    //i3: add r3 r3 f3

    initial begin
        $monitor("TIME:%4.0f busy:%b ready:%b", $time, busy, ready);
        clock = 0;
        reset = 1;
        @(negedge clock);
        reset = 0;
        //inst1 
        enable = 1;
        //id
        id_packet_in.rs1_value = 1;  
        id_packet_in.rs2_value = 1;  
        id_packet_in.dest_reg_idx = 1;
        id_packet_in.inst.inst = 32'hABCDEF12;
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
        assert(is_packet_out.inst.inst == 32'hABCDEF12) else $display("@@@FAILED@@@");
        enable = 0;

        @(negedge clock);
        assert(busy == 1) else $display("@@@FAILED@@@");
        assert(is_packet_out.inst.inst == 32'hABCDEF12) else $display("@@@FAILED@@@");
        clear = 1;
        @(negedge clock);
        assert(busy == 0) else $display("@@@FAILED@@@");

         //inst2
        enable = 1;
        //id
        id_packet_in.rs1_value = 2;
        id_packet_in.rs2_value = 2;
        id_packet_in.dest_reg_idx = 2;
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
        assert(busy == 1) else $display("@@@FAILED@@@");
        assert(ready == 1) else $display("@@@FAILED@@@");
        enable = 0;

        @(negedge clock);
        assert(busy == 1) else $display("@@@FAILED@@@");
        clear = 1;
        @(negedge clock);
        assert(busy == 0) else $display("@@@FAILED@@@");
        @(negedge clock);


        //inst3
        enable = 1;
        //id
        id_packet_in.rs1_value = 3;
        id_packet_in.rs2_value = 3;
        id_packet_in.dest_reg_idx = 3;
        id_packet_in.inst.inst = 32'hABCDEF12;
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
        enable = 0;
        cdb_packet_in.reg_tag = 1;
        cdb_packet_in.reg_value = 1;

        @(negedge clock);
        assert(busy == 1) else $display("@@@FAILED@@@");
        assert(ready == 1) else $display("@@@FAILED@@@");
        assert(is_packet_out.inst.inst == 32'hABCDEF12) else $display("@@@FAILED@@@");
        clear = 1;
        cdb_packet_in.reg_tag = 0;
        cdb_packet_in.reg_value = 0;

        @(negedge clock);
        assert(busy == 0) else $display("@@@FAILED@@@");
        @(negedge clock);


        //inst4
        enable = 1;
        //id
        id_packet_in.rs1_value = 3;
        id_packet_in.rs2_value = 3;
        id_packet_in.dest_reg_idx = 3;
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

        @(negedge clock);
        assert(busy == 1) else $display("@@@FAILED@@@");
        assert(ready == 0) else $display("@@@FAILED@@@");
        enable = 0;
        cdb_packet_in.reg_tag = 1;
        cdb_packet_in.reg_value = 1;

        @(negedge clock);
        assert(busy == 1) else $display("@@@FAILED@@@");
        assert(ready == 1) else $display("@@@FAILED@@@");
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
        id_packet_in.rs1_value = 1;  
        id_packet_in.rs2_value = 1;  
        id_packet_in.dest_reg_idx = 1;
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
        enable = 0;

        @(negedge clock);
        assert(busy == 1) else $display("@@@FAILED@@@");
        clear = 1;

        //inst6
        enable = 1;
        //id
        id_packet_in.rs1_value = 2;
        id_packet_in.rs2_value = 2;
        id_packet_in.dest_reg_idx = 2;
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
        rob2rs_packet_in.rs1_value = 0;
        rob2rs_packet_in.rs2_value = 0;
        //clear
        @(negedge clock);
        assert(busy == 1) else $display("@@@FAILED@@@");
        clear = 0;

        
        @(negedge clock);
        assert(busy == 1) else $display("@@@FAILED@@@");
        assert(ready == 1) else $display("@@@FAILED@@@");
        enable = 0;

        @(negedge clock);
        assert(busy == 1) else $display("@@@FAILED@@@");
        clear = 1;
        @(negedge clock);
        assert(busy == 0) else $display("@@@FAILED@@@");
        @(negedge clock);


        //inst7
        enable = 1;
        //id
        id_packet_in.rs1_value = 1;  
        id_packet_in.rs2_value = 1;  
        id_packet_in.dest_reg_idx = 1;
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
        enable = 0;
        @(negedge clock);
        cdb_packet_in.reg_tag = 2;
        cdb_packet_in.reg_value = 10;

        @(negedge clock);
        assert(busy == 1) else $display("@@@FAILED@@@");
        assert(ready == 1) else $display("@@@FAILED@@@");
        clear = 1;
        @(negedge clock);
        assert(busy == 0) else $display("@@@FAILED@@@");

         //inst8
        enable = 1;
        //id
        id_packet_in.rs1_value = 2;
        id_packet_in.rs2_value = 2;
        id_packet_in.dest_reg_idx = 3;
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
        enable = 0;
        cdb_packet_in.reg_tag = 4;
        cdb_packet_in.reg_value = 10;
        @(negedge clock);
        assert(busy == 1) else $display("@@@FAILED@@@");
        assert(ready == 0) else $display("@@@FAILED@@@");
        cdb_packet_in.reg_tag = 3;
        cdb_packet_in.reg_value = 10;
        @(negedge clock);
        assert(busy == 1) else $display("@@@FAILED@@@");
        assert(ready == 1) else $display("@@@FAILED@@@");
        clear = 1;
        @(negedge clock);
        assert(busy == 0) else $display("@@@FAILED@@@");

        $display("@@@PASSED@@@");
        $finish;
    end

endmodule