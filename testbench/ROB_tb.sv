/////////////////////////////////////////////////////////////////////////
//                                                                     //
//   Modulename :  ROB_tb.sv                                           //
//                                                                     //
//  Description :  An  testbench for the ROB module                    //
//                                                                     //
/////////////////////////////////////////////////////////////////////////

`include "sys_defs.svh"
`define DEBUG

module 	ROB_tb;

	//integer i;
	//logic [31:0] a, b;
	logic clock, reset;
	logic [$clog2(`ROB_LEN)-1:0] head_idx;            // store ROB head idx
	logic [$clog2(`ROB_LEN)-1:0] tail_idx;            // store ROB tail idx
	logic [`ROB_LEN-1:0] rob_entry_wr_en;
	logic [`ROB_LEN-1:0] rob_entry_wr_value;
	logic [`ROB_LEN-1:0] rob_entry_clear;
	logic 					rob_struc_hazard;
	
	RS2ROB_PACKET rob2rs_packet_in;
	CDB_PACKET cdb_packet_in;
	ID_PACKET  id_packet_in;

	ROB2RS_PACKET rob2rs_packet_out;
   ROB2MT_PACKET rob2mt_packet_out;    // update tag in MT 
   ROB2REG_PACKET rob2reg_packet_out;   // retire 
   ROB_entry_PACKET [`ROB_LEN-1:0] rob_entry_packet_out;
	MISPREDICT_ROB_PACKET mispredict_packet_in;

	ROB ROB_0(
		.clock(clock),
		.reset(reset),
		.rs2rob_packet_in(rob2rs_packet_in),  // note: this testbench was stolen from project 2
		.cdb_packet_in(cdb_packet_in), // and is not a comprehensive testbench for a signed multiplier
		.id_packet_in(id_packet_in),
		.mispredict_packet_in (mispredict_packet_in),
		.head_idx(head_idx),
		.tail_idx(tail_idx),
		.rob_entry_wr_en(rob_entry_wr_en),
		.rob_struc_hazard(rob_struc_hazard),
		.rob_entry_wr_value(rob_entry_wr_value),
		.rob2rs_packet_out(rob2rs_packet_out),
		.rob2mt_packet_out(rob2mt_packet_out),
		.rob2reg_packet_out(rob2reg_packet_out),
		.rob_entry_packet_out(rob_entry_packet_out)
	);


	task exit_on_error;
		     input [$clog2(`ROB_LEN)-1:0] correct_head, correct_tail;    // manual input
		     begin
		         $display("@@@ Incorrect at time %4.0f", $time);
		         $display("@@@ Time:%4.0f reset:%b id_packet_in.valid: %b head_idx:%b tail_idx:%b", $time, reset, id_packet_in.valid, head_idx, tail_idx);
		         $display("@@@ rob_entry_wr_en:%b rob_entry_wr_value: %b", rob_entry_wr_en, rob_entry_wr_value);
		         $display("@@@ expected head: %b, expected tail: %b", correct_head, correct_tail);
		         $display("@@@failed");
		         $finish;
		     end
	endtask
	
	task check_ROB;
			input [$clog2(`ROB_LEN)-1:0] correct_head, correct_tail;    // manual input 
			begin
				assert (head_idx == correct_head)	else exit_on_error(correct_head, correct_tail);
				assert (tail_idx == correct_tail)	else exit_on_error(correct_head, correct_tail);				
			end
	endtask

	 always begin
        #5;
        clock = ~clock;
    end

