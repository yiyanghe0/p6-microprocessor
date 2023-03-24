`define DEBUG
module testbench_RS;
    logic clock;
    logic reset;
    logic squash;
    logic stall;
    ID_PACKET id_packet_in; // invalid if enable = 0
    MT2RS_PACKET mt2rs_packet_in;
    CDB_PACKET cdb_packet_in; 
    ROB2RS_PACKET rob2rs_packet_in; // invalid if enable = 0
    
    RS2ROB_PACKET rs2rob_packet_out;
    RS2MT_PACKET rs2mt_packet_out;
    IS_PACKET is_packet_out;

    logic [`RS_LEN-1:0] rs_entry_clear;

    logic [`RS_LEN-1:0] rs_entry_enable; 
    logic [`RS_LEN-1:0] rs_entry_busy;
    logic [`RS_LEN-1:0] rs_entry_ready;

    logic [$clog2(`RS_LEN)-1:0] issue_inst_rs_entry;
    logic [`ROB_LEN-1:0] issue_candidate_rob_entry; // one-hot encoding of rs_entry_packet_out.dest_reg_idx
    logic [`ROB_LEN-1:0] issue_inst_rob_entry; // one-hot encoding of rob_entry of the inst issued

    logic [`RS_LEN-1:0][`ROB_LEN-1:0] rs_entry_rob_entry;

    IS_PACKET [`RS_LEN-1:0] rs_entry_packet_out;

    logic valid; // if valid = 0, rs encountered structural hazard and has to stall

    TAG_PACKET [`RS_LEN-1:0] entry_rs1_tags;
    TAG_PACKET [`RS_LEN-1:0] entry_rs2_tags;

    logic rs_valid;

    RS Big_RS(
        .clock(clock),
        .reset(reset),
        .squash(squash),
        .stall(stall),
        .id_packet_in(id_packet_in),
        .rob2rs_packet_in(rob2rs_packet_in),
        .mt2rs_packet_in(mt2rs_packet_in),
        .cdb_packet_in(cdb_packet_in),
        
        `ifdef DEBUG
        .rs_entry_enable(rs_entry_enable),
        .rs_entry_busy(rs_entry_busy),
        .rs_entry_ready(rs_entry_ready),

        .issue_inst_rs_entry(issue_inst_rs_entry),
        .issue_candidate_rob_entry(issue_candidate_rob_entry), // one-hot encoding of rs_entry_packet_out.dest_reg_idx
        .issue_inst_rob_entry(issue_inst_rob_entry), // one-hot encoding of rob_entry of the inst issued

        .rs_entry_rob_entry(rs_entry_rob_entry),

        .rs_entry_packet_out(rs_entry_packet_out),

        .rs_entry_clear(rs_entry_clear),

        .entry_rs1_tags(entry_rs1_tags),
        .entry_rs2_tags(entry_rs2_tags),
        `endif 

        .rs2rob_packet_out(rs2rob_packet_out),
        .rs2mt_packet_out(rs2mt_packet_out),
        .is_packet_out(is_packet_out),

        .valid(rs_valid)
    );

    task exit_on_error;
        input [`XLEN-1:0] correct_inst;
        input [`XLEN-1:0] correct_rs1_value;
        input [`XLEN-1:0] correct_rs2_value;

        begin
            $display("@@@ Incorrect at time %4.0f", $time);
            $display("@@@ Expected inst: %h; Actual issued inst: %h", correct_inst, is_packet_out.inst.inst);
            $display("@@@ Expected rs1 value: %d; Actual rs1 value: %d", correct_rs1_value, is_packet_out.rs1_value);
            $display("@@@ Expected rs2 value: %d; Actual rs2 value: %d", correct_rs2_value, is_packet_out.rs2_value);
            $display("@@@ ----------------------------------------- @@@");
            $display("@@@ Current RS status:");
            $display("@@@ | RS Index | Wr_en | Busy |   Inst   | Ready | Clear | Tag1 | Tag2 |");

            for (int i = 0; i < `RS_LEN; i++) begin
                $display("@@@ |   [%1d]    |   %b   |  %b   | %h |   %b   |   %b   | %b  | %b  |",
                         i, rs_entry_enable[i], rs_entry_busy[i], rs_entry_packet_out[i].inst.inst, rs_entry_ready[i], rs_entry_clear[i], entry_rs1_tags[i].tag, entry_rs2_tags[i].tag);
            end

            $display("@@@failed");
            $finish;
        end
    endtask

    task check_func;
        input [`XLEN-1:0] correct_inst;
        input [`XLEN-1:0] correct_rs1_value;
        input [`XLEN-1:0] correct_rs2_value;

        begin 
            #1 assert (is_packet_out.inst.inst == correct_inst)                else exit_on_error(correct_inst,correct_rs1_value, correct_rs2_value);
            assert (is_packet_out.rs1_value == correct_rs1_value)           else exit_on_error(correct_inst,correct_rs1_value, correct_rs2_value);
            assert (is_packet_out.rs2_value == correct_rs2_value)           else exit_on_error(correct_inst,correct_rs1_value, correct_rs2_value);
        end
    endtask

    always begin
        #5;
        clock = ~clock;
    end

    initial begin
        //$monitor("TIME:%4.0f busy:%b ready:%b rs1_tag:%h rs2_tag:%h", $time, busy, ready, DUT_rs_entry.next_entry_rs1_tag, DUT_rs_entry.next_entry_rs2_tag);
        $monitor("TIME:%4.0f busy:%8b ready:%8b enable:%8b issue_inst:%8b", $time, rs_entry_busy, rs_entry_ready, rs_entry_enable, issue_inst_rob_entry);
        clock = 0;
        reset = 1;
        squash = 0;
        stall = 0;
        @(negedge clock);
        reset = 0;

