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

    // RS2ROB_PACKET rs2rob_packet;
    // RS2MT_PACKET rs2mt_packet;
    // IS_PACKET is_packet;

    // always_ff @(posedge clock) begin
    //     if (reset) begin
    //         rs2rob_packet <= `SD 0;
    //         rs2mt_packet <= `SD 0;
    //         is_packet <= `SD 0;
    //         rs_entry_clear_in <= `SD 0;
    //     end
    //     else begin
    //         rs2rob_packet <= `SD rs2rob_packet_out;
    //         rs2mt_packet <= `SD rs2mt_packet_out;
    //         is_packet <= `SD is_packet_out;
    //         rs_entry_clear_in <= `SD rs_entry_clear_out;
    //     end
    // end

    assign rs_entry_clear_in = rs_entry_clear_out;
    

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
        $monitor("TIME:%4.0f busy:%8b ready:%8b enable:%8b clear_in:%8b issue_inst:%8b", $time, Big_RS.rs_entry_busy, Big_RS.rs_entry_ready, Big_RS.rs_entry_enable, Big_RS.rs_entry_clear_in, Big_RS.issue_inst_rob_entry);
        clock = 0;
        reset = 1;
        @(negedge clock);
        reset = 0;

        // rs_entry_clear_in[0] = 1'b0;
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

        $display("clear_out:%8b", rs_entry_clear_out);
        $display("1st instr inputted");
        @(negedge clock);
        assert(is_packet_out.inst.inst == 32'hABCDEF12) else $display ("@@@FAILED@@@"); //test #1
//#2    
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

        $display("clear_out:%8b", rs_entry_clear_out);
        $display("2nd instr inputted");

        @(negedge clock);
        assert(is_packet_out.inst.inst == 32'hABC45F12) else $display ("@@@FAILED@@@");  //test #2
//#3 case: not ready(need one cycle to handle)
        id_packet_in.inst.inst = 32'hab489F12;

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
        rob2rs_packet_in.rob_head_idx = 1;
        rob2rs_packet_in.rob_entry = 3;
        rob2rs_packet_in.rs1_value = 0;
        rob2rs_packet_in.rs2_value = 0;

        // $display("TIME:%4.0f busy:%8b ready:%8b enable:%8b clear_in:%8b", $time, Big_RS.rs_entry_busy, Big_RS.rs_entry_ready, Big_RS.rs_entry_enable, Big_RS.rs_entry_clear_in);
        $display("clear_out:%8b", rs_entry_clear_out);
        $display("3rd instr inputted");

        @(negedge clock);
        id_packet_in.inst.inst = 32'h00000000;

        id_packet_in.rs1_value = 3;
        id_packet_in.rs2_value = 3;
        id_packet_in.dest_reg_idx = 4;
        //mt
        mt2rs_packet_in.rs1_tag = 3;
        mt2rs_packet_in.rs2_tag = 3;
        mt2rs_packet_in.rs1_ready = 1;
        mt2rs_packet_in.rs2_ready = 1;
        //cdb
        cdb_packet_in.reg_tag = 1;
        cdb_packet_in.reg_value = 20;
        //rob
        rob2rs_packet_in.rob_head_idx = 1;
        rob2rs_packet_in.rob_entry = 3;
        rob2rs_packet_in.rs1_value = 0;
        rob2rs_packet_in.rs2_value = 0;

    //assert (inst3)
        #1 assert(is_packet_out.inst.inst == 32'hab489F12) else $display ("@@@FAILED@@@");  //test #3

//waiting inst #4
        
        $display("clear_out:%8b", rs_entry_clear_out);

        @(negedge clock);
    //assert (inst4)
        assert(is_packet_out.inst.inst == 32'h00000000) else $display ("@@@FAILED@@@");  //wait for inst #4
        
    
//insert inst5
        //test inst
        id_packet_in.inst.inst = 32'hab22cF12;
        //id
        id_packet_in.rs1_value = 2;
        id_packet_in.rs2_value = 2;
        id_packet_in.dest_reg_idx = 2;
        //mt
        mt2rs_packet_in.rs1_tag = 3;  // t1 t2 is blank, v1 v2 in rob
        mt2rs_packet_in.rs2_tag = 2;
        mt2rs_packet_in.rs1_ready = 0;
        mt2rs_packet_in.rs2_ready = 0;
        //cdb
        cdb_packet_in.reg_tag = 0;
        cdb_packet_in.reg_value = 0;
        //rob
        rob2rs_packet_in.rob_head_idx = 1;
        rob2rs_packet_in.rob_entry = 4;
        rob2rs_packet_in.rs1_value = 0;
        rob2rs_packet_in.rs2_value = 0;

        @(negedge clock);

        

    //insert inst6
        //test inst
        id_packet_in.inst.inst = 32'ha12acF12;
        id_packet_in.rs1_value = 1;  
        id_packet_in.rs2_value = 1;  
        id_packet_in.dest_reg_idx = 1;
        //mt
        mt2rs_packet_in.rs1_tag = 0; // reg file
        mt2rs_packet_in.rs2_tag = 0;
        mt2rs_packet_in.rs1_ready = 0;
        mt2rs_packet_in.rs2_ready = 0;
        //cdb
        cdb_packet_in.reg_tag = 3;   //broadcast reg1
        cdb_packet_in.reg_value = 50;
        //rob
        rob2rs_packet_in.rob_head_idx = 1;
        rob2rs_packet_in.rob_entry = 5;
        rob2rs_packet_in.rs1_value = 0;
        rob2rs_packet_in.rs2_value = 0;
        
        @(negedge clock);

        //test inst 6

    //insert inst7
        id_packet_in.inst.inst = 32'hab2ccF12;
        id_packet_in.rs1_value = 1;  
        id_packet_in.rs2_value = 1;  
        id_packet_in.dest_reg_idx = 1;
        //mt
        mt2rs_packet_in.rs1_tag = 2; // one tag
        mt2rs_packet_in.rs2_tag = 3;
        mt2rs_packet_in.rs1_ready = 1;
        mt2rs_packet_in.rs2_ready = 1;
        //cdb
        cdb_packet_in.reg_tag = 2;
        cdb_packet_in.reg_value = 60;
        //rob
        rob2rs_packet_in.rob_head_idx = 1;
        rob2rs_packet_in.rob_entry = 6;
        rob2rs_packet_in.rs1_value = 0;
        rob2rs_packet_in.rs2_value = 0;

        #1 assert(is_packet_out.inst.inst == 32'hab22cF12) else $display ("@@@FAILED@@@");  //test inst5
        $display("Current inst:%32h", Big_RS.is_packet_out.inst.inst);
        $display("Current issue_inst_rob_entry:%8b", Big_RS.issue_inst_rob_entry);
        $display("Current issue_candidate_rob_entry:%8b", Big_RS.issue_candidate_rob_entry);
        @(negedge clock);

        id_packet_in.inst.inst = 32'h00000000;

        id_packet_in.rs1_value = 3;
        id_packet_in.rs2_value = 3;
        id_packet_in.dest_reg_idx = 4;
        //mt
        mt2rs_packet_in.rs1_tag = 3;
        mt2rs_packet_in.rs2_tag = 3;
        mt2rs_packet_in.rs1_ready = 1;
        mt2rs_packet_in.rs2_ready = 1;
        //cdb
        cdb_packet_in.reg_tag = 1;
        cdb_packet_in.reg_value = 25;
        //rob
        rob2rs_packet_in.rob_head_idx = 1;
        rob2rs_packet_in.rob_entry = 7;
        rob2rs_packet_in.rs1_value = 0;
        rob2rs_packet_in.rs2_value = 0;

        assert(is_packet_out.inst.inst == 32'ha12acF12) else $display ("@@@FAILED@@@"); 
        $display("Current inst:%32h", Big_RS.is_packet_out.inst.inst);
        $display("Current issue_inst_rob_entry:%8b", Big_RS.issue_inst_rob_entry);
        $display("Current issue_candidate_rob_entry:%8b", Big_RS.issue_candidate_rob_entry);

        @(negedge clock);
        #1 assert(is_packet_out.inst.inst == 32'hab2ccF12) else $display ("@@@FAILED@@@");  //test inst7
        $display("Current inst:%32h", Big_RS.is_packet_out.inst.inst);
        $display("Current issue_inst_rob_entry:%8b", Big_RS.issue_inst_rob_entry);
        $display("Current issue_candidate_rob_entry:%8b", Big_RS.issue_candidate_rob_entry);

        //rest and do the mass test
        reset = 1;

        @(negedge clock);
        
        reset = 0;
    //mass inst1

        id_packet_in.inst.inst = 32'h11111111;
        id_packet_in.rs1_value = 1;  
        id_packet_in.rs2_value = 1;  
        id_packet_in.dest_reg_idx = 1;
        //mt
        mt2rs_packet_in.rs1_tag = 1; // one tag
        mt2rs_packet_in.rs2_tag = 3;
        mt2rs_packet_in.rs1_ready = 0;
        mt2rs_packet_in.rs2_ready = 1;
        //cdb
        cdb_packet_in.reg_tag = 0;
        cdb_packet_in.reg_value = 0;
        //rob
        rob2rs_packet_in.rob_head_idx = 1;
        rob2rs_packet_in.rob_entry = 1;
        rob2rs_packet_in.rs1_value = 0;
        rob2rs_packet_in.rs2_value = 0;

        @(negedge clock);

        //mass inst2
    
        id_packet_in.inst.inst = 32'h22222222;
        id_packet_in.rs1_value = 2;  
        id_packet_in.rs2_value = 2;  
        id_packet_in.dest_reg_idx = 1;
        //mt
        mt2rs_packet_in.rs1_tag = 1; // one tag
        mt2rs_packet_in.rs2_tag = 3;
        mt2rs_packet_in.rs1_ready = 0;
        mt2rs_packet_in.rs2_ready = 1;
        //cdb
        cdb_packet_in.reg_tag = 0;
        cdb_packet_in.reg_value = 0;
        //rob
        rob2rs_packet_in.rob_head_idx = 1;
        rob2rs_packet_in.rob_entry = 1;
        rob2rs_packet_in.rs1_value = 0;
        rob2rs_packet_in.rs2_value = 0;

         @(negedge clock);

        //mass inst3

        id_packet_in.inst.inst = 32'h33333333;
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
        rob2rs_packet_in.rob_head_idx = 1;
        rob2rs_packet_in.rob_entry = 1;
        rob2rs_packet_in.rs1_value = 0;
        rob2rs_packet_in.rs2_value = 0;

        @(negedge clock);

        //mass inst4
    
        id_packet_in.inst.inst = 32'h44444444;
        id_packet_in.rs1_value = 2;  
        id_packet_in.rs2_value = 2;  
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
        rob2rs_packet_in.rob_head_idx = 1;
        rob2rs_packet_in.rob_entry = 1;
        rob2rs_packet_in.rs1_value = 0;
        rob2rs_packet_in.rs2_value = 0;

        @(negedge clock);
    
    //mass inst5

        id_packet_in.inst.inst = 32'h55555555;
        id_packet_in.rs1_value = 1;  
        id_packet_in.rs2_value = 1;  
        id_packet_in.dest_reg_idx = 1;
        //mt
        mt2rs_packet_in.rs1_tag = 3; // one tag
        mt2rs_packet_in.rs2_tag = 3;
        mt2rs_packet_in.rs1_ready = 0;
        mt2rs_packet_in.rs2_ready = 1;
        //cdb
        cdb_packet_in.reg_tag = 0;
        cdb_packet_in.reg_value = 0;
        //rob
        rob2rs_packet_in.rob_head_idx = 1;
        rob2rs_packet_in.rob_entry = 1;
        rob2rs_packet_in.rs1_value = 0;
        rob2rs_packet_in.rs2_value = 0;

        @(negedge clock);

        //mass inst6
    
        id_packet_in.inst.inst = 32'h66666666;
        id_packet_in.rs1_value = 2;  
        id_packet_in.rs2_value = 2;  
        id_packet_in.dest_reg_idx = 1;
        //mt
        mt2rs_packet_in.rs1_tag = 3; // one tag
        mt2rs_packet_in.rs2_tag = 3;
        mt2rs_packet_in.rs1_ready = 0;
        mt2rs_packet_in.rs2_ready = 1;
        //cdb
        cdb_packet_in.reg_tag = 0;
        cdb_packet_in.reg_value = 0;
        //rob
        rob2rs_packet_in.rob_head_idx = 1;
        rob2rs_packet_in.rob_entry = 1;
        rob2rs_packet_in.rs1_value = 0;
        rob2rs_packet_in.rs2_value = 0;

         @(negedge clock);

        //mass inst7

        id_packet_in.inst.inst = 32'h77777777;
        id_packet_in.rs1_value = 1;  
        id_packet_in.rs2_value = 1;  
        id_packet_in.dest_reg_idx = 1;
        //mt
        mt2rs_packet_in.rs1_tag = 4; // one tag
        mt2rs_packet_in.rs2_tag = 3;
        mt2rs_packet_in.rs1_ready = 0;
        mt2rs_packet_in.rs2_ready = 1;
        //cdb
        cdb_packet_in.reg_tag = 0;
        cdb_packet_in.reg_value = 0;
        //rob
        rob2rs_packet_in.rob_head_idx = 1;
        rob2rs_packet_in.rob_entry = 1;
        rob2rs_packet_in.rs1_value = 0;
        rob2rs_packet_in.rs2_value = 0;

        @(negedge clock);

        //mass inst8
    
        id_packet_in.inst.inst = 32'h88888888;
        id_packet_in.rs1_value = 5;  
        id_packet_in.rs2_value = 2;  
        id_packet_in.dest_reg_idx = 1;
        //mt
        mt2rs_packet_in.rs1_tag = 4; // one tag
        mt2rs_packet_in.rs2_tag = 3;
        mt2rs_packet_in.rs1_ready = 0;
        mt2rs_packet_in.rs2_ready = 1;
        //cdb
        cdb_packet_in.reg_tag = 1;
        cdb_packet_in.reg_value = 20;
        //rob
        rob2rs_packet_in.rob_head_idx = 1;
        rob2rs_packet_in.rob_entry = 1;
        rob2rs_packet_in.rs1_value = 0;
        rob2rs_packet_in.rs2_value = 0;


        #1 assert(is_packet_out.inst.inst == 32'h11111111) else $display ("@@@FAILED@@@");  //test inst1

        @(negedge clock);

        id_packet_in.inst.inst = 32'h00000000;

        id_packet_in.rs1_value = 3;
        id_packet_in.rs2_value = 3;
        id_packet_in.dest_reg_idx = 4;
        //mt
        mt2rs_packet_in.rs1_tag = 3;
        mt2rs_packet_in.rs2_tag = 3;
        mt2rs_packet_in.rs1_ready = 1;
        mt2rs_packet_in.rs2_ready = 1;
        //cdb
        cdb_packet_in.reg_tag = 0;
        cdb_packet_in.reg_value = 0;
        //rob
        rob2rs_packet_in.rob_head_idx = 1;
        rob2rs_packet_in.rob_entry = 7;
        rob2rs_packet_in.rs1_value = 0;
        rob2rs_packet_in.rs2_value = 0;

        assert(is_packet_out.inst.inst == 32'h22222222) else $display ("@@@FAILED@@@");  //test inst2

        @(negedge clock);

        id_packet_in.inst.inst = 32'h00000000;

        id_packet_in.rs1_value = 3;
        id_packet_in.rs2_value = 3;
        id_packet_in.dest_reg_idx = 4;
        //mt
        mt2rs_packet_in.rs1_tag = 3;
        mt2rs_packet_in.rs2_tag = 3;
        mt2rs_packet_in.rs1_ready = 1;
        mt2rs_packet_in.rs2_ready = 1;
        //cdb
        cdb_packet_in.reg_tag = 0;
        cdb_packet_in.reg_value = 0;
        //rob
        rob2rs_packet_in.rob_head_idx = 1;
        rob2rs_packet_in.rob_entry = 7;
        rob2rs_packet_in.rs1_value = 0;
        rob2rs_packet_in.rs2_value = 0;



        assert(is_packet_out.inst.inst == 32'h00000000) else $display ("@@@FAILED@@@");  //test inst0
        $display("@@@PASSED@@@");
        $finish;
    end

endmodule