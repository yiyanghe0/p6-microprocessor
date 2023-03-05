`timescale 1ns/100ps

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
        .enable(enable),
        .is_packet_out(is_packet_out),
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
        //mt
        mt2rs_packet_in.rs1_tag = 0;
        mt2rs_packet_in.rs2_tag = 0;
        mt2rs_packet_in.rs1_ready = 0;
        mt2rs_packet_in.rs2_ready = 0;
        //cdb
        cdb_packet_in.reg_tag = 0;
        cdb_packet_in.reg_value = 0;
        //rob
        rob2rs_packet_in.rob_entry = 1;
        rob2rs_packet_in.rob_head_idx = 1;
        rob2rs_packet_in.rs1_value = 0;
        rob2rs_packet_in.rs2_value = 0;
        //clear
        clear = 0;

        @(negedge clock);
        enable = 0;

        @(negedge clock);
        clear = 1;

        @(negedge clock);
        //inst2
        enable = 1;
        //id
        id_packet_in.rs1_value = 0;
        id_packet_in.rs2_value = 1;
        //mt
        mt2rs_packet_in.rs1_tag = 1;
        mt2rs_packet_in.rs2_tag = 1;
        mt2rs_packet_in.rs1_ready = 0;
        mt2rs_packet_in.rs2_ready = 0;
        //cdb
        cdb_packet_in.reg_tag = 0;
        cdb_packet_in.reg_value = 0;
        //rob
        rob2rs_packet_in.rob_entry = 2;
        rob2rs_packet_in.rob_head_idx = 2;
        rob2rs_packet_in.rs1_value = 0;
        rob2rs_packet_in.rs2_value = 0;
        //clear
        clear = 0;

        @(negedge clock);
        enable = 0;
        cdb_packet_in.reg_tag = 1;
        cdb_packet_in.reg_value = 10;

        @(negedge clock);
        clear = 1;

        @(negedge clock);
        //inst2
        enable = 1;
        //id
        id_packet_in.rs1_value = 0;
        id_packet_in.rs2_value = 1;
        //mt
        mt2rs_packet_in.rs1_tag = 2;
        mt2rs_packet_in.rs2_tag = 2;
        mt2rs_packet_in.rs1_ready = 1;
        mt2rs_packet_in.rs2_ready = 1;
        //cdb
        cdb_packet_in.reg_tag = 0;
        cdb_packet_in.reg_value = 0;
        //rob
        rob2rs_packet_in.rob_entry = 3;
        rob2rs_packet_in.rob_head_idx = 3;
        rob2rs_packet_in.rs1_value = 5;
        rob2rs_packet_in.rs2_value = 5;
        //clear
        clear = 0;

        @(negedge clock);
        enable = 0;
        cdb_packet_in.reg_tag = 1;
        cdb_packet_in.reg_value = 10;

        @(negedge clock);
        clear = 1;
    end

endmodule