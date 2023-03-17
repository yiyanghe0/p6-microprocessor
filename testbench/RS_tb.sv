`define DEBUG
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
    logic [$clog2(`RS_LEN)-1:0] issue_inst_rs_entry;
    logic [`ROB_LEN-1:0] issue_candidate_rob_entry; // one-hot encoding of rs_entry_packet_out.dest_reg_idx
    logic [`ROB_LEN-1:0] issue_inst_rob_entry; // one-hot encoding of rob_entry of the inst issued
    logic [`RS_LEN-1:0][`ROB_LEN-1:0] rs_entry_rob_entry;

    IS_PACKET [`RS_LEN-1:0] rs_entry_packet_out;

    logic valid; // if valid = 0, rs encountered structural hazard and has to stall



    RS Big_RS(
        .clock(clock),
        .reset(reset),
        .id_packet_in(id_packet_in),
        .rob2rs_packet_in(rob2rs_packet_in),
        .mt2rs_packet_in(mt2rs_packet_in),
        .cdb_packet_in(cdb_packet_in),
        //.rs_entry_clear_in(rs_entry_clear_in),
        
        `ifdef DEBUG
        .rs_entry_enable(rs_entry_enable),
        .rs_entry_busy(rs_entry_busy),
        .rs_entry_ready(rs_entry_ready),
        .issue_inst_rs_entry(issue_inst_rs_entry),
        .issue_candidate_rob_entry(issue_candidate_rob_entry), // one-hot encoding of rs_entry_packet_out.dest_reg_idx
        .issue_inst_rob_entry(issue_inst_rob_entry), // one-hot encoding of rob_entry of the inst issued
        .rs_entry_rob_entry(rs_entry_rob_entry),
        `endif 

        .rs2rob_packet_out(rs2rob_packet_out),
        .rs2mt_packet_out(rs2mt_packet_out),
        .is_packet_out(is_packet_out)
        //.rs_entry_clear_out(rs_entry_clear_out)
    );
/*
    task exit_on_error;
        input correct_busy, correct_ready;
        input [31:0] correct_inst;
        begin
            $display("@@@ Incorrect at time %4.0f", $time);
            $display("@@@ Time:%4.0f enable:%b busy:%b ready:%b INST:%8h", $time, enable, busy, ready, entry_packet.inst.inst);
            $display("@@@ expected busy: %b, expected ready: %b, expected inst: %h", correct_busy, correct_ready, correct_inst);
            $display("@@@failed");
            $finish;
        end
    endtask

    task check_func;
        input correct_busy, correct_ready;
        input [31:0] correct_rs1;
        input [31:0] correct_rs2;
        input [31:0] correct_inst;

        begin 
            assert (busy == correct_busy)                                   else exit_on_error(correct_busy,correct_ready, correct_inst);
            assert (ready == correct_ready)                                 else exit_on_error(correct_busy,correct_ready, correct_inst);
            assert (entry_packet.inst.inst == correct_inst)                 else exit_on_error(correct_busy,correct_ready, correct_inst);
            assert (id_packet_in.NPC == entry_packet.NPC)                   else exit_on_error(correct_busy,correct_ready, correct_inst);
            assert (id_packet_in.PC == entry_packet.PC)                     else exit_on_error(correct_busy,correct_ready, correct_inst);
            assert (entry_packet.rs1_value == correct_rs1)                  else exit_on_error(correct_busy,correct_ready, correct_inst);
            assert (entry_packet.rs2_value == correct_rs2)                  else exit_on_error(correct_busy,correct_ready, correct_inst);
            assert (id_packet_in.opa_select == entry_packet.opa_select)     else exit_on_error(correct_busy,correct_ready, correct_inst);
            assert (id_packet_in.opb_select == entry_packet.opb_select)     else exit_on_error(correct_busy,correct_ready, correct_inst);
            assert (id_packet_in.alu_func == entry_packet.alu_func)         else exit_on_error(correct_busy,correct_ready, correct_inst);
            assert (id_packet_in.rd_mem == entry_packet.rd_mem)             else exit_on_error(correct_busy,correct_ready, correct_inst);
            assert (id_packet_in.wr_mem == entry_packet.wr_mem)             else exit_on_error(correct_busy,correct_ready, correct_inst);
            assert (id_packet_in.cond_branch == entry_packet.cond_branch)   else exit_on_error(correct_busy,correct_ready, correct_inst);
            assert (id_packet_in.halt == entry_packet.halt)                 else exit_on_error(correct_busy,correct_ready, correct_inst);
            assert (id_packet_in.illegal == entry_packet.illegal)           else exit_on_error(correct_busy,correct_ready, correct_inst);
            assert (id_packet_in.csr_op == entry_packet.csr_op)             else exit_on_error(correct_busy,correct_ready, correct_inst);
            assert (id_packet_in.valid == entry_packet.valid)               else exit_on_error(correct_busy,correct_ready, correct_inst);
        end
    endtask
*/
    always begin
        #5;
        clock = ~clock;
    end

//1

    initial begin
        //$monitor("TIME:%4.0f busy:%b ready:%b rs1_tag:%h rs2_tag:%h", $time, busy, ready, DUT_rs_entry.next_entry_rs1_tag, DUT_rs_entry.next_entry_rs2_tag);
        $monitor("TIME:%4.0f busy:%8b ready:%8b enable:%8b issue_inst:%8b", $time, rs_entry_busy, rs_entry_ready, rs_entry_enable, issue_inst_rob_entry);
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
        assert(is_packet_out.rs1_value == 1) else $display ("@@@FAILED@@@");
        assert(is_packet_out.rs2_value == 1) else $display ("@@@FAILED@@@");
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
        assert(is_packet_out.rs1_value == 0) else $display ("@@@FAILED@@@");
        assert(is_packet_out.rs2_value == 0) else $display ("@@@FAILED@@@");
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

        // $display("TIME:%4.0f busy:%8b ready:%8b enable:%8b clear_in:%8b", $time, rs_entry_busy, rs_entry_ready, rs_entry_enable, rs_entry_clear_in);
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
        assert(is_packet_out.rs1_value == 20) else $display ("@@@FAILED@@@");
        assert(is_packet_out.rs2_value == 20) else $display ("@@@FAILED@@@");

//waiting inst #4
        
        $display("clear_out:%8b", rs_entry_clear_out);

        @(negedge clock);
    //assert (inst4)
        assert(is_packet_out.inst.inst == 32'h00000000) else $display ("@@@FAILED@@@");  //wait for inst #4
        assert(is_packet_out.rs1_value == 0) else $display ("@@@FAILED@@@");
        assert(is_packet_out.rs2_value == 0) else $display ("@@@FAILED@@@");
        
    
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
        mt2rs_packet_in.rs1_ready = 0;
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
        assert(is_packet_out.rs1_value == 50) else $display ("@@@FAILED@@@");
        assert(is_packet_out.rs2_value == 60) else $display ("@@@FAILED@@@");

        $display("ready_0: %1b,",rs_entry_ready[0]);
        $display("ready_1: %1b,",rs_entry_ready[1]);
        $display("ready_2: %1b,",rs_entry_ready[2]);
        $display("ready_3: %1b,",rs_entry_ready[3]);
        $display("ready_4: %1b,",rs_entry_ready[4]);
        $display("ready_5: %1b,",rs_entry_ready[5]);
        $display("ready_6: %1b,",rs_entry_ready[6]);
        $display("ready_7: %1b,",rs_entry_ready[7]);
        
        
        //$display("Current inst:%32h", is_packet_out.inst.inst);
        //$display("Current issue_inst_rob_entry:%8b", issue_inst_rob_entry);
        //$display("Current issue_candidate_rob_entry:%8b", issue_candidate_rob_entry);
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

        #1 assert(is_packet_out.inst.inst == 32'ha12acF12) else $display ("@@@FAILED@@@");
        assert(is_packet_out.rs1_value == 1) else $display ("@@@FAILED@@@");

        $display("rs1-value_322: %32h", is_packet_out.rs1_value);
        assert(is_packet_out.rs2_value == 1) else $display ("@@@FAILED@@@"); 
        $display("ROB_one_hot_bit_32'ha12acF12: %8b,",issue_candidate_rob_entry);
        $display("ready_0: %1b,",rs_entry_ready[0]);
        $display("ready_1: %1b,",rs_entry_ready[1]);
        $display("ready_2: %1b,",rs_entry_ready[2]);
        $display("ready_3: %1b,",rs_entry_ready[3]);
        $display("ready_4: %1b,",rs_entry_ready[4]);
        $display("ready_5: %1b,",rs_entry_ready[5]);
        $display("ready_6: %1b,",rs_entry_ready[6]);
        $display("ready_7: %1b,",rs_entry_ready[7]);
        
        

        //$display("Current inst:%32h", is_packet_out.inst.inst);
        //$display("Current issue_inst_rob_entry:%8b", issue_inst_rob_entry);
        //$display("Current issue_candidate_rob_entry:%8b", issue_candidate_rob_entry);

        @(negedge clock);
        #1 assert(is_packet_out.inst.inst == 32'hab2ccF12) else $display ("@@@FAILED@@@");  //test inst7
        $display("inst_330: %32h", is_packet_out.inst.inst);
        assert(is_packet_out.rs1_value == 60) else $display ("@@@FAILED@@@");
        $display("rs1-value_322: %32h", is_packet_out.rs1_value);
        assert(is_packet_out.rs2_value == 0) else $display ("@@@FAILED@@@");
        $display("ROB_one_hot_bit_32'hab2ccF12: %8b,",issue_candidate_rob_entry);
        //$display("Current inst:%32h", is_packet_out.inst.inst);
        //$display("Current issue_inst_rob_entry:%8b", issue_inst_rob_entry);
        //$display("Current issue_candidate_rob_entry:%8b", issue_candidate_rob_entry);

        @(negedge clock);
        #1 assert(is_packet_out.inst.inst == 32'hab2ccF12) else $display ("@@@FAILED@@@");  //test inst7
        assert(is_packet_out.rs1_value == 60) else $display ("@@@FAILED@@@");
        assert(is_packet_out.rs2_value == 0) else $display ("@@@FAILED@@@");
        $display("ROB_one_hot_bit_last: %8b,",issue_candidate_rob_entry);
        



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
        assert(is_packet_out.rs1_value == 20) else $display ("@@@FAILED@@@");
        assert(is_packet_out.rs2_value == 0) else $display ("@@@FAILED@@@");

        @(negedge clock);
//inst0
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
        assert(is_packet_out.rs1_value == 20) else $display ("@@@FAILED@@@");
        assert(is_packet_out.rs2_value == 0) else $display ("@@@FAILED@@@");


        @(negedge clock);
//inst0
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
        assert(is_packet_out.rs1_value == 0) else $display ("@@@FAILED@@@");
        assert(is_packet_out.rs2_value == 0) else $display ("@@@FAILED@@@");

        //reset 
        //start to test strutural hazard

        reset = 1;
        @(negedge clock);
        reset = 0;

    //stru inst1
        id_packet_in.inst.inst = 32'ha1111111;

        id_packet_in.rs1_value = 0;
        id_packet_in.rs2_value = 0;
        id_packet_in.dest_reg_idx = 1;
        //mt
        mt2rs_packet_in.rs1_tag = 1;
        mt2rs_packet_in.rs2_tag = 2;
        mt2rs_packet_in.rs1_ready = 0;
        mt2rs_packet_in.rs2_ready = 0;
        //cdb
        cdb_packet_in.reg_tag = 0;
        cdb_packet_in.reg_value = 0;
        //rob
        rob2rs_packet_in.rob_head_idx = 1;
        rob2rs_packet_in.rob_entry = 1;
        rob2rs_packet_in.rs1_value = 0;
        rob2rs_packet_in.rs2_value = 0;

        @(negedge clock);

    //stru inst2
        id_packet_in.inst.inst = 32'ha2222222;

        id_packet_in.rs1_value = 0;
        id_packet_in.rs2_value = 0;
        id_packet_in.dest_reg_idx = 2;
        //mt
        mt2rs_packet_in.rs1_tag = 2;
        mt2rs_packet_in.rs2_tag = 3;
        mt2rs_packet_in.rs1_ready = 0;
        mt2rs_packet_in.rs2_ready = 0;
        //cdb
        cdb_packet_in.reg_tag = 0;
        cdb_packet_in.reg_value = 0;
        //rob
        rob2rs_packet_in.rob_head_idx = 1;
        rob2rs_packet_in.rob_entry = 2;
        rob2rs_packet_in.rs1_value = 0;
        rob2rs_packet_in.rs2_value = 0;

        @(negedge clock);
    
    //stru inst3
        id_packet_in.inst.inst = 32'ha3333333;

        id_packet_in.rs1_value = 0;
        id_packet_in.rs2_value = 0;
        id_packet_in.dest_reg_idx = 3;
        //mt
        mt2rs_packet_in.rs1_tag = 3;
        mt2rs_packet_in.rs2_tag = 4;
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

        @(negedge clock);

    //stru inst4
        id_packet_in.inst.inst = 32'ha4444444;

        id_packet_in.rs1_value = 0;
        id_packet_in.rs2_value = 0;
        id_packet_in.dest_reg_idx = 4;
        //mt
        mt2rs_packet_in.rs1_tag = 4;
        mt2rs_packet_in.rs2_tag = 5;
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

    //stru inst5
        id_packet_in.inst.inst = 32'ha5555555;

        id_packet_in.rs1_value = 0;
        id_packet_in.rs2_value = 0;
        id_packet_in.dest_reg_idx = 5;
        //mt
        mt2rs_packet_in.rs1_tag = 5;
        mt2rs_packet_in.rs2_tag = 6;
        mt2rs_packet_in.rs1_ready = 0;
        mt2rs_packet_in.rs2_ready = 0;
        //cdb
        cdb_packet_in.reg_tag = 0;
        cdb_packet_in.reg_value = 0;
        //rob
        rob2rs_packet_in.rob_head_idx = 1;
        rob2rs_packet_in.rob_entry = 5;
        rob2rs_packet_in.rs1_value = 0;
        rob2rs_packet_in.rs2_value = 0;

        @(negedge clock);
    //stru inst6
        id_packet_in.inst.inst = 32'ha6666666;

        id_packet_in.rs1_value = 0;
        id_packet_in.rs2_value = 0;
        id_packet_in.dest_reg_idx = 6;
        //mt
        mt2rs_packet_in.rs1_tag = 6;
        mt2rs_packet_in.rs2_tag = 7;
        mt2rs_packet_in.rs1_ready = 0;
        mt2rs_packet_in.rs2_ready = 0;
        //cdb
        cdb_packet_in.reg_tag = 0;
        cdb_packet_in.reg_value = 0;
        //rob
        rob2rs_packet_in.rob_head_idx = 1;
        rob2rs_packet_in.rob_entry = 6;
        rob2rs_packet_in.rs1_value = 0;
        rob2rs_packet_in.rs2_value = 0;

        @(negedge clock);

    //stru inst7
        id_packet_in.inst.inst = 32'ha7777777;

        id_packet_in.rs1_value = 0;
        id_packet_in.rs2_value = 0;
        id_packet_in.dest_reg_idx = 7;
        //mt
        mt2rs_packet_in.rs1_tag = 7;
        mt2rs_packet_in.rs2_tag = 8;
        mt2rs_packet_in.rs1_ready = 0;
        mt2rs_packet_in.rs2_ready = 0;
        //cdb
        cdb_packet_in.reg_tag = 0;
        cdb_packet_in.reg_value = 0;
        //rob
        rob2rs_packet_in.rob_head_idx = 1;
        rob2rs_packet_in.rob_entry = 7;
        rob2rs_packet_in.rs1_value = 0;
        rob2rs_packet_in.rs2_value = 0;

        @(negedge clock);
    //stru inst8

        id_packet_in.inst.inst = 32'ha8888888;

        id_packet_in.rs1_value = 0;
        id_packet_in.rs2_value = 0;
        id_packet_in.dest_reg_idx = 8;
        //mt
        mt2rs_packet_in.rs1_tag = 8;
        mt2rs_packet_in.rs2_tag = 8;
        mt2rs_packet_in.rs1_ready = 0;
        mt2rs_packet_in.rs2_ready = 0;
        //cdb
        cdb_packet_in.reg_tag = 0;
        cdb_packet_in.reg_value = 0;
        //rob
        rob2rs_packet_in.rob_head_idx = 1;
        rob2rs_packet_in.rob_entry = 0;
        rob2rs_packet_in.rs1_value = 0;
        rob2rs_packet_in.rs2_value = 0;

        @(negedge clock);

        assert(Big_RS.valid == 0) else $display("@@@FAILED@@@"); //test structural hazard

        $display("@@@PASSED@@@");
        $finish;
    end

endmodule