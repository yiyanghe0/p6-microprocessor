`define DEBUG

module ROB(
    input clock,
    input reset,
	input stall,	
    input RS2ROB_PACKET rs2rob_packet_in,
    //input EX_PACKET ex_packet_in,
    input CDB_PACKET cdb_packet_in,
    input ID_PACKET  id_packet_in,

	`ifdef DEBUG
	output logic [$clog2(`ROB_LEN)-1:0] head_idx,            // store ROB head idx
	output logic [$clog2(`ROB_LEN)-1:0] tail_idx,            // store ROB tail idx
	output logic [`ROB_LEN-1:0]         rob_entry_wr_en,
	output logic [`ROB_LEN-1:0]         rob_entry_wr_value,
	output ROB_entry_PACKET [`ROB_LEN-1:0]         rob_entry_packet_out,
	`endif

	output logic           rob_struc_hazard,    // structural hazard in ROB
    output ROB2RS_PACKET  rob2rs_packet_out,    // transfer rs1 & rs2 & Tag 
    output ROB2MT_PACKET  rob2mt_packet_out,    // update tag in MT 
    output ROB2REG_PACKET rob2reg_packet_out   // retire 
);

`ifndef DEBUG
logic            [$clog2(`ROB_LEN)-1:0] head_idx;            // store ROB head idx
logic            [$clog2(`ROB_LEN)-1:0] tail_idx;            // store ROB tail idx
logic            [`ROB_LEN-1:0]         rob_entry_wr_en;
logic            [`ROB_LEN-1:0]         rob_entry_wr_value;
ROB_entry_PACKET [`ROB_LEN-1:0]         rob_entry_packet_out;
`endif

logic            [$clog2(`ROB_LEN)-1:0] next_head;
logic            [$clog2(`ROB_LEN)-1:0] next_tail;
logic            [$clog2(`REG_LEN)-1:0] dest_reg_idx_in;

// Mispredict
logic            [`ROB_LEN-1:0]         rob_entry_mispredict;
logic            [`ROB_LEN-1:0]         next_rob_entry_mispredict;
logic                                   squash;
logic									retire;
logic									is_init;

// ROB2RS
logic [$clog2(`ROB_LEN)-1:0] index_rs1;
logic [$clog2(`ROB_LEN)-1:0] index_rs2;

// ROB structural hazard
assign rob_struc_hazard = (head_idx == tail_idx) && (~is_init);

