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

logic            [`ROB_LEN-1:0] rob_entry_wr_en;
logic            [`ROB_LEN-1:0] rob_entry_wr_value;
logic            [`ROB_LEN-1:0] rob_entry_clear;
ROB_entry_PACKET [`ROB_LEN-1:0] rob_entry_packet_out;


ROB_entry rob_entry [ROB_LEN-1:0] (
     .clock(clock),
     .reset(reset),
     .wr_en(rob_entry_wr_en),
     .wr_value(rob_entry_wr_value),
     .clear(rob_entry_clear),
     .dest_reg_cdb(cdb_packet_in.reg_value),
     .dest_reg_idx_in(id_packet_in.dest_reg_idx),
     .rob_entry_packet_out(rob_entry_packet_out)
);

logic [$clog2(`ROB_LEN)-1:0] head_idx;            // store ROB head idx
logic [$clog2(`ROB_LEN)-1:0] tail_idx;            // store ROB tail idx
logic                        rob_struc_hazard;    // structural hazard in ROB
logic [$clog2(`ROB_LEN)-1:0] next_head;
logic [$clog2(`ROB_LEN)-1:0] next_tail;

// ROB structural hazard
assign rob_struc_hazard = (head_idx == tail_idx);

// dispatch logic 
// !!! check if under struc hazard, wr_en is all 0
always_comb begin
    rob_entry_wr_en = 0;
    if (id_packet_in.valid && (!rob_struc_hazard)) begin
        rob_entry_wr_en[tail_idx] = 1'b1;
    end
end

assign next_tail = (id_packet_in.valid && (!rob_struc_hazard)) ? tail_idx + 1'b1 : tail_idx;
assign next_head = retire ? head_idx +1'b1 : head_idx;

always_ff @(posedge clock) begin
	if (reset) begin
		tail_idx <= `SD 0;
		head_idx <= `SD 0;
	end	 
    else begin
        tail_idx <= `SD next_tail;
		head_idx <= `SD next_head;
    end
end

// complete logic
// dest_reg_value value comes from CDB
always_comb begin
    rob_entry_wr_value = 0;
	if (cdb_packet_in.reg_tag.valid)
    rob_entry_wr_value [cdb_packet_in.reg_tag.tag] = 1'b1; 
end

// retire logic
// head_idx move away + busy bit set to 0
assign retire = rob_entry_packet_out[head_idx].valid;

always_comb begin
    rob_entry_clear = 0;
    if (retire) begin
        rob_entry_clear[head_idx] = 1'b1;
        rob2reg_packet_out.dest_reg_value = rob_entry_packet_out[head_idx].dest_reg_value;
        rob2reg_packet_out.dest_reg_idx   = rob_entry_packet_out[head_idx].dest_reg_idx;
    end
end

endmodule

module ROB_entry(
    input                        clock,
    input                        reset,
    input                        wr_en,
    input                        wr_value,      // high when dest_reg_value_in is ready from CDB
    input                        clear,         // during clear, only busy is set to zero
    input [`XLEN-1:0]            dest_reg_cdb,
    input [$clog2(`REG_LEN)-1:0] dest_reg_idx_in,  

    output ROB_entry_PACKET      rob_entry_packet_out
);

// define entry entity
//logic is_head;
//logic is_tail;
logic busy;              // this entry is valid
logic valid;             // dest_reg_value is valid
logic [$clog2(`REG_LEN)-1:0] dest_reg_idx;
logic [`XLEN-1:0] dest_reg_value;

// assignment
assign next_dest_reg_idx   = wr_en ? dest_reg_idx_in : dest_reg_idx;
assign next_busy           = wr_en ? 1'b1 : (clear ? 1'b0 : busy);
assign next_dest_reg_value = wr_en ? 0 : (wr_value ? dest_reg_cdb : dest_reg_value);
assign next_valid          = wr_en ? 0 : (wr_value : 1'b1 : valid);

//sequential logic
// synopsys sync_set_reset "reset"
always_ff @(posedge clock) begin
        if (reset) begin
            busy <= `SD 1'b0;
            valid <= `SD 1'b0;
            dest_reg_idx <= `SD 0;
            dest_reg_value <= `SD 0;

        end
        else begin
            busy <= `SD wr_en;
            valid <= `SD next_valid;
            dest_reg_idx <= `SD next_dest_reg_idx;
            dest_reg_value <= `SD next_dest_reg_value;
        end
    end

endmodule
