module ROB(
    input clock,
    input reset,
    input RS2ROB_PACKET rs2rob_packet_in,
    input EX_PACKET ex_packet_in,
    input CDB_PACKET cdb_packet_in,
    input ID_PACKET  id_packet_in,



    output ROB2RS_PACKET rob2rs_packet_out,    // transfer rs1 & rs2 & Tag 
    output ROB2MT_PACKET rob2mt_packet_out,    // update tag in MT 
    output ROB2REG_PACKET rob2reg_packet_out   // retire 
);

logic [`ROB_LEN-1:0] rob_entry_wr_en;
logic [`ROB_LEN-1:0] rob_entry_wr_value;
logic [`ROB_LEN-1:0] rob_entry_clear;



ROB_entry rob_entry [ROB_LEN-1:0] (
     .clock(clock),
     .reset(reset),
     .wr_en(rob_entry_wr_en),
     .wr_value(rob_entry_wr_value),
     .clear(rob_entry_clear),
     .dest_reg_cdb(),
     .id_packet_dest_reg_idx(id_packet_in.dest_reg_idx)
);

logic [$clog2(`ROB_LEN):0] head_idx;  // store ROB head (ROB_LEN instead of ROB_LEN-1 because ROB starts at 1 )
logic [$clog2(`ROB_LEN):0] tail_idx;  // store ROB tail
logic                      full;      // structural hazard in ROB


// dispatch logic 
assign full =  

always_comb begin
    if (rs2rob_packet_in.valid) begin
        tail_idx = tail_idx + 1'b1;
        rob_entry[tail_idx].wr_en = 1'b1;
        rob_entry[tail_idx].next_dest_reg_idx = 
    end

end


// complete logic


// retire logic

endmodule

module ROB_entry(
    input                        clock,
    input                        reset,
    input                        wr_en,
    input                        wr_value,      // high when dest_reg_value is ready from CDB
    input                        clear,         // during clear, only busy is set to zero
    input [`XLEN-1:0]            dest_reg_cdb,
    input ID_PACKET              id_packet_dest_reg_idx,  

    output ROB_entry_PACKET rob_entry_packet_out
);

// define entry entity
//logic is_head;
//logic is_tail;
logic busy;              // this entry is valid
logic valid;             // dest_reg_value is valid
logic [$clog2(`REG_LEN)-1:0] dest_reg_idx;
logic [`XLEN-1:0] dest_reg_value;

// assignment
assign next_dest_reg_idx   = wr_en ? id_packet_dest_reg_idx : dest_reg_idx;
assign next_busy           = wr_en ? 1'b1 : (clear ? 1'b0 : busy);
assign next_dest_reg_value = wr_en ? 0 : (wr_value ? dest_reg_cdb : dest_reg_value);
assign next_valid          = wr_en ? 0 : (wr_value : 1'b1 : valid);

//sequential logic
// synopsys sync_set_reset "reset"
always_ff @(posedge clock) begin
        if (reset) begin
            busy <= `SD 1'b0;
            valid <= `SD 1'b0;
            //is_head <= `SD 1'b0;
            //is_tail <= `SD 1'b0;
            dest_reg_idx <= `SD 0;
            dest_reg_value <= `SD 0;

        end
        else begin
            busy <= `SD wr_en;
            valid <= `SD next_valid;
            //is_head <= `SD next_is_head;
            //is_tail <= `SD next_is_tail;
            dest_reg_idx <= `SD next_dest_reg_idx;
            dest_reg_value <= `SD next_dest_reg_value;
        end
    end

endmodule