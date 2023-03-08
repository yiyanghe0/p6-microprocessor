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
`ifndef __RS_ENTRY_SV__
`define __RS_ENTRY_SV__
`timescale 1ns/100ps





// RS_entry is the dispatch stage
module RS_entry(
    input clock,
    input reset,
    input ID_PACKET id_packet_in, // invalid if wr_en = 0
    input MT2RS_PACKET mt2rs_packet_in, // invalid if wr_en = 0
    input CDB_PACKET cdb_packet_in, 
    input ROB2RS_PACKET rob2rs_packet_in, // invalid if wr_en = 0
    input clear,
    input wr_en,

    output IS_PACKET entry_packet, // this is the output of the dispatch stage and input of issue stage
    output logic busy,
    output logic ready
);

/*
What this module does:
splited into Dispatch and Issue stages 
Dispatch stage is the behavior of RS_entry for reading instruction to this RS_entry from Decoder
Issue stage is the behavior or RS_entry for issue out instruction currently in the RS_entry
1. Dispatch stage
    If wr_en is False,
    Do nothing if not busy, 
    If busy and cdb_packet.reg_tag 
    matches any one of entry_rs1_tag or entry_rs2_tag, update rs1_value/rs2_value to cdb_packet.reg_value
    and change the corresponding tag to 0, which indicates the value is ready

    IF wr_en is True,
    Load the entry_packet, cdb_packet, mt2rs_packet, rob_entry;
    gives out rs2mt_packet

2. Issue stage   
    Ready if entry_rs1_tag = 0 and entry_rs2_tag = 0
    If ready, assign s_x_packet, which should be mostly the same as entry_packet, except for
    needing to change rs1_value and rs2_value

Note: packets to ROB, Map Table and selection of RS_entry, issued s_x_packet should be in RS 

*/
    IS_PACKET next_entry_packet;

    logic [$clog2(`ROB_LEN)-1:0] entry_rs1_tag;
    logic [$clog2(`ROB_LEN)-1:0] next_entry_rs1_tag;

    logic [$clog2(`ROB_LEN)-1:0] entry_rs2_tag;
    logic [$clog2(`ROB_LEN)-1:0] next_entry_rs2_tag;

    logic next_busy;

    // register value signals for entry_packet
    assign next_entry_packet.NPC              = wr_en ? id_packet_in.NPC            : entry_packet.NPC;
    assign next_entry_packet.PC               = wr_en ? id_packet_in.PC             : entry_packet.PC;
    assign next_entry_packet.opa_select       = wr_en ? id_packet_in.opa_select     : entry_packet.opa_select;
    assign next_entry_packet.opb_select       = wr_en ? id_packet_in.opb_select     : entry_packet.opb_select;
    assign next_entry_packet.inst             = wr_en ? id_packet_in.inst           : entry_packet.inst;
    assign next_entry_packet.alu_func         = wr_en ? id_packet_in.alu_func       : entry_packet.alu_func;
    assign next_entry_packet.rd_mem           = wr_en ? id_packet_in.rd_mem         : entry_packet.rd_mem;
    assign next_entry_packet.wr_mem           = wr_en ? id_packet_in.wr_mem         : entry_packet.wr_mem;
    assign next_entry_packet.cond_branch      = wr_en ? id_packet_in.cond_branch    : entry_packet.cond_branch;
    assign next_entry_packet.uncond_branch    = wr_en ? id_packet_in.uncond_branch  : entry_packet.uncond_branch;
    assign next_entry_packet.halt             = wr_en ? id_packet_in.halt           : entry_packet.halt;
    assign next_entry_packet.illegal          = wr_en ? id_packet_in.illegal        : entry_packet.illegal;
    assign next_entry_packet.csr_op           = wr_en ? id_packet_in.csr_op         : entry_packet.csr_op;
    assign next_entry_packet.valid            = wr_en ? id_packet_in.valid          : entry_packet.valid;
    assign next_entry_packet.dest_reg_idx     = wr_en ? rob2rs_packet_in.rob_entry  : entry_packet.dest_reg_idx; // changed 

    // register values for next rs1 and rs2 tags
    // assign next_entry_rs1_tag = wr_en ? (mt2rs_packet_in.rs1_ready ? 0 :
    //                                                                  mt2rs_packet_in.rs1_idx) :                     // 0 if ready in MT
    //                                     ((busy && (cdb_packet_in.reg_tag == entry_rs1_tag)) ? 0 :
    //                                                                                           entry_rs1_tag);       // 0 if broadcasted by cdb
    //                                                                                                                 // entry_rs1_tag by default

    always_comb begin
        next_entry_rs1_tag = 0;
    
        if (wr_en) begin
            if (!mt2rs_packet_in.rs1_ready)
                next_entry_rs1_tag = mt2rs_packet_in.rs1_tag;
        end
        else if (!(busy && (cdb_packet_in.reg_tag == entry_rs1_tag)))
            next_entry_rs1_tag = entry_rs1_tag;
    end

    // assign next_entry_rs2_tag = wr_en ? (mt2rs_packet_in.rs2_ready ? 0 :
    //                                                                  mt2rs_packet_in.rs2_idx) :                     // 0 if ready in MT
    //                                     ((busy && (cdb_packet_in.reg_tag == entry_rs2_tag)) ? 0 :
    //                                                                                           entry_rs2_tag);       // 0 if broadcasted by cdb
    //                                                                                                                 // entry_rs2_tag by default

    always_comb begin
        next_entry_rs2_tag = 0;
    
        if (wr_en) begin
            if (!mt2rs_packet_in.rs2_ready)
                next_entry_rs2_tag = mt2rs_packet_in.rs2_tag;
        end
        else if (!(busy && (cdb_packet_in.reg_tag == entry_rs2_tag)))
            next_entry_rs2_tag = entry_rs2_tag;
    end

    // register values for next rs1 and rs2 values
    // assign next_entry_packet.rs1_value = wr_en ? ((next_entry_rs1_tag == 0 && mt2rs_packet_in.entry_rs1_tag != 0) ? rob2rs_packet_in.rs1_value : id_packet_in.rs1_value) :
    //                                         (busy && cdb_packet_in.reg_tag == entry_rs1_tag ? cdb_packet_in.reg_value : entry_packet.rs1_value);

    always_comb begin
        next_entry_packet.rs1_value = 0; // Arbitrary value for not ready rs1
    
        if (wr_en) begin
            if (next_entry_rs1_tag == 0)
                next_entry_packet.rs1_value = id_packet_in.rs1_value;  
        end
        else begin
            if (busy && (cdb_packet_in.reg_tag == entry_rs1_tag))
                next_entry_packet.rs1_value = cdb_packet_in.reg_value;
            else
                next_entry_packet.rs1_value = entry_packet.rs1_value;
        end
    end

    // assign next_entry_packet.rs2_value = wr_en ? ((next_entry_rs2_tag == 0 && mt2rs_packet_in.entry_rs2_tag != 0) ? rob2rs_packet_in.rs2_value : id_packet_in.rs2_value) :
    //                                         (busy && cdb_packet_in.reg_tag == entry_rs2_tag ? cdb_packet_in.reg_value : entry_packet.rs2_value);

    always_comb begin
        next_entry_packet.rs2_value = 0; // Arbitrary value for not ready rs1
    
        if (wr_en) begin
            if (next_entry_rs2_tag == 0)
                next_entry_packet.rs2_value = id_packet_in.rs2_value;  
        end
        else begin
            if (busy && (cdb_packet_in.reg_tag == entry_rs2_tag))
                next_entry_packet.rs2_value = cdb_packet_in.reg_value;
            else
                next_entry_packet.rs2_value = entry_packet.rs2_value;
        end
    end

    // ready
    assign ready = ((entry_rs1_tag == 0) && (entry_rs2_tag == 0)) ? 1 : 0; // ready will be set one cc after the instruction is loaded into the RS_entry

    // busy
    always_comb begin
        next_busy = busy;

        if (wr_en)
            next_busy = 1;
        else if (clear)
            next_busy = 0;
    end

    // Dispatch to issue stage
    // synopsys sync_set_reset "reset"
    always_ff @(posedge clock) begin
        if (reset) begin
            busy <= `SD 0;
            entry_packet <= `SD '{{`XLEN{1'b0}},
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
			};
            entry_rs1_tag <= `SD 0;
            entry_rs2_tag <= `SD 0;
        end
        else begin
            busy <= `SD next_busy;
            entry_packet <= `SD next_entry_packet;
            entry_rs1_tag <= `SD next_entry_rs1_tag;
            entry_rs2_tag <= `SD next_entry_rs2_tag;
        end
    end

endmodule // module RS_entry

`endif // __RS_ENTRY__SV
// It is quite ridiculous that the Dispatch/Issue pipeline is actually inside the RS_entry
// But this is how the lecture slides indicated
/*
"""
Inputs for RS_entry module: 
1. D_S_PACKET from ID/IS pipeline, which includes signals from decoder
2. ROB2RS_PACKET from ROB, which includes rob entry number, and rs1/rs2 values
3. MT2RS_PACKET from map table, which includes the current name of desired registers
4. CDB_PACKET from CDB, which includes broadcasted CDB values
5. clear, which indicates need to clear this RS_entry as it is issued
Note: clear is given on the execution stage of the instruction
6. enable, which tells this RS_entry to load instruction or not
7. clock & reset, of course
Note: enable is given on the dispatch stage of the instruction

Outputs for RS_entry module:
1. IS_PACKET to IS/EX pipeline, which includes signals that should be sent to FUs
2. busy, which indicate whether this RS_entry is currently in use
3. ready, indicate if the instruction in this RS_entry is ready to issue
Note: ready is 1 on the issue stage of the instruction
"""

module RS_entry(
    input clock;
    input reset;
    input ID_PACKET id_packet_in; // invalid if enable = 0
    input MT2RS_PACKET mt2rs_packet_in; // invalid if enable = 0
    input CDB_PACKET cdb_packet_in; 
    input ROB2RS_PACKET rob2rs_packet_in; // invalid if enable = 0
    input clear;
    input enable;

    output IS_PACKET d_s_packet;
    output busy;
    output ready;
);

"""
What this module does:
splited into Dispatch and Issue stages 
Dispatch stage is the behavior of RS_entry for reading instruction to this RS_entry from Decoder
Issue stage is the behavior or RS_entry for issue out instruction currently in the RS_entry
1. Dispatch stage
    If enable is False,
    Do nothing if not busy, 
    If busy and cdb_packet.reg_tag 
    matches any one of rs1_tag or rs2_tag, update rs1_value/rs2_value to cdb_packet.reg_value
    and change the corresponding tag to 0, which indicates the value is ready

    IF enable is True,
    Load the d_s_packet, cdb_packet, mt2rs_packet, rob_entry;
    gives out rs2mt_packet

2. Issue stage   
    Ready if rs1_tag = 0 and rs2_tag = 0
    If ready, assign s_x_packet, which should be mostly the same as d_s_packet, except for
    needing to change rs1_value and rs2_value

Note: packets to ROB, Map Table and selection of RS_entry, issued s_x_packet should be in RS 

"""
    logic IS_PACKET is_packet_out;
    logic [$clog2(`ROB_LEN)-1:0] rs1_tag;
    logic [$clog2(`ROB_LEN)-1:0] rs2_tag;
    logic [$clog2(`ROB_LEN)-1:0] next_rs1_tag;
    logic [$clog2(`ROB_LEN)-1:0] next_rs2_tag;

    // register value signals for is_packet_out
    assign d_s_packet.NPC              = enable ? id_packet_in.NPC            : is_packet_out.NPC;
    assign d_s_packet.PC               = enable ? id_packet_in.PC             : is_packet_out.PC;
    assign d_s_packet.opa_select       = enable ? id_packet_in.opa_select     : is_packet_out.opa_select;
    assign d_s_packet.opb_select       = enable ? id_packet_in.opb_select     : is_packet_out.opb_select;
    assign d_s_packet.inst             = enable ? id_packet_in.opa_inst       : is_packet_out.opa_inst;
    assign d_s_packet.alu_func         = enable ? id_packet_in.alu_func       : is_packet_out.alu_func;
    assign d_s_packet.rd_mem           = enable ? id_packet_in.rd_mem         : is_packet_out.rd_mem;
    assign d_s_packet.wr_mem           = enable ? id_packet_in.wr_mem         : is_packet_out.wr_mem;
    assign d_s_packet.cond_branch      = enable ? id_packet_in.cond_branch    : is_packet_out.cond_branch;
    assign d_s_packet.uncond_branch    = enable ? id_packet_in.uncond_branch  : is_packet_out.uncond_branch;
    assign d_s_packet.halt             = enable ? id_packet_in.halt           : is_packet_out.halt;
    assign d_s_packet.illegal          = enable ? id_packet_in.illegal        : is_packet_out.illegal;
    assign d_s_packet.csr_op           = enable ? id_packet_in.csr_op         : is_packet_out.csr_op;
    assign d_s_packet.valid            = enable ? id_packet_in.valid          : is_packet_out.valid;
    assign d_s_packet.dest_reg_idx     = enable ? rob2rs_packet_in.rob_entry  : is_packet_out.dest_reg_idx; // changed 

    // assign d_s_packet.NPC              = id_packet_in.NPC;
    // assign d_s_packet.PC               = id_packet_in.PC;
    // assign d_s_packet.opa_select       = id_packet_in.opa_select;
    // assign d_s_packet.opb_select       = id_packet_in.opb_select;
    // assign d_s_packet.inst             = id_packet_in.opa_inst;
    // assign d_s_packet.alu_func         = id_packet_in.alu_func;
    // assign d_s_packet.rd_mem           = id_packet_in.rd_mem;
    // assign d_s_packet.wr_mem           = id_packet_in.wr_mem;
    // assign d_s_packet.cond_branch      = id_packet_in.cond_branch;
    // assign d_s_packet.uncond_branch    = id_packet_in.uncond_branch;
    // assign d_s_packet.halt             = id_packet_in.halt;
    // assign d_s_packet.illegal          = id_packet_in.illegal;
    // assign d_s_packet.csr_op           = id_packet_in.csr_op;
    // assign d_s_packet.valid            = id_packet_in.valid;
    // assign d_s_packet.dest_reg_idx     = rob2rs_packet_in.rob_entry;

    // register values for rs1 and rs2 tags
    assign next_rs1_tag = enable ? (mt2rs_packet_in.rs1_ready ? 0 : mt2rs_packet_in.rs1_idx) :  // 0 if ready in MT
                                   ((busy && (cdb_packet_in.reg_tag == rs1_tag)) ? 0 : rs1_tag);// 0 if broadcasted by cdb
                                                                                                // rs1_tag by default
    // always_comb begin
    //     if (mt2rs_packet_in.rs1_ready)
    //         next_rs1_tag = 0;
    //     else if (busy && (cdb_packet_in.reg_tag == rs1_tag))
    //         next_rs1_tag = 0;
    //     else
    //         next_rs1_tag = mt2rs_packet_in.rs1_idx;
    // end
    assign next_rs2_tag = enable ? (mt2rs_packet_in.rs2_ready ? 0 : mt2rs_packet_in.rs2_idx) :  // 0 if ready in MT
                                   ((busy && (cdb_packet_in.reg_tag == rs2_tag)) ? 0 : rs2_tag);// 0 if broadcasted by cdb
                                                                                                // rs2_tag by default

    // register values for rs1 and rs2 values
    // !!! perhaps it is not good to use next_rs1_tag to determine next_rs1_value?
    assign d_s_packet.rs1_value = enable ? ((next_rs1_tag == 0 && mt2rs_packet_in.rs1_tag != 0) ? rob2rs_packet_in.rs1_value : id_packet_in.rs1_value) :
                                            (busy && cdb_packet_in.reg_tag == rs1_tag ? cdb_packet_in.reg_value : is_packet_out.rs1_value);
    assign d_s_packet.rs2_value = enable ? ((next_rs2_tag == 0 && mt2rs_packet_in.rs2_tag != 0) ? rob2rs_packet_in.rs2_value : id_packet_in.rs2_value) :
                                            (busy && cdb_packet_in.reg_tag == rs2_tag ? cdb_packet_in.reg_value : is_packet_out.rs2_value);

    // logic for Issue stage
    assign ready = (!rs1_tag && !rs2_tag) ? 1 : 0; // ready will be set one cc after the instruction is loaded into the RS_entry

    // logic for registers
    // synopsys sync_set_reset "reset"
    always_ff @(posedge clock) begin
        if (reset) begin
            busy <= `SD 0;
        end
        else if (enable) begin
            busy <= `SD 1;
        end
        else if (clear) begin // do not clear if enable and clear is 1 at the same time
            busy <= `SD 0;
        end
        else begin
            is_packet_out <= `SD d_s_packet; // this is the dispatch/issue pipeline
            rs1_tag <= `SD next_rs1_tag;
            rs2_tag <= `SD next_rs2_tag;
        end
    end

endmodule // module RS_entry
*/

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
module RegisterStation(
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

    IS_PACKET [`RS_LEN-1:0] rs_entry_packet_out;

    logic valid; // if valid = 0, rs encountered structural hazard and has to stall

    logic [`RS_LEN-1:0] issue_candidate_rob_entry; // one-hot encoding of rs_entry_packet_out.dest_reg_idx
    logic [`RS_LEN-1:0] issue_inst_rob_entry; // one-hot encoding of rob_entry of the inst issued


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
        .clock({`RS_LEN {clock}}),
        .reset({`RS_LEN {reset}}),
        .id_packet_in({`RS_LEN {id_packet_in}}),
        .mt2rs_packet_in({`RS_LEN {mt2rs_packet_in}}),
        .cdb_packet_in({`RS_LEN {cdb_packet_in}}),
        .rob2rs_packet_in({`RS_LEN {rob2rs_packet_in}}),
        // different rs_entry has different clear and enable
        .clear(rs_entry_clear_in),
        .wr_en(rs_entry_enable),

        .entry_packet(rs_entry_packet_out),
        .busy(rs_entry_busy),
        .ready(rs_entry_ready)
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
        for (int i = 0; i < `RS_LEN; i++) begin
            for (int j = 0; j < `ROB_LEN; j++) begin
                if (rs_entry_ready[i] & rs_entry_packet_out[i].dest_reg_idx == j)
                    issue_candidate_rob_entry[j] = 1;
                    rs_entry_rob_entry[i][j] = 1;
            end
        end
    end


    // Issue according to issue_inst_rob_entry
    // !!! two ouputs
    always_comb begin
        is_packet_out = 0; // or a nop instruction
        for (int i = 0; i < `RS_LEN; i++) begin
            if (issue_inst_rob_entry == rs_entry_rob_entry[i]) begin
                is_packet_out = rs_entry_packet_out[i];
                rs_entry_clear_out[i] = 1;
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
            if (~rs_entry_busy[i]) begin
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

    


endmodule // module RegisterStation

`endif // __RS_SV__