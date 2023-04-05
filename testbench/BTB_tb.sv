
// `ifndef __FREELIST_TEST_SV__
// `define __FREELIST_TEST_SV__

//`define RS_ALLOCATE_DEBUG // test only allocating new entry in rs
`define DEBUG

`include "sys_defs.svh"
module testbench;

    logic 				            clock;
    logic 				            reset;

    IFID2BTB_PACKET if_packet_in; // valid indicates instruction is valid
    IFID2BTB_PACKET id_packet_in; // valid indicates currently on branch instruction
    FU2BTB_PACKET fu_packet_in; // valid indicates branch complete
    BTB_ENTRY [`BTB_LEN-1:0] bp_entries_display;
    BTB_ENTRY [`BTB_LEN-1:0] next_bp_entries_display;
    logic [31:0]                    cycle_count;
    BTB_PACKET btb_packet_out;


    BTB tbp(.clock(clock), .reset(reset), .if_packet_in(if_packet_in), .id_packet_in(id_packet_in), .id_packet_in(id_packet_in), .fu_packet_in(fu_packet_in), .bp_entries_display(bp_entries_display), .next_bp_entries_display(next_bp_entries_display), .btb_packet_out(btb_packet_out));

    always begin
		#5;
		clock = ~clock;
	end
    

    task show_branch_predictor;
        $display("####### Cycle %d ##########", cycle_count);
        $display("Current BP");
        for(int i=`BTB_LEN - 1; i>=0; i--) begin
            if (~bp_entries_display[i].busy) continue;
            $display("Index: %2d  Busy: %2d  Tag: %5d  State: %1d  Target_pc: %5d", i, bp_entries_display[i].busy, bp_entries_display[i].tag, bp_entries_display[i].state, bp_entries_display[i].target_pc);
        end
        $display("Next BP");
        for(int i=`BTB_LEN - 1; i>=0; i--) begin
            if (~next_bp_entries_display[i].busy) continue;
            $display("Index: %2d  Busy: %2d  Tag: %5d  State: %1d  Target_pc: %5d", i, next_bp_entries_display[i].busy, next_bp_entries_display[i].tag, next_bp_entries_display[i].state, next_bp_entries_display[i].target_pc);
        end
    endtask; // show_rs_table

    task show_input;
        begin
            $display("=====   Input   =====");
            $display("if_packet_in.valid: %b  id_packet_in.valid: %b", if_packet_in.valid, id_packet_in.valid);
            $display("if_packet_in.inst: %5d  id_packet_in.inst: %5d", if_packet_in.inst, id_packet_in.inst);

            $display("fu_packet_in.inst: %5d  fu_packet_in.taken: %1d  fu_packet_in.target_pc: %5d", fu_packet_in.inst, fu_packet_in.taken, fu_packet_in.target_pc);
        end
    endtask

    task show_output;
        begin
            $display("=====   Output   =====");
            $display("Predict_direction: %1d  Predict_pc: %5d", btb_packet_out.prediction, btb_packet_out.target_pc);
        end
    endtask


    always_ff@(posedge clock) begin
        if (reset)
            cycle_count <= 0;
        else 
            cycle_count <= cycle_count + 1;
    end

    
    always_ff@(negedge clock) begin
        show_branch_predictor();
        show_input();
        show_output();
    end

    initial begin
        //$dumpvars;
        clock = 1'b0;
        reset = 1'b1;
        fu_packet_in.valid = 1'b0;
        fu_packet_in.inst = 0;
        fu_packet_in.taken = 1'b0;
        fu_packet_in.target_pc = 0;
        id_packet_in.valid = 0;
        id_packet_in.inst = 0;
        if_packet_in.valid = 0;
        if_packet_in.inst = 0;
        
        @(negedge clock);
        reset = 0;

        @(posedge clock);
        if_packet_in.valid = 1'b1;
        if_packet_in.inst = 4;

        @(posedge clock);
        
        if_packet_in.inst = 16;
        id_packet_in.valid = 1'b1;
        id_packet_in.inst = 4;

        @(posedge clock);
        if_packet_in.valid = 0;
        fu_packet_in.valid = 1'b1;
        fu_packet_in.inst = 4;
        fu_packet_in.taken = 1'b1;
        fu_packet_in.target_pc = 80;
        #1
        id_packet_in.valid = 3'b101;
        id_packet_in.inst = 16;

        @(posedge clock);
        if_packet_in.valid = 3'b111;
        if_packet_in.inst = 4;
        #1
        id_packet_in.valid = 0;

        @(posedge clock);
        if_packet_in.valid = 0;
        id_packet_in.valid = 1'b1;
        id_packet_in.inst = 4;

        @(posedge clock);
        id_packet_in.valid = 0;
        fu_packet_in.valid = 1'b1;
        fu_packet_in.inst = 4;
        fu_packet_in.taken = 1'b1;
        fu_packet_in.target_pc = 80;

        @(posedge clock);
        if_packet_in.valid = 1'b1;
        if_packet_in.inst = 4;
        fu_packet_in.valid = 1'b0;
        

        @(posedge clock);
        if_packet_in.valid = 0;
        id_packet_in.valid = 3'b010;
        id_packet_in.inst = 4;

        @(posedge clock);
        id_packet_in.valid = 0;
        fu_packet_in.valid = 1'b1;
        fu_packet_in.inst = 4;
        fu_packet_in.taken = 1'b1;
        fu_packet_in.target_pc = 80;

        @(posedge clock);

        $finish;
    end

endmodule

//`endif