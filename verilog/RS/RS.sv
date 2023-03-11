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


`include "sys_defs.svh"



// It is quite ridiculous that the Dispatch/Issue pipeline is actually inside the RS_entry
// But this is how the lecture slides indicated

/*
Rotational 2-bit Priority Selector from Project1
Detailed explanation can be found in Project1 Description
*/
module rps2(
    input [1:0] req,
    input en,
    input sel,
    output logic [1:0] gnt,
    output logic req_up
);
    logic [1:0] temp;
    assign req_up = req[0] | req[1];
    assign gnt[0] = en ? (sel ? (gnt[1] ? 0 : (req[0] ? 1 : 0)) : (req[0] ? 1 : 0)) : 0;
    assign gnt[1] = en ? (sel ? (req[1] ? 1 : 0) : (gnt[0] ? 0 : (req[1] ? 1 : 0))) : 0; 
endmodule

/*
Rotational 4-bit Priority Selector modified from Project1
Graph can be seen on Project1 Description
*/
module rps4(
    input [3:0] req,
    input en,
    input [1:0] sel,
    output logic [3:0] gnt,
    output logic req_up
);
    logic [1:0] req_up2req;
    logic [1:0] gnt2en;

    rps2 left(.req(req[1:0]), .en(gnt2en[0]), .sel(sel[0]), .gnt(gnt[1:0]), .req_up(req_up2req[0]));
    rps2 right(.req(req[3:2]), .en(gnt2en[1]), .sel(sel[0]), .gnt(gnt[3:2]), .req_up(req_up2req[1]));
    rps2 top(.req(req_up2req[1:0]), .en(en), .sel(sel[1]), .gnt(gnt2en[1:0]), .req_up(req_up));
endmodule

/*
Rotational 8-bit Priority Selector
Use two 4-bit and one 2-bit Priority Selector
Similar to the design of rps4 
*/
module rps8(
    input [7:0] req,
    input en,
    input [2:0] sel,
    output logic [7:0] gnt,
    output logic req_up
);
    logic [1:0] req_up2req;
    logic [1:0] gnt2en;

    rps4 left(.req(req[3:0]), .en(gnt2en[0]), .sel(sel[1:0]), .gnt(gnt[3:0]), .req_up(req_up2req[0]));
    rps4 right(.req(req[7:4]), .en(gnt2en[1]), .sel(sel[1:0]), .gnt(gnt[7:4]), .req_up(req_up2req[1]));
    rps2 top(.req(req_up2req[1:0]), .en(en), .sel(sel[2]), .gnt(gnt2en[1:0]), .req_up(req_up));
endmodule

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
    input ID_PACKET id_packet_in,
    input ROB2RS_PACKET rob2rs_packet_in,
    input MT2RS_PACKET mt2rs_packet_in,
    input CDB_PACKET cdb_packet_in,
    input [`RS_LEN-1:0] rs_entry_clear_in,
    
    output RS2ROB_PACKET rs2rob_packet_out,
    output RS2MT_PACKET rs2mt_packet_out,
    output IS_PACKET is_packet_out,
    output logic [`RS_LEN-1:0] rs_entry_clear_out
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
    logic [`RS_LEN-1:0] rs_entry_enable; 
    logic [`RS_LEN-1:0] rs_entry_busy;
    logic [`RS_LEN-1:0] rs_entry_ready;
    FLAG [`RS_LEN-1:0] rs_flags;

    IS_PACKET [`RS_LEN-1:0] rs_entry_packet_out;

    logic valid; // if valid = 0, rs encountered structural hazard and has to stall

    logic [`ROB_LEN-1:0] issue_candidate_rob_entry; // one-hot encoding of rs_entry_packet_out.dest_reg_idx
    logic [`ROB_LEN-1:0] issue_inst_rob_entry; // one-hot encoding of rob_entry of the inst issued


    // output packages
    assign rs2mt_packet_out.rs1_idx         = id_packet_in.inst.r.rs1;
    assign rs2mt_packet_out.rs2_idx         = id_packet_in.inst.r.rs2;
    assign rs2mt_packet_out.dest_reg_idx    = id_packet_in.dest_reg_idx;
    assign rs2mt_packet_out.dest_reg_tag    = rob2rs_packet_in.rob_entry;

    assign rs2rob_packet_out.valid          = valid;
    assign rs2rob_packet_out.rs1_idx        = mt2rs_packet_in.rs1_tag;
    assign rs2rob_packet_out.rs2_idx        = mt2rs_packet_in.rs2_tag;

    RS_entry rs_entry [`RS_LEN-1:0] (
        // all rs_entry share the same input packets
        .clock(clock),
        .reset(reset),
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

        .flag(rs_flags)
    );

    wire reserved_wire;
    rps8 rps8_0( // have two outputs
        .req(issue_candidate_rob_entry),
        .en(1'b1), // always enabled
        .sel(rob2rs_packet_in.rob_head_idx),
        .gnt(issue_inst_rob_entry),
        .req_up(reserved_wire) // some wire that has no use
    );

    logic [`RS_LEN-1:0][`ROB_LEN-1:0] rs_entry_rob_entry;
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

    logic [$clog2(`RS_LEN)-1:0] issue_inst_rs_entry;

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
				1'b0  // valid
			}; // or a nop instruction
        rs_entry_clear_out = 0;
        issue_inst_rs_entry = 0;

        for (int i = 0; i < `RS_LEN; i++) begin
            if ((issue_inst_rob_entry == rs_entry_rob_entry[i]) && (issue_inst_rob_entry != 0)) begin
                is_packet_out = rs_entry_packet_out[i];
                if ((rs_flags == CDBTAG) || (rs_flags == CDBCDB))
                    is_packet_out.rs1_value = cdb_packet_in.reg_value;
                
                if ((rs_flags == TAGCDB) || (rs_flags == CDBCDB))
                    is_packet_out.rs2_value = cdb_packet_in.reg_value;
                
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
            if (~rs_entry_busy[i] || ((issue_inst_rs_entry == i) && rs_entry_ready[i])) begin
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