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
    output logic [`ROB_LEN-1:0]         rob_entry_retire_sig,
	output logic [`ROB_LEN-1:0]         rob_entry_cp_sig,
	output ROB_entry_PACKET [`ROB_LEN-1:0]         rob_entry_packet_out,
	`endif

	output logic          rob2store_start,
    output logic          rob_struc_hazard_out, // structural hazard in ROB, output into DP_IS, same as next_hazard
    output logic          next_rob_struc_hazard_out,
    output ROB2RS_PACKET  rob2rs_packet_out,    // transfer rs1 & rs2 & Tag 
    output ROB2MT_PACKET  rob2mt_packet_out,    // update tag in MT 
    output ROB2REG_PACKET rob2reg_packet_out   // retire 
);

`ifndef DEBUG
logic            [$clog2(`ROB_LEN)-1:0] head_idx;            // store ROB head idx
logic            [$clog2(`ROB_LEN)-1:0] tail_idx;            // store ROB tail idx
logic            [`ROB_LEN-1:0]         rob_entry_wr_en;
logic            [`ROB_LEN-1:0]         rob_entry_retire_sig;
logic            [`ROB_LEN-1:0]         rob_entry_cp_sig;
ROB_entry_PACKET [`ROB_LEN-1:0]         rob_entry_packet_out;
`endif

logic            [$clog2(`ROB_LEN)-1:0] next_head;
logic            [$clog2(`ROB_LEN)-1:0] next_tail;
logic                                   rob_struc_hazard;
logic                                   next_rob_struc_hazard;
logic            [`REG_LEN-1:0] dest_reg_idx_in;

// Mispredict
logic            [`ROB_LEN-1:0]         rob_entry_mispredict;
logic            [`ROB_LEN-1:0]         next_rob_entry_mispredict;
logic                                   squash;
logic									retire;
logic			 [3:0]					is_init;
logic			 [3:0]					next_is_init;



// ROB2RS
logic [$clog2(`ROB_LEN)-1:0] index_rs1;
logic [$clog2(`ROB_LEN)-1:0] index_rs2;

// rt halt
logic rt_halt;
logic next_rt_halt;


// To store unit 
assign rob2store_start = rob_entry_packet_out[head_idx].is_store;

// ROB structural hazard
assign next_is_init = squash ? 1 : (is_init < 14) ? is_init + 1 : is_init;
assign next_rob_struc_hazard = (next_head == next_tail) && (next_tail == tail_idx + 1 || id_packet_in.valid);
assign rob_struc_hazard_out = rob_struc_hazard;
assign next_rob_struc_hazard_out = next_rob_struc_hazard;
// assign rob_struc_hazard = 1'b0;

assign next_tail = squash ? head_idx : ((id_packet_in.valid && (!rob_struc_hazard) && (!stall)) ? tail_idx + 1'b1 : tail_idx);
assign next_head = (retire && (!squash)) ? head_idx +1'b1 : head_idx;

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
     .retire(rob_entry_retire_sig),
     .wr_en(rob_entry_wr_en),
     .cp_sig(rob_entry_cp_sig),
     .dest_reg_cdb(cdb_packet_in.reg_value),
     .cdb_valid_bit(cdb_packet_in.reg_tag.valid),
     .wr_mem_in(id_packet_in.wr_mem),
     .dest_reg_idx_in(dest_reg_idx_in),
     .halt_in(id_packet_in.halt),
     .illegal_in(id_packet_in.illegal),
     .PC_in(id_packet_in.PC),
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
        if (i == cdb_packet_in.reg_tag.tag && (!cdb_packet_in.correct_predict)) // !!!Assume predict not taken
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
    rob_entry_retire_sig = 0;

    if (rob_entry_packet_out[head_idx].valid) begin
        retire = 1;
        rob_entry_retire_sig[head_idx] = 1'b1;
    end
end



always_comb begin
    rob2reg_packet_out.dest_reg_value = 0;
    rob2reg_packet_out.dest_reg_idx = 0;
    rob2reg_packet_out.illegal = 0;
    rob2reg_packet_out.PC = 0;
    rob2reg_packet_out.inst_valid = 0;
    rob2reg_packet_out.wb_en = 0;

    if(retire) begin
            rob2reg_packet_out.dest_reg_value = rob_entry_packet_out[head_idx].dest_reg_value;
            rob2reg_packet_out.dest_reg_idx = rob_entry_packet_out[head_idx].dest_reg_idx;
            rob2reg_packet_out.illegal = rob_entry_packet_out[head_idx].is_illegal;
            rob2reg_packet_out.PC = rob_entry_packet_out[head_idx].PC;
            rob2reg_packet_out.inst_valid = rob_entry_packet_out[head_idx].inst_valid;
            rob2reg_packet_out.wb_en = rob_entry_packet_out[head_idx].wb_en;

        end
end

always_comb begin
    if (rob_entry_packet_out[head_idx].is_halt && retire)
        rob2reg_packet_out.halt = 1;
    else
        rob2reg_packet_out.halt = rt_halt;
end

always_comb begin
    if (rob_entry_packet_out[head_idx].is_halt && retire)
        next_rt_halt = 1;
    else
        next_rt_halt = rt_halt;
end

//flip flop
// synopsys sync_set_reset "reset"
always_ff @(posedge clock) begin
	if (reset) begin
		tail_idx <= `SD 0;
		head_idx <= `SD 0;
        rob_entry_mispredict <= `SD 0;
        is_init <= `SD 1;
        rob_struc_hazard <= `SD 0;
        rt_halt <= `SD 0;
	end	 
    else begin
        tail_idx <= `SD next_tail;
		head_idx <= `SD next_head;
        rob_entry_mispredict <= `SD next_rob_entry_mispredict;
        is_init <= `SD next_is_init;
        rob_struc_hazard <= `SD next_rob_struc_hazard;
        rt_halt <= `SD next_rt_halt;
    end
end

endmodule

module ROB_entry(
    input                        clock,
    input						 stall,
    input                        squash,
    input                        reset,
    input                        retire,       // this entry is retired, need to de-assert valid(complete)
    input                        wr_en,
    input                        cp_sig,      // high when dest_reg_value_in is ready from CDB
    input [`XLEN-1:0]            dest_reg_cdb,
    input                        cdb_valid_bit,
    input [`REG_LEN-1:0]         dest_reg_idx_in,  
    input                        wr_mem_in,
    input                        halt_in,
    input                        illegal_in, 
    input [`XLEN-1:0]            PC_in,
    input                        id_inst_valid,

    output ROB_entry_PACKET      rob_entry_packet_out
);

// define entry entity
logic valid;             // finished complete stage, dest_reg_value is valid
logic wb_en;
logic [`REG_LEN-1:0] dest_reg_idx;
logic [`XLEN-1:0] dest_reg_value;
logic             is_halt;
logic             is_illegal;
logic             is_store;
logic [`XLEN-1:0] PC_value;
logic             inst_valid;


logic [`REG_LEN-1:0] next_dest_reg_idx;
logic [`XLEN-1:0]    next_dest_reg_value;
logic                next_valid;
logic                next_wb_en;
logic                next_is_halt;
logic                next_is_illegal;
logic                next_is_store;
logic [`XLEN-1:0]    next_PC;
logic                next_inst_valid;


// assignment
assign next_dest_reg_idx   = (wr_en && !stall) ? dest_reg_idx_in : dest_reg_idx;
assign next_is_store       = (wr_en && !stall) ? wr_mem_in : is_store;
assign next_dest_reg_value = (wr_en && !stall) ? 0 : (cp_sig && cdb_valid_bit) ? dest_reg_cdb : dest_reg_value;
assign next_valid          = (retire) ? 0 : cp_sig ? 1'b1 : valid;
assign next_wb_en          = (retire) ? 0 : cp_sig ? cdb_valid_bit : wb_en;
assign next_is_halt        = (wr_en && !stall) ? halt_in : is_halt;
assign next_is_illegal     = (wr_en && !stall) ? illegal_in : is_illegal;
assign next_PC             = (wr_en && !stall) ? PC_in : PC_value;

always_comb begin
    if (wr_en && !stall) begin
        if (halt_in)
            next_inst_valid = 0;
        else
            next_inst_valid = id_inst_valid;
    end
    else
        next_inst_valid = inst_valid;
end

assign rob_entry_packet_out.dest_reg_value = dest_reg_value;
assign rob_entry_packet_out.dest_reg_idx   = dest_reg_idx;
assign rob_entry_packet_out.valid 		   = valid;
assign rob_entry_packet_out.wb_en 		   = wb_en;
assign rob_entry_packet_out.is_halt 	   = is_halt;
assign rob_entry_packet_out.is_illegal 	   = is_illegal;
assign rob_entry_packet_out.PC 	           = PC_value;
assign rob_entry_packet_out.inst_valid 	   = inst_valid;
assign rob_entry_packet_out.is_store 	   = is_store;
 

//sequential logic
// synopsys sync_set_reset "reset"
always_ff @(posedge clock) begin
        if (reset || squash) begin
            valid <= `SD 1'b0;
            wb_en <= `SD 1'b0;
            dest_reg_idx <= `SD 0;
            dest_reg_value <= `SD 0;
            is_halt <= `SD 0;
            is_illegal <= `SD 0;
            PC_value   <= `SD 0;
            inst_valid <= `SD 0;
            is_store   <= `SD 0;
        end
        else begin
            valid <= `SD next_valid;
            wb_en <= `SD next_wb_en;
            dest_reg_idx <= `SD next_dest_reg_idx;
            dest_reg_value <= `SD next_dest_reg_value;
            is_halt <= `SD next_is_halt;
            is_illegal <= `SD next_is_illegal;
            PC_value   <= `SD next_PC;
            inst_valid <= `SD next_inst_valid;
            is_store   <= `SD next_is_store;
        end
    end

endmodule
