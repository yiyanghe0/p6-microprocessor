`ifndef MAP_TABLE_SV
`define MAP_TABLE_SV

`include "sys_defs.svh"

module MAP_TABLE(
    input clock,
    input reset,
    input RS2MT_PACKET rs2mt_packet_in,
    input CDB_PACKET cdb_packet_in,
    output MT2RS_PACKET mt2rs_packet_out
);
    TAG_PACKET [`MAP_TABLE_LEN-1:0] map_table_entry_tag;
    logic [`MAP_TABLE_LEN-1:0] map_table_entry_ready;

    // Write into Map Table
    TAG_PACKET next_map_table_entry_tag;
    logic next_map_table_entry_ready;
    logic [`REG_LEN-1:0] next_map_table_entry_cdb_idx;

    assign next_map_table_entry_tag = wr_en ? rs2mt_packet_in.dest_reg_tag : map_table_entry_tag[rs2mt_packet_in.dest_reg_idx];
    
    always_comb begin
        next_map_table_entry_cdb_idx = 0;
        for (int i = 0; i < `MAP_TABLE_LEN; i++) begin
            if ((map_table_entry_tag[i].tag == cdb_packet_in.reg_tag.tag) &&
                map_table_entry_tag[i].valid && cdb_packet_in.valid)
                next_map_table_entry_cdb_idx = i;
        end
    end

    assign next_map_table_entry_ready = cdb_packet_in.reg_tag.valid;

    // Output
    always_comb begin
        mt2rs_packet_out.rs1_tag.valid = 0;
        mt2rs_packet_out.rs1_tag.tag = 0;
        mt2rs_packet_out.rs1_ready = 0;
        for (int i = 0; i < `MAP_TABLE_LEN; i++) begin
            if (rs2mt_packet_in.rs1_idx == i) begin
                mt2rs_packet_out.rs1_tag = map_table_entry_tag[i];
                mt2rs_packet_out.rs1_ready = map_table_entry_ready[i];
                break;
            end
        end
    end

    always_comb begin
        mt2rs_packet_out.rs2_tag.valid = 0;
        mt2rs_packet_out.rs2_tag.tag = 0;
        mt2rs_packet_out.rs2_ready = 0;
        for (int i = 0; i < `MAP_TABLE_LEN; i++) begin
            if (rs2mt_packet_in.rs2_idx == i) begin
                mt2rs_packet_out.rs2_tag = map_table_entry_tag[i];
                mt2rs_packet_out.rs2_ready = map_table_entry_ready[i];
                break;
            end
        end
    end

    // synopsys sync_set_reset "reset"
    always_ff @(posedge clock) begin
        if (reset) begin
            for (int i = 0; i < `MAP_TABLE_LEN; i++) begin
                map_table_entry_tag[i].tag <= `SD 0;
                map_table_entry_tag[i].valid <= `SD 0;
                map_table_entry_ready[i] <= `SD 0;
            end
            
        end
        else begin
            map_table_entry_tag[rs2mt_packet_in.dest_reg_idx] <= `SD next_map_table_entry_tag;
            map_table_entry_ready[next_map_table_entry_cdb_idx] <= `SD next_map_table_entry_ready;
        end
    end

endmodule

`endif