// xxns: xxxx means what has been done the rising edge before 
	initial begin
		reset = 1;
		clock = 0;
		id_packet_in.valid = 1'b1;  
		mispredict_packet_in = 0;
		cdb_packet_in.reg_tag.valid = 1'b0;
		cdb_packet_in.reg_tag.tag = 3'b000;
		id_packet_in.dest_reg_idx = 5'b00010; // entry0: r2
		@(negedge clock);  // 10ns: reset
		reset = 0;		
		@(negedge clock);  // 20ns: assign ROB #0 to r2 
		check_ROB(0,1);

		id_packet_in.dest_reg_idx = 5'b00011; // entry1: r3
		
		@(negedge clock);  // 30ns: assign ROB #1 to r3
		$display("@@@rob_0_dest_reg_idx = %b", ROB_0.rob_entry[0].dest_reg_idx);			
		check_ROB(0,2);
		
		cdb_packet_in.reg_tag.valid = 1'b1;
		cdb_packet_in.reg_value = 32'h0000000A;
		
		id_packet_in.dest_reg_idx = 5'b00100; // entry2: r4
		
		$display("@@@retire = %b", ROB_0.retire);			
		$display("@@@next_head30 = %8b", ROB_0.next_head);			
		
		@(negedge clock);  // 40ns: complete ROB #0; assign ROB #2 to r4
		$display("@@@next_head40 = %8b", ROB_0.next_head);	
		$display("@@@retire = %b", ROB_0.retire);					
		check_ROB(1,3);
		
		cdb_packet_in.reg_tag.tag = 3'b001;
		cdb_packet_in.reg_value = 32'h0000000B;
		
		id_packet_in.valid = 1'b0;  
		
		@(negedge clock);  // 50ns: retire ROB #0; complete ROB #1; NO NEW ASSIGN


		check_ROB(2,3);

		cdb_packet_in.reg_tag.valid = 1'b0;
		cdb_packet_in.reg_value = 32'h00000000;
		cdb_packet_in.reg_tag.tag = 0;

		id_packet_in.valid = 1'b1;		
		id_packet_in.dest_reg_idx = 5'b00101; // entry3: r5 
		$display("@@@next_head50 = %8b", ROB_0.next_head);
		$display("@@@retire = %b", ROB_0.retire);			
		@(negedge clock);  // 60ns: retire ROB #1 assign ROB #3 to r5
		check_ROB(2,4);

		id_packet_in.dest_reg_idx = 5'b00110; // entry4: r6 

		@(negedge clock);  // 70ns: assign ROB #4 to r6
		check_ROB(2,5);

		id_packet_in.dest_reg_idx = 5'b00111; // entry5: r7

		@(negedge clock);  // 80ns: assign ROB #5 to r7
		check_ROB(2,6);

		id_packet_in.dest_reg_idx = 5'b01000; // entry6: r8

		cdb_packet_in.reg_tag.valid = 1'b1;
		cdb_packet_in.reg_value = 32'h0000001A;
		cdb_packet_in.reg_tag.tag = 4;


		@(negedge clock);  // 90ns: complete ROB #4 assign ROB #6 to r8
		check_ROB(2,7);

		id_packet_in.dest_reg_idx = 5'b01001; // entry7: r9

		cdb_packet_in.reg_value = 32'h0000000D;
		cdb_packet_in.reg_tag.tag = 3;

		@(negedge clock);  // 100ns: complete ROB #3 assign ROB #7 to r9
		check_ROB(2,0);
		
		id_packet_in.dest_reg_idx = 5'b01010; // entry0: r10

		mispredict_packet_in.mispredict_rob_entry_idx.valid = 1'b1;
		mispredict_packet_in.mispredict_rob_entry_idx.tag = 3'b011;

		@(negedge clock); // 110ns: assign ROB #0 to r10 & ROB #3 IS MISPREDICTED
		check_ROB(2,1);

		id_packet_in.dest_reg_idx = 5'b01011; // entry1: r11

		@(negedge clock); // 120ns: assign ROB #1 to r11 STRUCTURAL HAZARD
		check_ROB(2,2);
		assert (rob_struc_hazard == 1'b1)	else begin $display("@@@failed struc hazard@@@"); $finish; end

		cdb_packet_in.reg_tag.valid = 1'b1;
		cdb_packet_in.reg_value = 32'h0000000C;
		cdb_packet_in.reg_tag.tag = 2;

		@(negedge clock);  // 130ns: complete & retire ROB #2 squash signal is asserted
		check_ROB(3,2);
		assert (rob2mt_packet_out.squash == 1'b1)	else begin $display("@@@fail to squash@@@"); $finish; end

		@(negedge clock); // 140ns: head_idx & tail_idx back to 0
		check_ROB(0,0);
		$display("@@@successfully squashed@@@");
		

		$display("@@@Passed");
		$finish;
	end

endmodule // module mult_tb