assign next_tail = squash ? 0 : ((id_packet_in.valid && (!rob_struc_hazard) && (!stall)) ? tail_idx + 1'b1 : tail_idx);
assign next_head = squash ? 0 : (retire && (!stall)) ? head_idx +1'b1 : head_idx;

assign dest_reg_idx_in = id_packet_in.dest_reg_idx;
assign rob2reg_packet_out.valid = (retire && (dest_reg_idx_in != `ZERO_REG)) ? 1 : 0;

// ROB2RS delivery packet
assign rob2rs_packet_out.rob_entry = tail_idx - 1'b1;
assign rob2rs_packet_out.rob_head_idx = head_idx;

assign index_rs1 = rs2rob_packet_in.rs1_idx;
assign index_rs2 = rs2rob_packet_in.rs2_idx;
assign rob2rs_packet_out.rs1_value = rob_entry[index_rs1].rob_entry_packet_out.dest_reg_value;
assign rob2rs_packet_out.rs2_value = rob_entry[index_rs2].rob_entry_packet_out.dest_reg_value;

// ROB2MT delivery packet
assign rob2mt_packet_out.head_idx = head_idx;
assign rob2mt_packet_out.retire = retire;

ROB_entry rob_entry [`ROB_LEN-1:0] (
     .clock(clock),
     .reset(reset),
     .wr_en(rob_entry_wr_en),
     .wr_value(rob_entry_wr_value),
     .dest_reg_cdb(cdb_packet_in.reg_value),
     .dest_reg_idx_in(dest_reg_idx_in),
     .rob_entry_packet_out(rob_entry_packet_out)
);

// dispatch logic 
always_comb begin
    rob_entry_wr_en = 0;
    if (id_packet_in.valid && (!rob_struc_hazard)) begin
        for (int i=0; i < `ROB_LEN; i++) begin
            if (i == tail_idx) 
                rob_entry_wr_en[i] = 1'b1;
        end
    end
end

// complete logic
// dest_reg_value value comes from CDB
always_comb begin
    rob_entry_wr_value = 0;
	if (cdb_packet_in.reg_tag.valid) begin
        for (int i = 0; i < `ROB_LEN; i++) begin
            if (i == cdb_packet_in.reg_tag.tag)
                rob_entry_wr_value [cdb_packet_in.reg_tag.tag] = 1'b1; 
        end
    end
end

// precise state logic
always_comb begin
    next_rob_entry_mispredict = rob_entry_mispredict;
    for (int i=0; i < `ROB_LEN; i++) begin
        if (i == cdb_packet_in.reg_tag.tag && cdb_packet_in.reg_tag.valid && cdb_packet_in.take_branch) // !!!Assume predict not taken
            next_rob_entry_mispredict[i+1] = 1;
    end
    if (squash) next_rob_entry_mispredict = 0;
end

always_comb begin
    rob2mt_packet_out.squash = 0;
    rob2rs_packet_out.squash = 0;
    squash               	 = 0;
    for (int i=0; i < `ROB_LEN; i++) begin
        if (head_idx == i && rob_entry_mispredict[i] == 1) begin
            rob2mt_packet_out.squash = 1;
            rob2rs_packet_out.squash = 1;
            squash               	 = 1;
        end
    end
end

// retire logic
always_comb begin
    retire = 0;
    rob2reg_packet_out.dest_reg_value = 0;
    rob2reg_packet_out.dest_reg_idx = 0;
    for (int i=0; i < `ROB_LEN; i++) begin
        if (i == head_idx && rob_entry_packet_out[i].valid)
            retire = 1;
            rob2reg_packet_out.dest_reg_value = rob_entry_packet_out[i].dest_reg_value;
            rob2reg_packet_out.dest_reg_idx   = rob_entry_packet_out[i].dest_reg_idx;
    end
end

//flip flop
// synopsys sync_set_reset "reset"
always_ff @(posedge clock) begin
	if (reset) begin
		tail_idx <= `SD 0;
		head_idx <= `SD 0;
        rob_entry_mispredict <= `SD 0;
        is_init <= `SD 1;
	end	 
    else begin
        tail_idx <= `SD next_tail;
		head_idx <= `SD next_head;
        rob_entry_mispredict <= `SD next_rob_entry_mispredict;
        is_init <= `SD 0;
    end
end

endmodule

module ROB_entry(
    input                        clock,
    input						 stall,
    input                        reset,
    input                        wr_en,
    input                        wr_value,      // high when dest_reg_value_in is ready from CDB
    input [`XLEN-1:0]            dest_reg_cdb,
    input [$clog2(`REG_LEN)-1:0] dest_reg_idx_in,  

    output ROB_entry_PACKET      rob_entry_packet_out
);

// define entry entity
logic valid;             // dest_reg_value is valid
logic [$clog2(`REG_LEN)-1:0] dest_reg_idx;
logic [`XLEN-1:0] dest_reg_value;

logic [$clog2(`REG_LEN)-1:0] next_dest_reg_idx;
logic [`XLEN-1:0] next_dest_reg_value;
// assignment
assign next_dest_reg_idx   = (wr_en && !stall) ? dest_reg_idx_in : dest_reg_idx;
assign next_dest_reg_value = (wr_en && !stall) ? 0 : (wr_value && !stall) ? dest_reg_cdb : dest_reg_value;
assign next_valid          = (wr_en && !stall) ? 0 : (wr_en && !stall) ? 1'b1 : valid;

assign rob_entry_packet_out.dest_reg_value = dest_reg_value;
assign rob_entry_packet_out.dest_reg_idx   = dest_reg_idx;
assign rob_entry_packet_out.valid 		   = next_valid;
//sequential logic
// synopsys sync_set_reset "reset"
always_ff @(posedge clock) begin
        if (reset) begin
            valid <= `SD 1'b0;
            dest_reg_idx <= `SD 0;
            dest_reg_value <= `SD 0;

        end
        else begin
            valid <= `SD next_valid;
            dest_reg_idx <= `SD next_dest_reg_idx;
            dest_reg_value <= `SD next_dest_reg_value;
        end
    end

endmodule
