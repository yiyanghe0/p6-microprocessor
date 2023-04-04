// `define DEBUG

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
	output logic [`ROB_LEN-1:0]         rob_entry_cp_sig,
	output ROB_entry_PACKET [`ROB_LEN-1:0]         rob_entry_packet_out,
	`endif

	output logic          rob_struc_hazard_out, // structural hazard in ROB, output into DP_IS, same as next_hazard
    output ROB2RS_PACKET  rob2rs_packet_out,    // transfer rs1 & rs2 & Tag 
    output ROB2MT_PACKET  rob2mt_packet_out,    // update tag in MT 
    output ROB2REG_PACKET rob2reg_packet_out   // retire 
);

`ifndef DEBUG
logic            [$clog2(`ROB_LEN)-1:0] head_idx;            // store ROB head idx
logic            [$clog2(`ROB_LEN)-1:0] tail_idx;            // store ROB tail idx
logic            [`ROB_LEN-1:0]         rob_entry_wr_en;
logic            [`ROB_LEN-1:0]         rob_entry_cp_sig;
ROB_entry_PACKET [`ROB_LEN-1:0]         rob_entry_packet_out;
`endif

logic            [$clog2(`ROB_LEN)-1:0] next_head;
logic            [$clog2(`ROB_LEN)-1:0] next_tail;
logic                                   rob_struc_hazard;
logic            [`REG_LEN-1:0] dest_reg_idx_in;

// Mispredict
logic            [`ROB_LEN-1:0]         rob_entry_mispredict;
logic            [`ROB_LEN-1:0]         next_rob_entry_mispredict;
logic                                   squash;
logic									retire;
logic			 [1:0]					is_init;
logic			 [1:0]					next_is_init;



// ROB2RS
logic [$clog2(`ROB_LEN)-1:0] index_rs1;
logic [$clog2(`ROB_LEN)-1:0] index_rs2;



// ROB structural hazard
assign next_is_init = squash ? 1 : (is_init < 3) ? is_init + 1 : is_init;
assign rob_struc_hazard = (head_idx == tail_idx) && (is_init == 2'b11);
assign rob_struc_hazard_out = rob_struc_hazard;
// assign rob_struc_hazard = 1'b0;

assign next_tail = squash ? head_idx : ((id_packet_in.valid && (!rob_struc_hazard) && (!stall)) ? tail_idx + 1'b1 : tail_idx);
assign next_head = (retire && (!stall) && (!squash)) ? head_idx +1'b1 : head_idx;

assign dest_reg_idx_in = id_packet_in.dest_reg_idx;
assign rob2reg_packet_out.valid = (retire && (rob_entry_packet_out[head_idx].dest_reg_idx != `ZERO_REG)) ? 1 : 0;

// ROB2RS delivery packet
assign rob2rs_packet_out.rob_entry = tail_idx;
assign rob2rs_packet_out.rob_head_idx = head_idx;
assign rob2rs_packet_out.rs1_value = rob_entry_packet_out[rs2rob_packet_in.rs1_idx].dest_reg_value;
assign rob2rs_packet_out.rs2_value = rob_entry_packet_out[rs2rob_packet_in.rs2_idx].dest_reg_value;

// ROB2MT delivery packet
assign rob2mt_packet_out.head_idx = head_idx;
assign rob2mt_packet_out.retire = retire;

ROB_entry rob_entry [`ROB_LEN-1:0] (
     .clock(clock),
     .reset(reset),
     .stall(stall),
     .squash(squash),
     .wr_en(rob_entry_wr_en),
     .cp_sig(rob_entry_cp_sig),
     .dest_reg_cdb(cdb_packet_in.reg_value),
     .cdb_valid_bit(cdb_packet_in.reg_tag.valid),
     .dest_reg_idx_in(dest_reg_idx_in),
     .halt_in(id_packet_in.halt),
     .illegal_in(id_packet_in.illegal),
     .NPC_in(id_packet_in.NPC),
     .id_inst_valid(id_packet_in.valid),

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
    rob_entry_cp_sig = 0;
	if (!cdb_packet_in.no_output) begin
        for (int i = 0; i < `ROB_LEN; i++) begin
            if (i == cdb_packet_in.reg_tag.tag)
                rob_entry_cp_sig [i] = 1'b1; 
        end
    end
end

