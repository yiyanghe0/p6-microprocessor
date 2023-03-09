
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
        $monitor("TIME:%4.0f inst:%32h", $time, is_packet_out.inst.inst);
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


         
        //clear
   //     clear = 0;
        assert(Big_RS.rs_entry_busy[0] == 0) else $display ("@@@FAILED@@@");
        assert(Big_RS.rs_entry_enable[0] == 1) else $display ("@@@FAILED@@@");
        @(negedge clock);

        assert(Big_RS.rs_entry_enable[0] == 0) else $display ("@@@FAILED@@@");
        assert(Big_RS.rs_entry_busy[0] == 1) else $display ("@@@FAILED@@@");
        assert(Big_RS.rs_entry_ready[0] == 1) else $display ("@@@FAILED@@@");


        assert(Big_RS.issue_inst_rob_entry == 8'b1) else $display("@@@FAILED@@@");
        $display("issue:%8b",Big_RS.issue_inst_rob_entry);

        //[1] or [0]???
        assert(rs2mt_packet_out.dest_reg_tag == rob2rs_packet_in.rob_entry) else $display ("@@@FAILED@@@");
        assert(is_packet_out.inst.inst == 32'hABCDEF12) else $display ("@@@FAILED@@@");

        @(negedge clock);
        rs_entry_clear_in[0] = 1;



//2
        //clear
        rs_entry_clear_in[1] = 0;
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
        rob2rs_packet_in.rob_entry = 2;
        rob2rs_packet_in.rs1_value = 0;
        rob2rs_packet_in.rs2_value = 0;
        //clear

        assert(Big_RS.rs_entry_busy[1] == 1) else $display ("@@@FAILED@@@");
        assert(Big_RS.rs_entry_enable[1] == 1) else $display ("@@@FAILED@@@");

        @(negedge clock);
        assert(rs2mt_packet_out.dest_reg_tag == rob2rs_packet_in.rob_entry) else $display ("@@@FAILED@@@");
        assert(Big_RS.rs_entry_enable[1] == 0) else $display ("@@@FAILED@@@");
        assert(Big_RS.rs_entry_busy[1] == 1) else $display ("@@@FAILED@@@");
        assert(Big_RS.rs_entry_ready[1] == 1) else $display ("@@@FAILED@@@");
        assert(is_packet_out.inst.inst == 32'hABC45F12) else $display ("@@@FAILED@@@");



        @(negedge clock);
         rs_entry_clear_in[1] = 1;

//inst3
        //clear
        rs_entry_clear_in[2] = 0;

        //test inst
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
        rob2rs_packet_in.rob_entry = 3;
        rob2rs_packet_in.rs1_value = 0;
        rob2rs_packet_in.rs2_value = 0;

        assert(Big_RS.rs_entry_busy[2] == 1) else $display ("@@@FAILED@@@");
        assert(Big_RS.rs_entry_enable[2] == 1) else $display ("@@@FAILED@@@");

        @(negedge clock);
        assert(rs2mt_packet_out.dest_reg_tag == rob2rs_packet_in.rob_entry) else $display ("@@@FAILED@@@");
        //test enable
        assert(Big_RS.rs_entry_enable[2] == 0) else $display ("@@@FAILED@@@");
        assert(Big_RS.rs_entry_busy[2] == 1) else $display ("@@@FAILED@@@");
        assert(Big_RS.rs_entry_ready[2] == 1) else $display ("@@@FAILED@@@");
        assert(is_packet_out.inst.inst == 32'hab489F12) else $display ("@@@FAILED@@@");

        cdb_packet_in.reg_tag = 1;
        cdb_packet_in.reg_value = 1;
        
        @(negedge clock);
        assert(Big_RS.rs_entry_busy[2] == 1) else $display ("@@@FAILED@@@");
        assert(Big_RS.rs_entry_ready[2] == 1) else $display ("@@@FAILED@@@");
        
        rs_entry_clear_in[2] = 1;

        cdb_packet_in.reg_tag = 0;
        cdb_packet_in.reg_value = 0;

        @(negedge clock);
        assert(Big_RS.rs_entry_busy[2] == 0) else $display ("@@@FAILED@@@");
        @(negedge clock);


//inst4

         //clear
        rs_entry_clear_in[3] = 0;

        //id
        //test inst
        id_packet_in.inst.inst = 32'habbacF12;

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

        assert(Big_RS.rs_entry_busy[3] == 1) else $display ("@@@FAILED@@@");
        assert(Big_RS.rs_entry_enable[3] == 1) else $display ("@@@FAILED@@@");

        @(negedge clock);
        assert(Big_RS.rs_entry_busy[3] == 1) else $display ("@@@FAILED@@@");
        assert(Big_RS.rs_entry_enable[3] == 0) else $display ("@@@FAILED@@@");
        assert(Big_RS.rs_entry_ready[3] == 0) else $display ("@@@FAILED@@@");
        assert(rs2mt_packet_out.dest_reg_tag == rob2rs_packet_in.rob_entry) else $display ("@@@FAILED@@@");

        assert(is_packet_out.inst.inst == 32'habbacF12) else $display ("@@@FAILED@@@");

        @(negedge clock);
        assert(Big_RS.rs_entry_busy[3] == 1) else $display ("@@@FAILED@@@");
        assert(Big_RS.rs_entry_ready[3] == 0) else $display ("@@@FAILED@@@");

        cdb_packet_in.reg_tag = 1;
        cdb_packet_in.reg_value = 1;

        @(negedge clock);
        assert(Big_RS.rs_entry_busy[3] == 1) else $display ("@@@FAILED@@@");
        assert(Big_RS.rs_entry_ready[3] == 1) else $display ("@@@FAILED@@@");

        rs_entry_clear_in[3] = 1;
    
        cdb_packet_in.reg_tag = 0;
        cdb_packet_in.reg_value = 0;

        @(negedge clock);
        assert(Big_RS.rs_entry_busy[3] == 0) else $display ("@@@FAILED@@@");
        @(negedge clock);



        //very tight test
//inst5 
        //clear
        rs_entry_clear_in[4] = 0;
        //id
        //test inst
        id_packet_in.inst.inst = 32'habaacF12;
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

        assert(Big_RS.rs_entry_busy[4] == 1) else $display ("@@@FAILED@@@");
        assert(Big_RS.rs_entry_enable[4] == 1) else $display ("@@@FAILED@@@");

       
        @(negedge clock);
        assert(rs2mt_packet_out.dest_reg_tag == rob2rs_packet_in.rob_entry) else $display ("@@@FAILED@@@");
        assert(Big_RS.rs_entry_enable[4] == 0) else $display ("@@@FAILED@@@");
        assert(Big_RS.rs_entry_busy[4] == 1) else $display ("@@@FAILED@@@");
        assert(Big_RS.rs_entry_ready[4] == 1) else $display ("@@@FAILED@@@");
        assert(is_packet_out.inst.inst == 32'habaacF12) else $display ("@@@FAILED@@@");
        @(negedge clock);
        assert(Big_RS.rs_entry_busy[4] == 1) else $display ("@@@FAILED@@@");
        rs_entry_clear_in[4] = 1;


//inst6
        //clear
        rs_entry_clear_in[5] = 0;
        
        //test inst
        id_packet_in.inst.inst = 32'hab22cF12;
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

        assert(Big_RS.rs_entry_busy[5] == 1) else $display ("@@@FAILED@@@");
        assert(Big_RS.rs_entry_enable[5] == 1) else $display ("@@@FAILED@@@");

        //clear
        @(negedge clock);
        assert(Big_RS.rs_entry_busy[5] == 1) else $display ("@@@FAILED@@@");
        assert(Big_RS.rs_entry_enable[5] == 0) else $display ("@@@FAILED@@@");
        assert(rs2mt_packet_out.dest_reg_tag == rob2rs_packet_in.rob_entry) else $display ("@@@FAILED@@@");
        
        @(negedge clock);
        //assert(busy == 1) else $display("@@@FAILED@@@");
        //assert(ready == 1) else $display("@@@FAILED@@@");

        assert(Big_RS.rs_entry_busy[5] == 1) else $display ("@@@FAILED@@@");
        assert(Big_RS.rs_entry_ready[5] == 1) else $display ("@@@FAILED@@@");
        assert(is_packet_out.inst.inst == 32'hab22cF12) else $display ("@@@FAILED@@@");

        @(negedge clock);
        assert(Big_RS.rs_entry_busy[5] == 0) else $display ("@@@FAILED@@@");
        rs_entry_clear_in[5] = 1;
        @(negedge clock);
        assert(Big_RS.rs_entry_busy[5] == 0) else $display ("@@@FAILED@@@");
        @(negedge clock);


//inst7
        //clear
        rs_entry_clear_in[6] = 0;

        //id
        //test inst
        id_packet_in.inst.inst = 32'hab2ccF12;
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


        assert(Big_RS.rs_entry_busy[6] == 1) else $display ("@@@FAILED@@@");
        assert(Big_RS.rs_entry_enable[6] == 1) else $display ("@@@FAILED@@@");

        @(negedge clock);
        assert(Big_RS.rs_entry_busy[6] == 1) else $display ("@@@FAILED@@@");
        assert(Big_RS.rs_entry_enable[6] == 0) else $display ("@@@FAILED@@@");
        assert(Big_RS.rs_entry_ready[6] == 0) else $display ("@@@FAILED@@@");
        assert(is_packet_out.inst.inst == 32'hab2ccF12) else $display ("@@@FAILED@@@");

        @(negedge clock);
        assert(rs2mt_packet_out.dest_reg_tag == rob2rs_packet_in.rob_entry) else $display ("@@@FAILED@@@");
        cdb_packet_in.reg_tag = 2;
        cdb_packet_in.reg_value = 10;

        @(negedge clock);
        assert(Big_RS.rs_entry_ready[6] == 1) else $display ("@@@FAILED@@@");
        assert(Big_RS.rs_entry_busy[6] == 1) else $display ("@@@FAILED@@@");
    
        rs_entry_clear_in[6] = 1;
        @(negedge clock);
        assert(Big_RS.rs_entry_busy[6] == 0) else $display ("@@@FAILED@@@");

//inst8
        //clear
        rs_entry_clear_in[7] = 0;
        //id
        //test inst
        id_packet_in.inst.inst = 32'h222ccF12;
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

        assert(Big_RS.rs_entry_busy[7] == 1) else $display ("@@@FAILED@@@");
        assert(Big_RS.rs_entry_enable[7] == 1) else $display ("@@@FAILED@@@");

        @(negedge clock);
        assert(Big_RS.rs_entry_ready[7] == 0) else $display ("@@@FAILED@@@");
        assert(Big_RS.rs_entry_busy[7] == 1) else $display ("@@@FAILED@@@");

        cdb_packet_in.reg_tag = 4;
        cdb_packet_in.reg_value = 10;

        @(negedge clock);
        assert(rs2mt_packet_out.dest_reg_tag == rob2rs_packet_in.rob_entry) else $display ("@@@FAILED@@@");
        assert(Big_RS.rs_entry_ready[7] == 0) else $display ("@@@FAILED@@@");
        assert(Big_RS.rs_entry_busy[7] == 1) else $display ("@@@FAILED@@@");
        assert(is_packet_out.inst.inst == 32'h222ccF12) else $display ("@@@FAILED@@@");

        cdb_packet_in.reg_tag = 3;
        cdb_packet_in.reg_value = 10;
        @(negedge clock);

        assert(Big_RS.rs_entry_ready[7] == 1) else $display ("@@@FAILED@@@");
        assert(Big_RS.rs_entry_busy[7] == 1) else $display ("@@@FAILED@@@");

        rs_entry_clear_in[7] = 1;
        @(negedge clock);
        assert(Big_RS.rs_entry_busy[7] == 0) else $display ("@@@FAILED@@@");

    //test structural hazard



        $display("@@@PASSED@@@");
        $finish;
    end

endmodule