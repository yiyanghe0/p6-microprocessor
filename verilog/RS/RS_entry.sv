`ifndef __RS_ENTRY_SV__
`define __RS_ENTRY_SV__

`define DEBUG

`include "sys_defs.svh"

// RS_entry is the dispatch stage
module RS_entry(
    input clock,
    input reset,
    input squash,
    input ID_PACKET id_packet_in, // invalid if wr_en = 0
    input MT2RS_PACKET mt2rs_packet_in, // invalid if wr_en = 0
    input CDB_PACKET cdb_packet_in, 
    input ROB2RS_PACKET rob2rs_packet_in, // invalid if wr_en = 0
    input clear,
    input wr_en,

    output IS_PACKET entry_packet, // this is the output of the dispatch stage and input of issue stage
    output logic busy,
    output logic ready,

    `ifdef DEBUG
    output TAG_PACKET entry_rs1_tag,
    output TAG_PACKET entry_rs2_tag,
    `endif

    output FLAG flag // when cdb write through, corresponding flag will be raised
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

    `ifndef DEBUG
    // logic [$clog2(`ROB_LEN)-1:0] entry_rs1_tag;
    // logic [$clog2(`ROB_LEN)-1:0] entry_rs2_tag;
    TAG_PACKET entry_rs1_tag;
    TAG_PACKET entry_rs2_tag;
    `endif

    TAG_PACKET next_entry_rs1_tag;
    TAG_PACKET next_entry_rs2_tag;
    // logic [$clog2(`ROB_LEN)-1:0] next_entry_rs1_tag;
    // logic [$clog2(`ROB_LEN)-1:0] next_entry_rs2_tag;

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
    assign next_entry_packet.dest_reg_idx     = wr_en ? ((id_packet_in.dest_reg_idx == `ZERO_REG && id_packet_in.cond_branch == 1'b0 ) ? 0 : rob2rs_packet_in.rob_entry) : entry_packet.dest_reg_idx; // changed
    assign next_entry_packet.channel          = wr_en ? id_packet_in.channel        : entry_packet.channel;
    assign next_entry_packet.is_ZEROREG       = wr_en ? ((id_packet_in.dest_reg_idx == `ZERO_REG && id_packet_in.cond_branch == 1'b0) ? 1 : 0) : entry_packet.is_ZEROREG;

    // register values for next rs1 and rs2 tags
    // assign next_entry_rs1_tag = wr_en ? (mt2rs_packet_in.rs1_ready ? 0 :
    //                                                                  mt2rs_packet_in.rs1_idx) :                     // 0 if ready in MT
    //                                     ((busy && (cdb_packet_in.reg_tag == entry_rs1_tag)) ? 0 :
    //                                                                                           entry_rs1_tag);       // 0 if broadcasted by cdb
    //                                                                                                                 // entry_rs1_tag by default

    always_comb begin
        if (wr_en) begin
            if (mt2rs_packet_in.rs1_ready) begin
                next_entry_rs1_tag.tag = 0;
                next_entry_rs1_tag.valid = 0;
            end
            // Map table not ready until next cycle when cdb broadcasts
            else if ((cdb_packet_in.reg_tag.tag == mt2rs_packet_in.rs1_tag.tag) && (cdb_packet_in.reg_tag.valid != 0)) begin
                next_entry_rs1_tag.tag = 0;
                next_entry_rs1_tag.valid = 0;
            end
            else begin
                next_entry_rs1_tag.tag = mt2rs_packet_in.rs1_tag.tag;
                next_entry_rs1_tag.valid = mt2rs_packet_in.rs1_tag.valid;
            end
        end
        else begin
            if (busy && (cdb_packet_in.reg_tag.tag == entry_rs1_tag.tag) && (cdb_packet_in.reg_tag.valid != 0)) begin
                next_entry_rs1_tag.tag = 0;
                next_entry_rs1_tag.valid = 0;
            end
            else
                next_entry_rs1_tag = entry_rs1_tag;
        end
    end

    // assign next_entry_rs2_tag = wr_en ? (mt2rs_packet_in.rs2_ready ? 0 :
    //                                                                  mt2rs_packet_in.rs2_idx) :                     // 0 if ready in MT
    //                                     ((busy && (cdb_packet_in.reg_tag == entry_rs2_tag)) ? 0 :
    //                                                                                           entry_rs2_tag);       // 0 if broadcasted by cdb
    //                                                                                                                 // entry_rs2_tag by default

    always_comb begin
        if (wr_en) begin
            if (mt2rs_packet_in.rs2_ready) begin
                next_entry_rs2_tag.tag = 0;
                next_entry_rs2_tag.valid = 0;
            end
            // Map table not ready until next cycle when cdb broadcasts
            else if ((cdb_packet_in.reg_tag.tag == mt2rs_packet_in.rs2_tag.tag) && (cdb_packet_in.reg_tag.valid != 0)) begin
                next_entry_rs2_tag.tag = 0;
                next_entry_rs2_tag.valid = 0;
            end
            else begin
                next_entry_rs2_tag.tag = mt2rs_packet_in.rs2_tag.tag;
                next_entry_rs2_tag.valid = mt2rs_packet_in.rs2_tag.valid;
            end
        end
        else begin
            if (busy && (cdb_packet_in.reg_tag.tag == entry_rs2_tag.tag) && (cdb_packet_in.reg_tag.valid != 0)) begin
                next_entry_rs2_tag.tag = 0;
                next_entry_rs2_tag.valid = 0;
            end
            else
                next_entry_rs2_tag = entry_rs2_tag;
        end
    end

    // register values for next rs1 and rs2 values
    // assign next_entry_packet.rs1_value = wr_en ? ((next_entry_rs1_tag == 0 && mt2rs_packet_in.entry_rs1_tag != 0) ? rob2rs_packet_in.rs1_value : id_packet_in.rs1_value) :
    //                                         (busy && cdb_packet_in.reg_tag == entry_rs1_tag ? cdb_packet_in.reg_value : entry_packet.rs1_value);

    always_comb begin
        next_entry_packet.rs1_value = 0; // Arbitrary value for not ready rs1
    
        if (wr_en) begin
            if (mt2rs_packet_in.rs1_ready && mt2rs_packet_in.rs1_tag.valid != 0)
                next_entry_packet.rs1_value = rob2rs_packet_in.rs1_value;
            else if (!mt2rs_packet_in.rs1_ready && (cdb_packet_in.reg_tag.tag == mt2rs_packet_in.rs1_tag.tag) && (cdb_packet_in.reg_tag.valid != 0))
                next_entry_packet.rs1_value = cdb_packet_in.reg_value;
            else
                next_entry_packet.rs1_value = id_packet_in.rs1_value;  
        end
        else begin
            if (busy && (cdb_packet_in.reg_tag.tag == entry_rs1_tag.tag) && (cdb_packet_in.reg_tag.valid != 0))
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
            if (mt2rs_packet_in.rs2_ready && mt2rs_packet_in.rs2_tag.valid != 0)
                next_entry_packet.rs2_value = rob2rs_packet_in.rs2_value;
            else if (!mt2rs_packet_in.rs2_ready && (cdb_packet_in.reg_tag.tag == mt2rs_packet_in.rs2_tag.tag) && (cdb_packet_in.reg_tag.valid != 0))
                next_entry_packet.rs2_value = cdb_packet_in.reg_value;
            else
                next_entry_packet.rs2_value = id_packet_in.rs2_value;  
        end
        else begin
            if (busy && (cdb_packet_in.reg_tag.tag == entry_rs2_tag.tag) && (cdb_packet_in.reg_tag.valid != 0))
                next_entry_packet.rs2_value = cdb_packet_in.reg_value;
            else
                next_entry_packet.rs2_value = entry_packet.rs2_value;
        end
    end

    // ready
    always_comb begin
        ready = 0;
        flag = TAGTAG;

        if (busy) begin
            if ((entry_rs1_tag.tag == 0) && (entry_rs1_tag.valid == 0) && (entry_rs2_tag.tag == 0) && (entry_rs2_tag.valid == 0)) begin
                ready = 1;
                flag = TAGTAG;
            end
            else if ((entry_rs1_tag.tag == 0) && (entry_rs1_tag.valid == 0) && (cdb_packet_in.reg_tag.tag == entry_rs2_tag.tag) && (cdb_packet_in.reg_tag.valid != 0)) begin
                ready = 1;
                flag = TAGCDB;
            end    
            else if ((entry_rs2_tag.tag == 0) && (entry_rs2_tag.valid == 0) && (cdb_packet_in.reg_tag.tag == entry_rs1_tag.tag) && (cdb_packet_in.reg_tag.valid != 0)) begin
                ready = 1;
                flag = CDBTAG;
            end
            else if ((cdb_packet_in.reg_tag.tag == entry_rs1_tag.tag) && (cdb_packet_in.reg_tag.valid != 0) && (cdb_packet_in.reg_tag.tag == entry_rs2_tag.tag)) begin
                ready = 1;
                flag = CDBCDB;
            end
        end
    end
    // assign ready = (busy && (entry_rs1_tag == 0) && (entry_rs2_tag == 0)) ? 1 : 0; // ready will be set one cc after the instruction is loaded into the RS_entry

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
        if (reset || squash) begin
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
				1'b0, // valid
                1'b1, // is_ZEROREG
                ALU   // channel
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
