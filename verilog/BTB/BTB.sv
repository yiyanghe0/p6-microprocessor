`define DEBUG

module BTB(
    input clock,
    input reset,
    input IFID2BTB_PACKET if_packet_in, // valid indicates instruction is valid
    input IFID2BTB_PACKET id_packet_in, // valid indicates currently on branch instruction
    input FU2BTB_PACKET fu_packet_in; // valid indicates branch complete

	`ifdef DEBUG

	`endif

    output BTB_PACKET btb_packet_out;
);

// `ifndef DEBUG

// `endif

    BTB_ENTRY [`BTB_LEN-1:0] btb_entrys;
    BTB_ENTRY [`BTB_LEN-1:0] next_btb_entrys;

// prediction
always_comb begin
    btb_packet_out =0;
    if (if_packet_in.valid) begin
        if (if_packet_in.inst[`XLEN-1:$clog2(`BTB_LEN)] == btb_entrys[if_packet_in.inst[$clog2(`BTB_LEN)-1:0]].tag && btb_entrys[if_packet_in.inst[$clog2(`BTB_LEN)-1:0]].busy) begin
            btb_packet_out.prediction = (btb_entrys[if_packet_in.inst[$clog2(`BTB_LEN)-1:0]].state == TAKEN || btb_entrys[if_packet_in.inst[$clog2(`BTB_LEN)-1:0]].state == WEAK_TAKEN) ? 1 : 0;
            btb_packet_out.valid = 1;
            btb_packet_out.target_pc = btb_entrys[if_packet_in.inst[$clog2(`BTB_LEN)-1:0]].target_pc;
        end
    end
end

// initialization and update of btb entry
always_comb begin
    next_btb_entrys = btb_entrys;
    // initialization
    if (id_packet_in.valid) begin
        if ((btb_entrys[id_packet_in.inst[$clog2(`BTB_LEN)-1:0]].tag != id_packet_in.inst[`XLEN-1:$clog2(`BTB_LEN)] && btb_entrys[id_packet_in.inst[$clog2(`BTB_LEN)-1:0]]).busy || 
            btb_entrys[id_packet_in.inst[$clog2(`BTB_LEN)-1:0]].busy) begin // btb entry not hit or is not in use 
            next_btb_entrys[id_packet_in.inst[$clog2(`BTB_LEN)-1:0]].valid = 1;
            next_btb_entrys[id_packet_in.inst[$clog2(`BTB_LEN)-1:0]].tag = id_packet_in.inst[`XLEN-1:$clog2(`BTB_LEN)];
            next_btb_entrys[id_packet_in.inst[$clog2(`BTB_LEN)-1:0]].target_pc = 0; 
            next_btb_entrys[id_packet_in.inst[$clog2(`BTB_LEN)-1:0]].state = TAKEN;
        end
    end
    // update 
    if (fu_packet_in.valid) begin
        if (btb_entrys[fu_packet_in.inst[$clog2(`BTB_LEN)-1:0]].tag == fu_packet_in.inst[`XLEN-1:$clog2(`BTB_LEN)] && btb_entrys[fu_packet_in.inst[$clog2(`BTB_LEN)-1:0]].valid) begin
            next_btb_entrys[fu_packet_in.inst[$clog2(`BTB_LEN)-1:0]].target_pc = fu_packet_in.target_pc;
            case (btb_entrys[fu_packet_in.inst[$clog2(`BTB_LEN)-1:0]].state)
                TAKEN:          next_btb_entrys[fu_packet_in.inst[$clog2(`BTB_LEN)-1:0]].state = fu_packet_in.taken ? TAKEN         : WEAK_TAKEN;
                WEAK_TAKEN:     next_btb_entrys[fu_packet_in.inst[$clog2(`BTB_LEN)-1:0]].state = fu_packet_in.taken ? TAKEN         : WEAK_NOTTAKE;
                WEAK_NOTTAKE:   next_btb_entrys[fu_packet_in.inst[$clog2(`BTB_LEN)-1:0]].state = fu_packet_in.taken ? WEAK_TAKEN    : NOTTAKE;
                NOTTAKE:        next_btb_entrys[fu_packet_in.inst[$clog2(`BTB_LEN)-1:0]].state = fu_packet_in.taken ? WEAK_NOTTAKE  : NOTTAKE;
            endcase
        end
    end
end

always_ff @(posedge clock) begin
    if (reset) btb_entrys   <= `SD 0;
    else btb_entrys         <= `SD next_btb_entrys;
end

endmodule