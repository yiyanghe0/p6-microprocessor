module testbench_RS;
    logic clock;
    logic reset;
    ID_PACKET id_packet_in; // invalid if enable = 0
    MT2RS_PACKET mt2rs_packet_in;
    CDB_PACKET cdb_packet_in; 
    ROB2RS_PACKET rob2rs_packet_in; // invalid if enable = 0
    logic [`RS_LEN-1:0] rs_entry_clear_in;
    
    RS2ROB_PACKET rs2rob_packet_out;
    RS2MT_PACKET rs2mt_packet_out;
    IS_PACKET is_packet_out;

    logic [`RS_LEN-1:0] rs_entry_clear_out; 
    logic [`RS_LEN-1:0] rs_entry_enable; 
    logic [`RS_LEN-1:0] rs_entry_busy;
    logic [`RS_LEN-1:0] rs_entry_ready; 

    IS_PACKET [`RS_LEN-1:0] rs_entry_packet_out;

    logic valid; // if valid = 0, rs encountered structural hazard and has to stall



    RS Big_RS(
        .clock(clock),
        .reset(reset),
        .id_packet_in(id_packet_in),
        .rob2rs_packet_in(rob2rs_packet_in),
        .mt2rs_packet_in(mt2rs_packet_in),
        .cdb_packet_in(cdb_packet_in),
        .rs_entry_clear_in(rs_entry_clear_in),


        .rs2rob_packet_out(rs2rob_packet_out),
        .rs2mt_packet_out(rs2mt_packet_out),
        .is_packet_out(is_packet_out),
        .rs_entry_clear_out(rs_entry_clear_out)
    );
    

    always begin
        #5;
        clock = ~clock;
    end

    //i1: add r1 r1 f1
    //i2: add r2 r2 f2
    //i3: add r3 r3 f3

//1

    initial begin
        //$monitor("TIME:%4.0f busy:%b ready:%b rs1_tag:%h rs2_tag:%h", $time, busy, ready, DUT_rs_entry.next_entry_rs1_tag, DUT_rs_entry.next_entry_rs2_tag);
        clock = 0;
        reset = 1;
        @(negedge clock);
        reset = 0;


        rs_entry_clear_in[0] = 1'b0;
        //inst1 
        //id
        id_packet_in.inst.inst = 32'hABCDEF12;
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
        rob2rs_packet_in.rob_entry = 1;
        rob2rs_packet_in.rs1_value = 0;
        rob2rs_packet_in.rs2_value = 0;
        rob2rs_packet_in.rob_head_idx = 1;

        @(negedge clock);
     //   $display("if correct: %8h",Big_RS.issue_inst_rob_entry);
      //  $display("if correct entry: %8h",Big_RS.issue_candidate_rob_entry);

        assert(is_packet_out.inst.inst == 32'hABCDEF12) else $display ("@@@FAILED@@@");
        rs_entry_clear_in[0] = 1;
     //   $display("if correct: %8h",Big_RS.issue_inst_rob_entry);
     //   $display("if correct: %8h",Big_RS.rs_entry_rob_entry[0]);
    //    $display("if correct: %8h",Big_RS.rs_entry_rob_entry[1]);

    //    $display("is_packet_out.inst.inst: %h",is_packet_out.inst.inst);
    //    $display("is_packet_IN.inst.inst: %h",id_packet_in.inst.inst);
       // $display("ready: %h",Big_RS.rs_entry_ready[0]);

        @(negedge clock);
        rs_entry_clear_in[0] = 0;
        $display("busy: %h",Big_RS.rs_entry_busy[0]);
        $display("enable: %h",Big_RS.rs_entry_enable[0]);


//#2
        @(negedge clock);
        //test INST
        id_packet_in.inst.inst = 32'hABC45F12;

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
        rob2rs_packet_in.rob_head_idx = 1;
        rob2rs_packet_in.rob_entry = 2;
        rob2rs_packet_in.rs1_value = 0;
        rob2rs_packet_in.rs2_value = 0;

        $display("busy: %h",Big_RS.rs_entry_busy[0]);

      //  assert(Big_RS.rs_entry_enable[0] == 1) else $display ("@@@FAILED@@@");

        @(negedge clock);


        assert(is_packet_out.inst.inst == 32'hABC45F12) else $display ("@@@FAILED@@@");
         $display("is_packet_out.inst.inst: %h",is_packet_out.inst.inst);

        $display("@@@PASSED@@@");
    end

endmodule