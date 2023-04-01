/////////////////////////////////////////////////////////////////////////
//                                                                     //
//   Modulename :  rs.v                                                //
//                                                                     //
//  Description :  instruction decode (ID) stage of the pipeline;      //
//                 decode the instruction fetch register operands, and //
//                 compute immediate operand (if applicable)           //
//                                                                     //
/////////////////////////////////////////////////////////////////////////

`ifndef __RS_SV__
`define __RS_SV__
`define DEBUG

`include "sys_defs.svh"



// It is quite ridiculous that the Dispatch/Issue pipeline is actually inside the RS_entry
// But this is how the lecture slides indicated

/*
Add rps16 if necessary
Bits of rps should equal `ROB_LEN
*/

/*
Inputs for RegisterStation:
1. ID_PACKET from decoder, same as RS_entry
2. ROB2RS_PACKET from ROB, same as RS_entry
3. MT2RS_PACKET from Map Table, same as RS_entry
4. CDB_PACKET from CDB, same as RS_entry
5. rs_entry_clear_idx from EX stage, indicating an instruction
    in rs_entry should be cleared
6. clock & reset, of course

Outputs for RegisterStation
1. RS2ROB_PACKET to ROB, include valid, rs_idx
2. RS2MT_PACKET to Map Table, include rs_idx and dest_reg_idx, dest_reg_tag
3. IS_PACKET to S_X pipeline
4. rs_entry_issue_idx, the index of the rs_entry issued in this clock cycle

*/
module RS(
    input clock,
    input reset,
    input squash,
    input stall,
    input ID_PACKET id_packet_in,
    input ROB2RS_PACKET rob2rs_packet_in,
    input MT2RS_PACKET mt2rs_packet_in,
    input CDB_PACKET cdb_packet_in,    

    `ifdef DEBUG
    output logic [`RS_LEN-1:0] rs_entry_enable, 
    output logic [`RS_LEN-1:0] rs_entry_busy,
    output logic [`RS_LEN-1:0] rs_entry_ready,

    output logic [$clog2(`RS_LEN)-1:0] issue_inst_rs_entry,
    output logic [`ROB_LEN-1:0] issue_candidate_rob_entry, // one-hot encoding of rs_entry_packet_out.dest_reg_idx
    output logic [`ROB_LEN-1:0] issue_inst_rob_entry, // one-hot encoding of rob_entry of the inst issued

    output logic [`RS_LEN-1:0][`ROB_LEN-1:0] rs_entry_rob_entry,

    output IS_PACKET [`RS_LEN-1:0] rs_entry_packet_out,
    
    output logic [`RS_LEN-1:0] rs_entry_clear,

    output TAG_PACKET [`RS_LEN-1:0] entry_rs1_tags,
    output TAG_PACKET [`RS_LEN-1:0] entry_rs2_tags,
    `endif

    output RS2ROB_PACKET rs2rob_packet_out,
    output RS2MT_PACKET rs2mt_packet_out,
    output IS_PACKET is_packet_out,
    
    output logic valid // if valid = 0, rs encountered structural hazard and has to stall
);
/*
What this module does:
This module covers dispatch stage and issue stage

Dispatch Stage: 
Receive packed instruction from decoder
Select RS_entry the instruction should go to using loop (or priority selector)
Clear RS_entry if instruction is issued in the previous stage
Give out RS2ROB_PACKET to ROB, RS2MT_PACKET to Map Table

Issue Stage:
Use rotational priority selector to select issued instruction
Output the index of the RS_entry that issued instruction

*/
    // logic [`RS_LEN-1:0] rs_entry_clear;
    `ifndef DEBUG
    logic [`RS_LEN-1:0] rs_entry_enable; 
    logic [`RS_LEN-1:0] rs_entry_busy;
    logic [`RS_LEN-1:0] rs_entry_ready;

    logic [$clog2(`RS_LEN)-1:0] issue_inst_rs_entry;
    logic [`ROB_LEN-1:0] issue_candidate_rob_entry; // one-hot encoding of rs_entry_packet_out.dest_reg_idx
    logic [`ROB_LEN-1:0] issue_inst_rob_entry; // one-hot encoding of rob_entry of the inst issued

    logic [`RS_LEN-1:0][`ROB_LEN-1:0] rs_entry_rob_entry;

    IS_PACKET [`RS_LEN-1:0] rs_entry_packet_out;
    `endif

    FLAG [`RS_LEN-1:0] rs_flags;

    logic [`RS_LEN-1:0] rs_entry_clear_in;
    logic [`RS_LEN-1:0] rs_entry_clear_out;

    assign rs_entry_clear_in = rs_entry_clear_out;

    `ifdef DEBUG
        assign rs_entry_clear = rs_entry_clear_in;
    `endif

    // output packages
    assign rs2mt_packet_out.rs1_idx            = id_packet_in.inst.r.rs1;
    assign rs2mt_packet_out.rs2_idx            = id_packet_in.inst.r.rs2;
    assign rs2mt_packet_out.dest_reg_idx       = id_packet_in.dest_reg_idx;
    assign rs2mt_packet_out.dest_reg_tag.tag   = (id_packet_in.dest_reg_idx == `ZERO_REG) ? 0 : rob2rs_packet_in.rob_entry;
    assign rs2mt_packet_out.dest_reg_tag.valid = (id_packet_in.dest_reg_idx == `ZERO_REG) ? 0 : 1;

    assign rs2rob_packet_out.valid          = valid;
    assign rs2rob_packet_out.rs1_idx        = mt2rs_packet_in.rs1_tag.tag;
    assign rs2rob_packet_out.rs2_idx        = mt2rs_packet_in.rs2_tag.tag;

    RS_entry rs_entry [`RS_LEN-1:0] (
        // all rs_entry share the same input packets
        .clock(clock),
        .reset(reset),
        .squash(squash),
        .id_packet_in(id_packet_in),
        .mt2rs_packet_in(mt2rs_packet_in),
        .cdb_packet_in(cdb_packet_in),
        .rob2rs_packet_in(rob2rs_packet_in),
        // different rs_entry has different clear and enable
        .clear(rs_entry_clear_in),
        .wr_en(rs_entry_enable),

        .entry_packet(rs_entry_packet_out),
        .busy(rs_entry_busy),
        .ready(rs_entry_ready),

        `ifdef DEBUG
        .entry_rs1_tag(entry_rs1_tags),
        .entry_rs2_tag(entry_rs2_tags),
        `endif

        .flag(rs_flags)
    );

    // wire reserved_wire;
    // rps8 rps8_0( // have two outputs
    //     .req(issue_candidate_rob_entry),
    //     .en(1'b1), // always enabled
    //     .sel(rob2rs_packet_in.rob_head_idx),
    //     .gnt(issue_inst_rob_entry),
    //     .req_up(reserved_wire) // some wire that has no use
    // );
    integer available_assignment = `SUPERSCALER_LEN;
    always_comb begin
        integer i;
        available_assignment = `SUPERSCALER_LEN; //2
        issue_inst_rob_entry = 0;
        for (i = 0; i < `ROB_LEN; i++) begin
            integer curr_rob_entry = i;
            for (int j = 0; j < `ROB_LEN; j++) begin
                if (j == rob2rs_packet_in.rob_head_idx) curr_rob_entry = i + j;
            end
            if (curr_rob_entry >= `ROB_LEN) curr_rob_entry = curr_rob_entry - `ROB_LEN;
            if (issue_candidate_rob_entry[curr_rob_entry] == 1) begin
                issue_inst_rob_entry[curr_rob_entry] = 1;
                available_assignment = available_assignment - 1;
                if (available_assignment == 0) break;
            end
        end
    end

    
    // Find issue_candidate_rob_entry
    always_comb begin
        issue_candidate_rob_entry = 0;
        rs_entry_rob_entry = 0;
        for (int i = 0; i < `RS_LEN; i++) begin
            for (int j = 0; j < `ROB_LEN; j++) begin
                if (rs_entry_ready[i] && rs_entry_packet_out[i].dest_reg_idx == j) begin
                    issue_candidate_rob_entry[j] = 1;
                    rs_entry_rob_entry[i][j] = 1;
                end
            end
        end
    end

    //logic [$clog2(`RS_LEN)-1:0] issue_inst_rs_entry;

    // Issue according to issue_inst_rob_entry
    // !!! two ouputs
    always_comb begin
        is_packet_out = '{{`XLEN{1'b0}},
				{`XLEN{1'b0}},
				{`XLEN{1'b0}},
				{`XLEN{1'b0}},
				OPA_IS_RS1,
				OPB_IS_RS2,
				`NOP,
				`ZERO_REG,
				ALU_ADD,
				1'b0, // rd_mem
				1'b0, // wr_mem
				1'b0, // cond
				1'b0, // uncond
				1'b0, // halt
				1'b0, // illegal
				1'b0, // csr_op
				1'b0, // valid
                1'b1, // is_ZEROREG
                ALU   // channel
			}; // or a nop instruction
        rs_entry_clear_out = 0;
        issue_inst_rs_entry = 0;

        for (int i = 0; i < `RS_LEN; i++) begin
            if ((issue_inst_rob_entry == rs_entry_rob_entry[i]) && (issue_inst_rob_entry != 0)) begin
                is_packet_out = rs_entry_packet_out[i];
                if ((rs_flags[i] == CDBTAG) || (rs_flags[i] == CDBCDB))
                    is_packet_out.rs1_value = cdb_packet_in.reg_value;
                
                if ((rs_flags[i] == TAGCDB) || (rs_flags[i] == CDBCDB))
                    is_packet_out.rs2_value = cdb_packet_in.reg_value;
                
                if (!stall)
                    rs_entry_clear_out[i] = 1;
                issue_inst_rs_entry = i;
                break;
            end
        end
    end

    // loop to find which RS_entry to assign
    // can also use ps_RS_LEN (priority selector)
    // !!! two ouptuts
    always_comb begin
        rs_entry_enable = 0; // default: all 0
        valid           = 0;
        for (int i = 0; i < `RS_LEN; i++) begin
            if (~rs_entry_busy[i] || ((issue_inst_rs_entry == i) && rs_entry_ready[i] && !stall)) begin
                rs_entry_enable[i]  = 1; // set this rs_entry to load instruction
                valid               = 1;
                break;
            end
        end
    end

    // Find rs_entry that should be cleared
    // !!! a better way to do this?
    // always_comb begin
    //     rs_entry_clear = 0;
    //     for (int i = 0; i < `RS_LEN; i++) begin
    //         if (rs_entry_clear_idx == i) begin
    //             rs_entry_clear[i]   = 1; // clear this rs_entry 
    //             break;
    //         end
    //     end
    // end

endmodule // module RS

`endif // __RS_SV__
