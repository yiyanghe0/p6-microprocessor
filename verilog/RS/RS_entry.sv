module RS_entry(
    input ID_IS_PACKET id_packet_in,
    input MT_RS_PACKET mt_packet_in,
    // and CDB
    input ROB_RS_PACKET rob_packet_in,
    input enable,
    output RS_MT_PACKET rs_mt_packet_out,
    output IS_EX_PACKET is_packet_out,
    output RS_ROB_PACKET rs_rob_packet_out,
    output issue_ready
);
    RS_SLOT  rs_content;
    RS_SLOT  N_rs_content;


    assign N_rs_content.id_is_packet = id_packet_in;
    assign N_rs_content.busy = enable; 

    //tags
    assign N_rs_content.dest_tag = (id_packet_in.wr_mem) ? 0 : rob_packet_in.rob_entry_in;  // only instruction without dest reg is store ?
    //tag from packet should not be ready in ROB
    assign N_rs_content.rs1_tag = (mt_packet_in.rs1_tag_ready) ? 0 : mt_packet_in.rs1_tag;
    assign N_rs_content.rs2_tag = (mt_packet_in.rs2_tag_ready) ? 0 : mt_packet_in.rs2_tag;


    // Need to consider CDB!!!
    assign N_rs_content.rs1_value = (mt_packet_in.rs1_tag_ready) ? rob_packet_in.rob_entry_value_rs1 : ((mt_packet_in.rs1_tag) ? 0 : id_packet_in.rs1_value);
    assign N_rs_content.rs2_value = (mt_packet_in.rs2_tag_ready) ? rob_packet_in.rob_entry_value_rs2 : ((mt_packet_in.rs2_tag) ? 0 : id_packet_in.rs2_value);


    // judge if can issue
    // !!! need to consider the existence of rs12(load/store)
    assign issue_ready = (rs_content.busy && !rs_content.rs1_tag && !rs_content.rs2_tag);

    //interact map table
    assign rs_mt_packet_out.rs1_index = id_packet_in.inst.r.rs1;
    assign rs_mt_packet_out.rs2_index = id_packet_in.inst.r.rs2;
    assign rs_mt_packet_out.dest_index = id_packet_in.dest_reg_idx;
    assign rs_mt_packet_out.dest_tag = N_rs_content.dest_tag;


    //interact CDB (no need)


    //interact ROB
    assign rs_rob_packet_out.rs1_tag = N_rs_content.rs1_tag;
    assign rs_rob_packet_out.rs2_tag = N_rs_content.rs2_tag;



    // Need to use rotational priority selector
    

    // synopsys sync_set_reset "reset"
    always_ff @(posedge clock) begin
        if (enable) begin
            rs_content <= #1 N_rs_content;
        end
        else begin
            rs_content <= rs_content;
        end
    end



    // Need to find ways to get rs_out_index!!!
    logic [$clog2(`RS_SIZE)-1:0] rs_out_index;
    assign is_packet_out.NPC = rs_content.id_is_packet.NPC;
    assign is_packet_out.PC = rs_content.id_is_packet.PC;
    assign is_packet_out.rs1_value = rs_content.id_is_packet.rs1_value;
    assign is_packet_out.rs2_value = rs_content.id_is_packet.rs2_value;
    assign is_packet_out.opa_select = rs_content[rs_out_index].id_is_packet.opa_select;
    assign is_packet_out.opb_select = rs_content[rs_out_index].id_is_packet.opb_select;
    //...

endmodule