// #1 case: ready - both in reg file
        id_packet_in.inst.inst = 32'hABCDEF12;
        id_packet_in.rs1_value = 1;  
        id_packet_in.rs2_value = 1;  
        id_packet_in.dest_reg_idx = 1;

        //mt
        mt2rs_packet_in.rs1_tag.tag = 0; // reg file
        mt2rs_packet_in.rs2_tag.tag = 0;
        mt2rs_packet_in.rs1_tag.valid = 0; // reg file
        mt2rs_packet_in.rs2_tag.valid = 0;
        mt2rs_packet_in.rs1_ready = 0;
        mt2rs_packet_in.rs2_ready = 0;

        //cdb
        cdb_packet_in.reg_tag.tag = 0;
        cdb_packet_in.reg_tag.valid = 0;
        cdb_packet_in.reg_value = 0;

        //rob
        rob2rs_packet_in.rob_entry = 1;
        rob2rs_packet_in.rs1_value = 0;
        rob2rs_packet_in.rs2_value = 0;
        rob2rs_packet_in.rob_head_idx = 1;

        // #1 $display("1st instr inputted");

        // $display("@@@ | RS Index | Wr_en | Busy |   Inst   | Ready | Clear | Tag1 | Tag2 |");
        // for (int i = 0; i < `RS_LEN; i++) begin
        //     $display("@@@ |   [%1d]    |   %b   |  %b   | %h |   %b   |   %b   | %b  | %b  |",
        //             i, rs_entry_enable[i], rs_entry_busy[i], rs_entry_packet_out[i].inst.inst, rs_entry_ready[i], rs_entry_clear[i], entry_rs1_tags[i], entry_rs2_tags[i]);
        // end

        @(negedge clock);
