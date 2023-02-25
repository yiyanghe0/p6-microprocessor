module RS(
    input ID_IS_PACKET id_packet_in,
    input MT_RS_PACKET mt_packet_in,
    // and CDB
    input [$clog2(`ROB_SIZE)-1:0] rob_entry_in,

    output RS_MT_PACKET rs_mt_packet_out,
    output IS_EX_PACKET is_packet_out
);
    RS_SLOT [`RS_SIZE:0] rs_content;

    // Need to consider structural hazard in the future!!!
    logic [$clog2(`RS_SIZE)-1:0] rs_in_index;
    always_comb begin
        rs_in_index = 0;
        for (int i = 0; i < `RS_SIZE; i++) begin
            if (!rs_content[i].busy) begin
                rs_in_index = i;
                break;
            end
        end
    end    

    assign rs_content[rs_in_index].id_is_packet = id_packet_in;
    assign rs_content[rs_in_index].busy = 1'b1;
    assign rs_content[rs_in_index].dest_tag = (condition) ? rob_entry_in : 0;
    assign rs_content[rs_in_index].rs1_tag = mt_packet_in.rs1_tag;
    assign rs_content[rs_in_index].rs2_tag = mt_packet_in.rs2_tag;
    // Need to consider CDB!!!
    assign rs_content[rs_in_index].rs1_value = id_packet_in.rs1_value;
    assign rs_content[rs_in_index].rs2_value = id_packet_in.rs2_value;

    // Need to use rotational priority selector

    // Need to find ways to get rs_out_index!!!
    logic [$clog2(`RS_SIZE)-1:0] rs_out_index;
    assign is_packet_out.NPC = rs_content[rs_out_index].id_is_packet.NPC;
    assign is_packet_out.PC = rs_content[rs_out_index].id_is_packet.PC;
    assign is_packet_out.rs1_value = rs_content[rs_out_index].id_is_packet.rs1_value;
    assign is_packet_out.rs2_value = rs_content[rs_out_index].id_is_packet.rs2_value;
    assign is_packet_out.opa_select = rs_content[rs_out_index].id_is_packet.opa_select;
    assign is_packet_out.opb_select = rs_content[rs_out_index].id_is_packet.opb_select;
    //...

endmodule