// precise state logic
always_comb begin
    next_rob_entry_mispredict = rob_entry_mispredict;
    for (int i=0; i < `ROB_LEN; i++) begin
        if (i == cdb_packet_in.reg_tag.tag && cdb_packet_in.take_branch) // !!!Assume predict not taken
            next_rob_entry_mispredict[i] = 1;
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

// retire logic (or we should call it write back logic because head_idx is moving down next cycle)
always_comb begin
    retire = 0;
        if (rob_entry_packet_out[head_idx].valid) begin
            retire = 1;
    end
end

always_comb begin
    rob2reg_packet_out.dest_reg_value = 0;
    rob2reg_packet_out.dest_reg_idx = 0;
    rob2reg_packet_out.halt = 0;
    rob2reg_packet_out.illegal = 0;
    rob2reg_packet_out.NPC = 0;
    rob2reg_packet_out.inst_valid = 0;

    if(retire) begin
            rob2reg_packet_out.dest_reg_value = rob_entry_packet_out[head_idx].dest_reg_value;
            rob2reg_packet_out.dest_reg_idx = rob_entry_packet_out[head_idx].dest_reg_idx;
            rob2reg_packet_out.halt = squash ? 1'b0 : rob_entry_packet_out[head_idx].is_halt;
            rob2reg_packet_out.illegal = rob_entry_packet_out[head_idx].is_illegal;
            rob2reg_packet_out.NPC = rob_entry_packet_out[head_idx].NPC;
            rob2reg_packet_out.inst_valid = rob_entry_packet_out[head_idx].inst_valid;

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
        is_init <= `SD next_is_init;
    end
end

endmodule

module ROB_entry(
    input                        clock,
    input						 stall,
    input                        squash,
    input                        reset,
    input                        wr_en,
    input                        cp_sig,      // high when dest_reg_value_in is ready from CDB
    input [`XLEN-1:0]            dest_reg_cdb,
    input                        cdb_valid_bit,
    input [`REG_LEN-1:0]         dest_reg_idx_in,  
    input                        halt_in,
    input                        illegal_in, 
    input [`XLEN-1:0]            NPC_in,
    input                        id_inst_valid,

    output ROB_entry_PACKET      rob_entry_packet_out
);

// define entry entity
logic valid;             // dest_reg_value is valid
logic [`REG_LEN-1:0] dest_reg_idx;
logic [`XLEN-1:0] dest_reg_value;
logic             is_halt;
logic             is_illegal;
logic [`XLEN-1:0] NPC;
logic             inst_valid;


logic [`REG_LEN-1:0] next_dest_reg_idx;
logic [`XLEN-1:0]    next_dest_reg_value;
logic                next_valid;
logic                next_is_halt;
logic                next_is_illegal;
logic [`XLEN-1:0]    next_NPC;
logic                next_inst_valid;


// assignment
assign next_dest_reg_idx   = (wr_en && !stall) ? dest_reg_idx_in : dest_reg_idx;
assign next_dest_reg_value = (wr_en && !stall) ? 0 : (cp_sig && cdb_valid_bit && !stall) ? dest_reg_cdb : dest_reg_value;
assign next_valid          = (wr_en && !stall) ? 0 : (cp_sig && !stall) ? 1'b1 : valid;
assign next_is_halt        = (wr_en && !stall) ? halt_in : is_halt;
assign next_is_illegal     = (wr_en && !stall) ? illegal_in : is_illegal;
assign next_NPC            = (wr_en && !stall) ? NPC_in : NPC;
assign next_inst_valid     = (wr_en && !halt_in && !stall) ? id_inst_valid : inst_valid;


assign rob_entry_packet_out.dest_reg_value = dest_reg_value;
assign rob_entry_packet_out.dest_reg_idx   = dest_reg_idx;
assign rob_entry_packet_out.valid 		   = valid;
assign rob_entry_packet_out.is_halt 	   = is_halt;
assign rob_entry_packet_out.is_illegal 	   = is_illegal;
assign rob_entry_packet_out.NPC 	       = NPC;
assign rob_entry_packet_out.inst_valid 	   = inst_valid;
 

//sequential logic
// synopsys sync_set_reset "reset"
always_ff @(posedge clock) begin
        if (reset || squash) begin
            valid <= `SD 1'b0;
            dest_reg_idx <= `SD 0;
            dest_reg_value <= `SD 0;
            is_halt <= `SD 0;
            is_illegal <= `SD 0;
            NPC        <= `SD 0;
            inst_valid <= `SD 0;
        end
        else begin
            valid <= `SD next_valid;
            dest_reg_idx <= `SD next_dest_reg_idx;
            dest_reg_value <= `SD next_dest_reg_value;
            is_halt <= `SD next_is_halt;
            is_illegal <= `SD next_is_illegal;
            NPC        <= `SD next_NPC;
            inst_valid <= `SD next_inst_valid;
        end
    end

endmodule