// #2 case: ready - both in rob
        id_packet_in.inst.inst = 32'hABC45F12;

        id_packet_in.rs1_value = 2;
        id_packet_in.rs2_value = 2;
        id_packet_in.dest_reg_idx = 2;
        //mt
        mt2rs_packet_in.rs1_tag.tag = 1;  // t1 t2 is blank, v1 v2 in rob
        mt2rs_packet_in.rs2_tag.tag = 1;
        mt2rs_packet_in.rs1_tag.valid = 1;  // t1 t2 is blank, v1 v2 in rob
        mt2rs_packet_in.rs2_tag.valid = 1;
        mt2rs_packet_in.rs1_ready = 1;
        mt2rs_packet_in.rs2_ready = 1;
        //cdb
        cdb_packet_in.reg_tag.tag = 0;
        cdb_packet_in.reg_tag.valid = 0;
        cdb_packet_in.reg_value = 0;
        //rob
        rob2rs_packet_in.rob_head_idx = 1;
        rob2rs_packet_in.rob_entry = 2;
        rob2rs_packet_in.rs1_value = 0;
        rob2rs_packet_in.rs2_value = 0;

        // #1 $display("2nd instr inputted");

        // $display("@@@ | RS Index | Wr_en | Busy |   Inst   | Ready | Clear | Tag1 | Tag2 |");
        // for (int i = 0; i < `RS_LEN; i++) begin
        //     $display("@@@ |   [%1d]    |   %b   |  %b   | %h |   %b   |   %b   | %b  | %b  |",
        //             i, rs_entry_enable[i], rs_entry_busy[i], rs_entry_packet_out[i].inst.inst, rs_entry_ready[i], rs_entry_clear[i], entry_rs1_tags[i], entry_rs2_tags[i]);
        // end

        check_func(32'hABCDEF12, 1, 1); // #1
        // assert(is_packet_out.inst.inst == 32'hABCDEF12) else $display ("@@@FAILED@@@"); //test #1
        // assert(is_packet_out.rs1_value == 1) else $display ("@@@FAILED@@@");
        // assert(is_packet_out.rs2_value == 1) else $display ("@@@FAILED@@@");

        @(negedge clock);
// #3 case: not ready - both with tag 1
        id_packet_in.inst.inst = 32'hab489F12;

        id_packet_in.rs1_value = 3;
        id_packet_in.rs2_value = 3;
        id_packet_in.dest_reg_idx = 3;
        //mt
        mt2rs_packet_in.rs1_tag.tag = 1;  // t1 t2 is waiting
        mt2rs_packet_in.rs2_tag.tag = 1;
        mt2rs_packet_in.rs1_tag.valid = 1;  // t1 t2 is waiting
        mt2rs_packet_in.rs2_tag.valid = 1;
        mt2rs_packet_in.rs1_ready = 0;
        mt2rs_packet_in.rs2_ready = 0;
        //cdb
        cdb_packet_in.reg_tag.tag = 0;
        cdb_packet_in.reg_tag.valid = 0;
        cdb_packet_in.reg_value = 0;
        //rob
        rob2rs_packet_in.rob_head_idx = 1;
        rob2rs_packet_in.rob_entry = 3;
        rob2rs_packet_in.rs1_value = 0;
        rob2rs_packet_in.rs2_value = 0;

        // #1 $display("3rd instr inputted");

        // $display("@@@ | RS Index | Wr_en | Busy |   Inst   | Ready | Clear | Tag1 | Tag2 |");
        // for (int i = 0; i < `RS_LEN; i++) begin
        //     $display("@@@ |   [%1d]    |   %b   |  %b   | %h |   %b   |   %b   | %b  | %b  |",
        //             i, rs_entry_enable[i], rs_entry_busy[i], rs_entry_packet_out[i].inst.inst, rs_entry_ready[i], rs_entry_clear[i], entry_rs1_tags[i], entry_rs2_tags[i]);
        // end

        check_func(32'hABC45F12, 0, 0); // #2
        // assert(is_packet_out.inst.inst == 32'hABC45F12) else $display ("@@@FAILED@@@");  //test #2
        // assert(is_packet_out.rs1_value == 0) else $display ("@@@FAILED@@@");
        // assert(is_packet_out.rs2_value == 0) else $display ("@@@FAILED@@@");

        @(negedge clock);
// #4 case: ready - both in rob
// tag 1 ready with cdb broadcast -> #3 ready
        id_packet_in.inst.inst = 32'h00000000;

        id_packet_in.rs1_value = 3;
        id_packet_in.rs2_value = 3;
        id_packet_in.dest_reg_idx = 4;
        //mt
        mt2rs_packet_in.rs1_tag.tag = 3;
        mt2rs_packet_in.rs2_tag.tag = 3;
        mt2rs_packet_in.rs1_tag.valid = 1;
        mt2rs_packet_in.rs2_tag.valid = 1;
        mt2rs_packet_in.rs1_ready = 1;
        mt2rs_packet_in.rs2_ready = 1;
        //cdb
        cdb_packet_in.reg_tag.tag = 1;
        cdb_packet_in.reg_tag.valid = 1;
        cdb_packet_in.reg_value = 20;
        //rob
        rob2rs_packet_in.rob_head_idx = 1;
        rob2rs_packet_in.rob_entry = 3;
        rob2rs_packet_in.rs1_value = 0;
        rob2rs_packet_in.rs2_value = 0;

        // #1 $display("4th instr inputted");

        // $display("@@@ | RS Index | Wr_en | Busy |   Inst   | Ready | Clear | Tag1 | Tag2 |");
        // for (int i = 0; i < `RS_LEN; i++) begin
        //     $display("@@@ |   [%1d]    |   %b   |  %b   | %h |   %b   |   %b   | %b  | %b  |",
        //             i, rs_entry_enable[i], rs_entry_busy[i], rs_entry_packet_out[i].inst.inst, rs_entry_ready[i], rs_entry_clear[i], entry_rs1_tags[i], entry_rs2_tags[i]);
        // end

        check_func(32'hab489F12, 20, 20); // #3
        // assert(is_packet_out.inst.inst == 32'hab489F12) else $display ("@@@FAILED@@@");  //test #3
        // assert(is_packet_out.rs1_value == 20) else $display ("@@@FAILED@@@");
        // assert(is_packet_out.rs2_value == 20) else $display ("@@@FAILED@@@");

        @(negedge clock);    
// #5 case: not ready - rs1 with tag3, rs2 with tag2
        //test inst
        id_packet_in.inst.inst = 32'hab22cF12;
        //id
        id_packet_in.rs1_value = 2;
        id_packet_in.rs2_value = 2;
        id_packet_in.dest_reg_idx = 2;
        //mt
        mt2rs_packet_in.rs1_tag.tag = 3;  // t1 t2 is blank, v1 v2 in rob
        mt2rs_packet_in.rs2_tag.tag = 2;
        mt2rs_packet_in.rs1_tag.valid = 1;  // t1 t2 is blank, v1 v2 in rob
        mt2rs_packet_in.rs2_tag.valid = 1;
        mt2rs_packet_in.rs1_ready = 0;
        mt2rs_packet_in.rs2_ready = 0;
        //cdb
        cdb_packet_in.reg_tag.tag = 0;
        cdb_packet_in.reg_tag.valid = 0;
        cdb_packet_in.reg_value = 0;
        //rob
        rob2rs_packet_in.rob_head_idx = 1;
        rob2rs_packet_in.rob_entry = 4;
        rob2rs_packet_in.rs1_value = 0;
        rob2rs_packet_in.rs2_value = 0;

        // #1 $display("5th instr inputted");

        // $display("@@@ | RS Index | Wr_en | Busy |   Inst   | Ready | Clear | Tag1 | Tag2 |");
        // for (int i = 0; i < `RS_LEN; i++) begin
        //     $display("@@@ |   [%1d]    |   %b   |  %b   | %h |   %b   |   %b   | %b  | %b  |",
        //             i, rs_entry_enable[i], rs_entry_busy[i], rs_entry_packet_out[i].inst.inst, rs_entry_ready[i], rs_entry_clear[i], entry_rs1_tags[i], entry_rs2_tags[i]);
        // end

        check_func(32'h00000000, 0, 0); // #4
        // assert(is_packet_out.inst.inst == 32'h00000000) else $display ("@@@FAILED@@@");  //wait for inst #4
        // assert(is_packet_out.rs1_value == 0) else $display ("@@@FAILED@@@");
        // assert(is_packet_out.rs2_value == 0) else $display ("@@@FAILED@@@");

        @(negedge clock);
// #6 case: ready - both in reg file
// tag 3 ready with cdb broadcast
        //test inst
        id_packet_in.inst.inst = 32'ha12acF12;
        id_packet_in.rs1_value = 1;  
        id_packet_in.rs2_value = 1;  
        id_packet_in.dest_reg_idx = 1;
        //mt
        mt2rs_packet_in.rs1_tag.tag = 0; // reg file
        mt2rs_packet_in.rs2_tag.tag = 0;
        mt2rs_packet_in.rs1_tag.valid = 0; // reg file
        mt2rs_packet_in.rs2_tag.valid = 0;
        mt2rs_packet_in.rs1_ready = 0;
        mt2rs_packet_in.rs2_ready = 0;
        //cdb
        cdb_packet_in.reg_tag.tag = 3;   //broadcast reg1
        cdb_packet_in.reg_tag.valid = 1;
        cdb_packet_in.reg_value = 50;
        //rob
        rob2rs_packet_in.rob_head_idx = 1;
        rob2rs_packet_in.rob_entry = 5;
        rob2rs_packet_in.rs1_value = 0;
        rob2rs_packet_in.rs2_value = 0;

        // #1 $display("6th instr inputted");

        // $display("@@@ | RS Index | Wr_en | Busy |   Inst   | Ready | Clear | Tag1 | Tag2 |");
        // for (int i = 0; i < `RS_LEN; i++) begin
        //     $display("@@@ |   [%1d]    |   %b   |  %b   | %h |   %b   |   %b   | %b  | %b  |",
        //             i, rs_entry_enable[i], rs_entry_busy[i], rs_entry_packet_out[i].inst.inst, rs_entry_ready[i], rs_entry_clear[i], entry_rs1_tags[i], entry_rs2_tags[i]);
        // end
        
        @(negedge clock);
// #7 case: ready - rs1 in cdb, rs2 in rob
// tag 2 ready with cdb broadcast -> #5 ready
        id_packet_in.inst.inst = 32'hab2ccF12;
        id_packet_in.rs1_value = 1;  
        id_packet_in.rs2_value = 1;  
        id_packet_in.dest_reg_idx = 1;
        //mt
        mt2rs_packet_in.rs1_tag.tag = 2; // one tag
        mt2rs_packet_in.rs2_tag.tag = 3;
        mt2rs_packet_in.rs1_tag.valid = 1; // one tag
        mt2rs_packet_in.rs2_tag.valid = 1;
        mt2rs_packet_in.rs1_ready = 0;
        mt2rs_packet_in.rs2_ready = 1;
        //cdb
        cdb_packet_in.reg_tag.tag = 2;
        cdb_packet_in.reg_tag.valid = 1;
        cdb_packet_in.reg_value = 60;
        //rob
        rob2rs_packet_in.rob_head_idx = 1;
        rob2rs_packet_in.rob_entry = 6;
        rob2rs_packet_in.rs1_value = 0;
        rob2rs_packet_in.rs2_value = 0;

        // #1 $display("7th instr inputted");

        // $display("@@@ | RS Index | Wr_en | Busy |   Inst   | Ready | Clear | Tag1 | Tag2 |");
        // for (int i = 0; i < `RS_LEN; i++) begin
        //     $display("@@@ |   [%1d]    |   %b   |  %b   | %h |   %b   |   %b   | %b  | %b  |",
        //             i, rs_entry_enable[i], rs_entry_busy[i], rs_entry_packet_out[i].inst.inst, rs_entry_ready[i], rs_entry_clear[i], entry_rs1_tags[i], entry_rs2_tags[i]);
        // end

        check_func(32'hab22cF12, 50, 60); // #5
        // assert(is_packet_out.inst.inst == 32'hab22cF12) else $display ("@@@FAILED@@@");  //test inst5
        // assert(is_packet_out.rs1_value == 50) else $display ("@@@FAILED@@@");
        // assert(is_packet_out.rs2_value == 60) else $display ("@@@FAILED@@@");

        @(negedge clock);
// #8 case: ready - both in rob
        id_packet_in.inst.inst = 32'h00000000;

        id_packet_in.rs1_value = 3;
        id_packet_in.rs2_value = 3;
        id_packet_in.dest_reg_idx = 4;
        //mt
        mt2rs_packet_in.rs1_tag.tag = 3;
        mt2rs_packet_in.rs2_tag.tag = 3;
        mt2rs_packet_in.rs1_tag.valid = 1;
        mt2rs_packet_in.rs2_tag.valid = 1;
        mt2rs_packet_in.rs1_ready = 1;
        mt2rs_packet_in.rs2_ready = 1;
        //cdb
        cdb_packet_in.reg_tag.tag = 1;
        cdb_packet_in.reg_tag.valid = 1;
        cdb_packet_in.reg_value = 25;
        //rob
        rob2rs_packet_in.rob_head_idx = 1;
        rob2rs_packet_in.rob_entry = 7;
        rob2rs_packet_in.rs1_value = 0;
        rob2rs_packet_in.rs2_value = 0;

        // #1 $display("8th instr inputted");

        // $display("@@@ | RS Index | Wr_en | Busy |   Inst   | Ready | Clear | Tag1 | Tag2 |");
        // for (int i = 0; i < `RS_LEN; i++) begin
        //     $display("@@@ |   [%1d]    |   %b   |  %b   | %h |   %b   |   %b   | %b  | %b  |",
        //             i, rs_entry_enable[i], rs_entry_busy[i], rs_entry_packet_out[i].inst.inst, rs_entry_ready[i], rs_entry_clear[i], entry_rs1_tags[i], entry_rs2_tags[i]);
        // end

        check_func(32'ha12acF12, 1, 1); // #6
        // assert(is_packet_out.inst.inst == 32'ha12acF12) else $display ("@@@FAILED@@@");
        // assert(is_packet_out.rs1_value == 1) else $display ("@@@FAILED@@@");
        // assert(is_packet_out.rs2_value == 1) else $display ("@@@FAILED@@@"); 

        @(negedge clock);
        // $display("@@@ | RS Index | Wr_en | Busy |   Inst   | Ready | Clear | Tag1 | Tag2 |");
        // for (int i = 0; i < `RS_LEN; i++) begin
        //     $display("@@@ |   [%1d]    |   %b   |  %b   | %h |   %b   |   %b   | %b  | %b  |",
        //             i, rs_entry_enable[i], rs_entry_busy[i], rs_entry_packet_out[i].inst.inst, rs_entry_ready[i], rs_entry_clear[i], entry_rs1_tags[i], entry_rs2_tags[i]);
        // end

        check_func(32'hab2ccF12, 60, 0); // #7
        // assert(is_packet_out.inst.inst == 32'hab2ccF12) else $display ("@@@FAILED@@@");
        // assert(is_packet_out.rs1_value == 60) else $display ("@@@FAILED@@@");
        // assert(is_packet_out.rs2_value == 0) else $display ("@@@FAILED@@@");

        @(negedge clock);
        check_func(32'h00000000, 0, 0); // #8
        //rest and do the mass test
        reset = 1;

        @(negedge clock);
        reset = 0;

// mass inst1: not ready - rs1 with tag1, rs2 in rob
        id_packet_in.inst.inst = 32'h11111111;
        id_packet_in.rs1_value = 4;  
        id_packet_in.rs2_value = 1;  
        id_packet_in.dest_reg_idx = 1;
        //mt
        mt2rs_packet_in.rs1_tag.tag = 1; // one tag
        mt2rs_packet_in.rs2_tag.tag = 3;
        mt2rs_packet_in.rs1_tag.valid = 1; // one tag
        mt2rs_packet_in.rs2_tag.valid = 1;
        mt2rs_packet_in.rs1_ready = 0;
        mt2rs_packet_in.rs2_ready = 1;
        //cdb
        cdb_packet_in.reg_tag.tag = 0;
        cdb_packet_in.reg_tag.valid = 0;
        cdb_packet_in.reg_value = 0;
        //rob
        rob2rs_packet_in.rob_head_idx = 1;
        rob2rs_packet_in.rob_entry = 1;
        rob2rs_packet_in.rs1_value = 0;
        rob2rs_packet_in.rs2_value = 0;

        @(negedge clock);
//mass inst2: not ready - rs1 with tag1, rs2 in rob
        id_packet_in.inst.inst = 32'h22222222;
        id_packet_in.rs1_value = 2;  
        id_packet_in.rs2_value = 2;  
        id_packet_in.dest_reg_idx = 1;
        //mt
        mt2rs_packet_in.rs1_tag.tag = 1; // one tag
        mt2rs_packet_in.rs2_tag.tag = 3;
        mt2rs_packet_in.rs1_tag.valid = 1; // one tag
        mt2rs_packet_in.rs2_tag.valid = 1;
        mt2rs_packet_in.rs1_ready = 0;
        mt2rs_packet_in.rs2_ready = 1;
        //cdb
        cdb_packet_in.reg_tag.tag = 0;
        cdb_packet_in.reg_tag.valid = 0;
        cdb_packet_in.reg_value = 0;
        //rob
        rob2rs_packet_in.rob_head_idx = 1;
        rob2rs_packet_in.rob_entry = 1;
        rob2rs_packet_in.rs1_value = 0;
        rob2rs_packet_in.rs2_value = 32;

        @(negedge clock);
//mass inst3: not ready - rs1 in rob, rs2 with tag5
        id_packet_in.inst.inst = 32'h33333333;
        id_packet_in.rs1_value = 1;  
        id_packet_in.rs2_value = 1;  
        id_packet_in.dest_reg_idx = 1;
        //mt
        mt2rs_packet_in.rs1_tag.tag = 2; // one tag
        mt2rs_packet_in.rs2_tag.tag = 5;
        mt2rs_packet_in.rs1_tag.valid = 1; // one tag
        mt2rs_packet_in.rs2_tag.valid = 1;
        mt2rs_packet_in.rs1_ready = 1;
        mt2rs_packet_in.rs2_ready = 0;
        //cdb
        cdb_packet_in.reg_tag.tag = 0;
        cdb_packet_in.reg_tag.valid = 0;
        cdb_packet_in.reg_value = 0;
        //rob
        rob2rs_packet_in.rob_head_idx = 1;
        rob2rs_packet_in.rob_entry = 1;
        rob2rs_packet_in.rs1_value = 4;
        rob2rs_packet_in.rs2_value = 0;

        @(negedge clock);
//mass inst4: not ready - rs1 with tag2, rs2 in reg file
        id_packet_in.inst.inst = 32'h44444444;
        id_packet_in.rs1_value = 2;  
        id_packet_in.rs2_value = 2;  
        id_packet_in.dest_reg_idx = 1;
        //mt
        mt2rs_packet_in.rs1_tag.tag = 2; // one tag
        mt2rs_packet_in.rs2_tag.tag = 0;
        mt2rs_packet_in.rs1_tag.valid = 1; // one tag
        mt2rs_packet_in.rs2_tag.valid = 0;
        mt2rs_packet_in.rs1_ready = 0;
        mt2rs_packet_in.rs2_ready = 0;
        //cdb
        cdb_packet_in.reg_tag.tag = 0;
        cdb_packet_in.reg_tag.valid = 0;
        cdb_packet_in.reg_value = 0;
        //rob
        rob2rs_packet_in.rob_head_idx = 1;
        rob2rs_packet_in.rob_entry = 1;
        rob2rs_packet_in.rs1_value = 0;
        rob2rs_packet_in.rs2_value = 0;

        @(negedge clock);
//mass inst5: not ready - rs1 in reg file, rs2 with tag5
        id_packet_in.inst.inst = 32'h55555555;
        id_packet_in.rs1_value = 1;  
        id_packet_in.rs2_value = 1;  
        id_packet_in.dest_reg_idx = 1;
        //mt
        mt2rs_packet_in.rs1_tag.tag = 0; // one tag
        mt2rs_packet_in.rs2_tag.tag = 5;
        mt2rs_packet_in.rs1_tag.valid = 0; // one tag
        mt2rs_packet_in.rs2_tag.valid = 1;
        mt2rs_packet_in.rs1_ready = 0;
        mt2rs_packet_in.rs2_ready = 0;
        //cdb
        cdb_packet_in.reg_tag.tag = 0;
        cdb_packet_in.reg_tag.valid = 0;
        cdb_packet_in.reg_value = 0;
        //rob
        rob2rs_packet_in.rob_head_idx = 1;
        rob2rs_packet_in.rob_entry = 1;
        rob2rs_packet_in.rs1_value = 0;
        rob2rs_packet_in.rs2_value = 0;

        @(negedge clock);
//mass inst6: not ready - rs1 in rob, rs2 with tag3
        id_packet_in.inst.inst = 32'h66666666;
        id_packet_in.rs1_value = 2;  
        id_packet_in.rs2_value = 2;  
        id_packet_in.dest_reg_idx = 1;
        //mt
        mt2rs_packet_in.rs1_tag.tag = 6; // one tag
        mt2rs_packet_in.rs2_tag.tag = 3;
        mt2rs_packet_in.rs1_tag.valid = 1; // one tag
        mt2rs_packet_in.rs2_tag.valid = 1;
        mt2rs_packet_in.rs1_ready = 1;
        mt2rs_packet_in.rs2_ready = 0;
        //cdb
        cdb_packet_in.reg_tag.tag = 0;
        cdb_packet_in.reg_tag.valid = 0;
        cdb_packet_in.reg_value = 0;
        //rob
        rob2rs_packet_in.rob_head_idx = 1;
        rob2rs_packet_in.rob_entry = 1;
        rob2rs_packet_in.rs1_value = 5;
        rob2rs_packet_in.rs2_value = 0;

         @(negedge clock);
//mass inst7: not ready - rs1 with tag5, rs2 with tag1
        id_packet_in.inst.inst = 32'h77777777;
        id_packet_in.rs1_value = 1;  
        id_packet_in.rs2_value = 1;  
        id_packet_in.dest_reg_idx = 1;
        //mt
        mt2rs_packet_in.rs1_tag.tag = 5; // one tag
        mt2rs_packet_in.rs2_tag.tag = 1;
        mt2rs_packet_in.rs1_tag.valid = 1; // one tag
        mt2rs_packet_in.rs2_tag.valid = 1;
        mt2rs_packet_in.rs1_ready = 0;
        mt2rs_packet_in.rs2_ready = 0;
        //cdb
        cdb_packet_in.reg_tag.tag = 0;
        cdb_packet_in.reg_tag.valid = 0;
        cdb_packet_in.reg_value = 0;
        //rob
        rob2rs_packet_in.rob_head_idx = 1;
        rob2rs_packet_in.rob_entry = 1;
        rob2rs_packet_in.rs1_value = 0;
        rob2rs_packet_in.rs2_value = 0;

        @(negedge clock);
//mass inst8: not ready - rs1 with tag3, rs2 with tag6
        id_packet_in.inst.inst = 32'h88888888;
        id_packet_in.rs1_value = 5;  
        id_packet_in.rs2_value = 2;  
        id_packet_in.dest_reg_idx = 1;
        //mt
        mt2rs_packet_in.rs1_tag.tag = 3; // one tag
        mt2rs_packet_in.rs2_tag.tag = 6;
        mt2rs_packet_in.rs1_tag.valid = 1; // one tag
        mt2rs_packet_in.rs2_tag.valid = 1;
        mt2rs_packet_in.rs1_ready = 0;
        mt2rs_packet_in.rs2_ready = 0;
        //cdb
        cdb_packet_in.reg_tag.tag = 0;
        cdb_packet_in.reg_tag.valid = 0;
        cdb_packet_in.reg_value = 0;
        //rob
        rob2rs_packet_in.rob_head_idx = 1;
        rob2rs_packet_in.rob_entry = 1;
        rob2rs_packet_in.rs1_value = 0;
        rob2rs_packet_in.rs2_value = 0;

        // #1 $display("@@@ | RS Index | Wr_en | Busy |   Inst   | Ready | Clear | Tag1 | Tag2 |");
        // for (int i = 0; i < `RS_LEN; i++) begin
        //     $display("@@@ |   [%1d]    |   %b   |  %b   | %h |   %b   |   %b   | %b  | %b  |",
        //             i, rs_entry_enable[i], rs_entry_busy[i], rs_entry_packet_out[i].inst.inst, rs_entry_ready[i], rs_entry_clear[i], entry_rs1_tags[i], entry_rs2_tags[i]);
        // end

        @(negedge clock);
//mass inst9: !!!structural hazard!!! ready - both in rob
        id_packet_in.inst.inst = 32'h00000000;
        id_packet_in.rs1_value = 5;  
        id_packet_in.rs2_value = 2;  
        id_packet_in.dest_reg_idx = 1;
        //mt
        mt2rs_packet_in.rs1_tag.tag = 3; // one tag
        mt2rs_packet_in.rs2_tag.tag = 6;
        mt2rs_packet_in.rs1_tag.valid = 1; // one tag
        mt2rs_packet_in.rs2_tag.valid = 1;
        mt2rs_packet_in.rs1_ready = 1;
        mt2rs_packet_in.rs2_ready = 1;
        //cdb
        cdb_packet_in.reg_tag.tag = 0;
        cdb_packet_in.reg_tag.valid = 0;
        cdb_packet_in.reg_value = 0;
        //rob
        rob2rs_packet_in.rob_head_idx = 1;
        rob2rs_packet_in.rob_entry = 1;
        rob2rs_packet_in.rs1_value = 0;
        rob2rs_packet_in.rs2_value = 0;

        // #1 $display("@@@ | RS Index | Wr_en | Busy |   Inst   | Ready | Clear | Tag1 | Tag2 |");
        // for (int i = 0; i < `RS_LEN; i++) begin
        //     $display("@@@ |   [%1d]    |   %b   |  %b   | %h |   %b   |   %b   | %b  | %b  |",
        //             i, rs_entry_enable[i], rs_entry_busy[i], rs_entry_packet_out[i].inst.inst, rs_entry_ready[i], rs_entry_clear[i], entry_rs1_tags[i], entry_rs2_tags[i]);
        // end

        #1 assert(rs_valid == 0) else begin
            $display("@@@ Expected valid: 0, Actual Valid: %b", rs_valid);
            $display("@@@failed");
            $finish;
        end

        @(negedge clock);
//inst0: ready - both in rob
//tag1 ready with cdb broadcast -> mass inst 1 & 2 ready
        id_packet_in.inst.inst = 32'h00000000;

        id_packet_in.rs1_value = 3;
        id_packet_in.rs2_value = 3;
        id_packet_in.dest_reg_idx = 4;
        //mt
        mt2rs_packet_in.rs1_tag.tag = 3;
        mt2rs_packet_in.rs2_tag.tag = 3;
        mt2rs_packet_in.rs1_tag.valid = 1;
        mt2rs_packet_in.rs2_tag.valid = 1;
        mt2rs_packet_in.rs1_ready = 1;
        mt2rs_packet_in.rs2_ready = 1;
        //cdb
        cdb_packet_in.reg_tag.tag = 1;
        cdb_packet_in.reg_tag.valid = 1;
        cdb_packet_in.reg_value = 20;
        //rob
        rob2rs_packet_in.rob_head_idx = 1;
        rob2rs_packet_in.rob_entry = 7;
        rob2rs_packet_in.rs1_value = 0;
        rob2rs_packet_in.rs2_value = 0;

        #1 check_func(32'h11111111, 20, 0);

        @(negedge clock);
//inst0: ready - both in rob
//tag5 ready with cdb broadcast -> mass inst 3, 5, & 7 ready
        id_packet_in.inst.inst = 32'h00000000;

        id_packet_in.rs1_value = 3;
        id_packet_in.rs2_value = 3;
        id_packet_in.dest_reg_idx = 4;
        //mt
        mt2rs_packet_in.rs1_tag.tag = 3;
        mt2rs_packet_in.rs2_tag.tag = 3;
        mt2rs_packet_in.rs1_tag.valid = 1;
        mt2rs_packet_in.rs2_tag.valid = 1;
        mt2rs_packet_in.rs1_ready = 1;
        mt2rs_packet_in.rs2_ready = 1;
        //cdb
        cdb_packet_in.reg_tag.tag = 5;
        cdb_packet_in.reg_tag.valid = 1;
        cdb_packet_in.reg_value = 14;
        //rob
        rob2rs_packet_in.rob_head_idx = 1;
        rob2rs_packet_in.rob_entry = 7;
        rob2rs_packet_in.rs1_value = 0;
        rob2rs_packet_in.rs2_value = 0;

        #1 check_func(32'h22222222, 20, 32);

        @(negedge clock);
//inst0: ready - both in rob
        id_packet_in.inst.inst = 32'h00000000;

        id_packet_in.rs1_value = 3;
        id_packet_in.rs2_value = 3;
        id_packet_in.dest_reg_idx = 4;
        //mt
        mt2rs_packet_in.rs1_tag.tag = 3;
        mt2rs_packet_in.rs2_tag.tag = 3;
        mt2rs_packet_in.rs1_tag.valid = 1;
        mt2rs_packet_in.rs2_tag.valid = 1;
        mt2rs_packet_in.rs1_ready = 1;
        mt2rs_packet_in.rs2_ready = 1;
        //cdb
        cdb_packet_in.reg_tag.tag = 0;
        cdb_packet_in.reg_tag.valid = 0;
        cdb_packet_in.reg_value = 0;
        //rob
        rob2rs_packet_in.rob_head_idx = 1;
        rob2rs_packet_in.rob_entry = 7;
        rob2rs_packet_in.rs1_value = 0;
        rob2rs_packet_in.rs2_value = 0;

        #1 check_func(32'h33333333, 4, 14);

        @(negedge clock);
//inst0: ready - both in rob
//tag5 ready with cdb broadcast, should not change value
        id_packet_in.inst.inst = 32'h00000000;

        id_packet_in.rs1_value = 3;
        id_packet_in.rs2_value = 3;
        id_packet_in.dest_reg_idx = 4;
        //mt
        mt2rs_packet_in.rs1_tag.tag = 3;
        mt2rs_packet_in.rs2_tag.tag = 3;
        mt2rs_packet_in.rs1_tag.valid = 1;
        mt2rs_packet_in.rs2_tag.valid = 1;
        mt2rs_packet_in.rs1_ready = 1;
        mt2rs_packet_in.rs2_ready = 1;
        //cdb
        cdb_packet_in.reg_tag.tag = 5;
        cdb_packet_in.reg_tag.valid = 1;
        cdb_packet_in.reg_value = 33;
        //rob
        rob2rs_packet_in.rob_head_idx = 1;
        rob2rs_packet_in.rob_entry = 7;
        rob2rs_packet_in.rs1_value = 0;
        rob2rs_packet_in.rs2_value = 0;

        #1 check_func(32'h55555555, 1, 14);

        @(negedge clock);
//inst0: ready - both in rob
//tag2 ready with cdb broadcast -> mass inst 4 ready
        id_packet_in.inst.inst = 32'h00000000;

        id_packet_in.rs1_value = 3;
        id_packet_in.rs2_value = 3;
        id_packet_in.dest_reg_idx = 4;
        //mt
        mt2rs_packet_in.rs1_tag.tag = 3;
        mt2rs_packet_in.rs2_tag.tag = 3;
        mt2rs_packet_in.rs1_tag.valid = 1;
        mt2rs_packet_in.rs2_tag.valid = 1;
        mt2rs_packet_in.rs1_ready = 1;
        mt2rs_packet_in.rs2_ready = 1;
        //cdb
        cdb_packet_in.reg_tag.tag = 2;
        cdb_packet_in.reg_tag.valid = 1;
        cdb_packet_in.reg_value = 71;
        //rob
        rob2rs_packet_in.rob_head_idx = 1;
        rob2rs_packet_in.rob_entry = 7;
        rob2rs_packet_in.rs1_value = 0;
        rob2rs_packet_in.rs2_value = 0;

        #1 check_func(32'h44444444, 71, 2);

        @(negedge clock);
//inst0: ready - both in rob
        id_packet_in.inst.inst = 32'h00000000;

        id_packet_in.rs1_value = 3;
        id_packet_in.rs2_value = 3;
        id_packet_in.dest_reg_idx = 4;
        //mt
        mt2rs_packet_in.rs1_tag.tag = 3;
        mt2rs_packet_in.rs2_tag.tag = 3;
        mt2rs_packet_in.rs1_tag.valid = 1;
        mt2rs_packet_in.rs2_tag.valid = 1;
        mt2rs_packet_in.rs1_ready = 1;
        mt2rs_packet_in.rs2_ready = 1;
        //cdb
        cdb_packet_in.reg_tag.tag = 0;
        cdb_packet_in.reg_tag.valid = 0;
        cdb_packet_in.reg_value = 0;
        //rob
        rob2rs_packet_in.rob_head_idx = 1;
        rob2rs_packet_in.rob_entry = 7;
        rob2rs_packet_in.rs1_value = 0;
        rob2rs_packet_in.rs2_value = 0;

        #1 check_func(32'h77777777, 14, 20);

        @(negedge clock);
//inst0: ready - both in rob
//tag3 ready with cdb broadcast -> mass inst 6 ready
        id_packet_in.inst.inst = 32'h00000000;

        id_packet_in.rs1_value = 3;
        id_packet_in.rs2_value = 3;
        id_packet_in.dest_reg_idx = 4;
        //mt
        mt2rs_packet_in.rs1_tag.tag = 3;
        mt2rs_packet_in.rs2_tag.tag = 3;
        mt2rs_packet_in.rs1_tag.valid = 1;
        mt2rs_packet_in.rs2_tag.valid = 1;
        mt2rs_packet_in.rs1_ready = 1;
        mt2rs_packet_in.rs2_ready = 1;
        //cdb
        cdb_packet_in.reg_tag.tag = 3;
        cdb_packet_in.reg_tag.valid = 1;
        cdb_packet_in.reg_value = 66;
        //rob
        rob2rs_packet_in.rob_head_idx = 1;
        rob2rs_packet_in.rob_entry = 7;
        rob2rs_packet_in.rs1_value = 0;
        rob2rs_packet_in.rs2_value = 0;

        #1 check_func(32'h66666666, 5, 66);

        @(negedge clock);
//inst0: ready - both in rob
//tag6 ready with cdb broadcast -> mass inst 8 ready
        id_packet_in.inst.inst = 32'h00000000;

        id_packet_in.rs1_value = 3;
        id_packet_in.rs2_value = 3;
        id_packet_in.dest_reg_idx = 4;
        //mt
        mt2rs_packet_in.rs1_tag.tag = 3;
        mt2rs_packet_in.rs2_tag.tag = 3;
        mt2rs_packet_in.rs1_tag.valid = 1;
        mt2rs_packet_in.rs2_tag.valid = 1;
        mt2rs_packet_in.rs1_ready = 1;
        mt2rs_packet_in.rs2_ready = 1;
        //cdb
        cdb_packet_in.reg_tag.tag = 6;
        cdb_packet_in.reg_tag.valid = 1;
        cdb_packet_in.reg_value = 23;
        //rob
        rob2rs_packet_in.rob_head_idx = 1;
        rob2rs_packet_in.rob_entry = 7;
        rob2rs_packet_in.rs1_value = 0;
        rob2rs_packet_in.rs2_value = 0;

        #1 check_func(32'h88888888, 66, 23);

        @(negedge clock);
        squash = 1;

        @(negedge clock);
        squash = 0;
// Tag 0 in rs1
        id_packet_in.inst.inst = 32'hDEADFACE;
        id_packet_in.rs1_value = 1;  
        id_packet_in.rs2_value = 1;  
        id_packet_in.dest_reg_idx = 1;

        //mt
        mt2rs_packet_in.rs1_tag.tag = 0; // reg file
        mt2rs_packet_in.rs2_tag.tag = 2;
        mt2rs_packet_in.rs1_tag.valid = 1; // reg file
        mt2rs_packet_in.rs2_tag.valid = 1;
        mt2rs_packet_in.rs1_ready = 1;
        mt2rs_packet_in.rs2_ready = 1;

        //cdb
        cdb_packet_in.reg_tag.tag = 0;
        cdb_packet_in.reg_tag.valid = 0;
        cdb_packet_in.reg_value = 0;

        //rob
        rob2rs_packet_in.rob_entry = 1;
        rob2rs_packet_in.rs1_value = 23;
        rob2rs_packet_in.rs2_value = 7;
        rob2rs_packet_in.rob_head_idx = 1;

        // $display("@@@ | RS Index | Wr_en | Busy |   Inst   | Ready | Clear | Tag1 | Tag2 |");
        // for (int i = 0; i < `RS_LEN; i++) begin
        // $display("@@@ |   [%1d]    |   %b   |  %b   | %h |   %b   |   %b   | %b  | %b  |",
        //                 i, rs_entry_enable[i], rs_entry_busy[i], rs_entry_packet_out[i].inst.inst, rs_entry_ready[i], rs_entry_clear[i], entry_rs1_tags[i].tag, entry_rs2_tags[i].tag);
        // end

        @(negedge clock);
// Tag 0 in rs2
        stall = 1;
        id_packet_in.inst.inst = 32'hFACEF00D;
        id_packet_in.rs1_value = 1;  
        id_packet_in.rs2_value = 1;  
        id_packet_in.dest_reg_idx = 1;

        //mt
        mt2rs_packet_in.rs1_tag.tag = 5; // reg file
        mt2rs_packet_in.rs2_tag.tag = 0;
        mt2rs_packet_in.rs1_tag.valid = 1; // reg file
        mt2rs_packet_in.rs2_tag.valid = 1;
        mt2rs_packet_in.rs1_ready = 1;
        mt2rs_packet_in.rs2_ready = 1;

        //cdb
        cdb_packet_in.reg_tag.tag = 0;
        cdb_packet_in.reg_tag.valid = 0;
        cdb_packet_in.reg_value = 0;

        //rob
        rob2rs_packet_in.rob_entry = 2;
        rob2rs_packet_in.rs1_value = 61;
        rob2rs_packet_in.rs2_value = 43;
        rob2rs_packet_in.rob_head_idx = 1;

        // $display("~~~Stalling now");
        // $display("@@@ | RS Index | Wr_en | Busy |   Inst   | Ready | Clear | Tag1 | Tag2 |");
        // for (int i = 0; i < `RS_LEN; i++) begin
        // $display("@@@ |   [%1d]    |   %b   |  %b   | %h |   %b   |   %b   | %b  | %b  |",
        //                 i, rs_entry_enable[i], rs_entry_busy[i], rs_entry_packet_out[i].inst.inst, rs_entry_ready[i], rs_entry_clear[i], entry_rs1_tags[i].tag, entry_rs2_tags[i].tag);
        // end

        // #1 check_func(32'hDEADFACE, 23, 7);

        @(negedge clock);
// Tag 0 in rs2
        stall = 0;
        id_packet_in.inst.inst = 32'hF00DF00D;
        id_packet_in.rs1_value = 1;  
        id_packet_in.rs2_value = 1;  
        id_packet_in.dest_reg_idx = 1;

        //mt
        mt2rs_packet_in.rs1_tag.tag = 0; // reg file
        mt2rs_packet_in.rs2_tag.tag = 0;
        mt2rs_packet_in.rs1_tag.valid = 1; // reg file
        mt2rs_packet_in.rs2_tag.valid = 1;
        mt2rs_packet_in.rs1_ready = 1;
        mt2rs_packet_in.rs2_ready = 1;

        //cdb
        cdb_packet_in.reg_tag.tag = 0;
        cdb_packet_in.reg_tag.valid = 0;
        cdb_packet_in.reg_value = 0;

        //rob
        rob2rs_packet_in.rob_entry = 3;
        rob2rs_packet_in.rs1_value = 11;
        rob2rs_packet_in.rs2_value = 11;
        rob2rs_packet_in.rob_head_idx = 1;

        #1 check_func(32'hDEADFACE, 23, 7);
        // #1 check_func(32'hFACEF00D, 61, 43);

        @(negedge clock);
        #1 check_func(32'hFACEF00D, 61, 43);
        // #1 check_func(32'hF00DF00D, 11, 11);

        @(negedge clock);
        #1 check_func(32'hF00DF00D, 11, 11);
        
        $display("@@@PASSED@@@");
        $finish;
    end

endmodule