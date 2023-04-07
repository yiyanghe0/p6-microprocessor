/////////////////////////////////////////////////////////////////////////
//                                                                     //
//   Modulename :  BTB.sv                                          //
//                                                                     //
//  Description :  ourBTB                                              //
//                                                                     //
//                                                                     //
/////////////////////////////////////////////////////////////////////////

`ifndef __BTB_SV__
`define __BTB_SV__


// `define DEBUG
`include "sys_defs.svh"
module BTB(
    input clock,
    input reset,
    input IFID2BTB_PACKET if_packet_in, // valid indicates PCruction is valid
    input IFID2BTB_PACKET id_packet_in, // valid indicates currently on branch PCruction
    input EX2BTB_PACKET ex_packet_in, // valid indicates branch complete

	`ifdef DEBUG
    output BTB_ENTRY [`BTB_LEN-1:0] bp_entries_display,
    output BTB_ENTRY [`BTB_LEN-1:0] next_bp_entries_display,
	`endif

    output BTB_PACKET btb_packet_out
);

   

    BTB_ENTRY [`BTB_LEN-1:0] btb_entrys;
    BTB_ENTRY [`BTB_LEN-1:0] next_btb_entrys;

    `ifdef DEBUG
        assign bp_entries_display = btb_entrys;
        assign next_bp_entries_display = next_btb_entrys;
   `endif

// prediction
always_comb begin
    btb_packet_out.prediction = 1'b0;
    btb_packet_out.valid = 1'b0;
    btb_packet_out.target_pc = 0;
    if (if_packet_in.valid) begin
        if (if_packet_in.PC[`XLEN-1:$clog2(`BTB_LEN)] == btb_entrys[if_packet_in.PC[$clog2(`BTB_LEN)-1:0]].tag && btb_entrys[if_packet_in.PC[$clog2(`BTB_LEN)-1:0]].busy) begin
            btb_packet_out.prediction = (btb_entrys[if_packet_in.PC[$clog2(`BTB_LEN)-1:0]].state == TAKEN || btb_entrys[if_packet_in.PC[$clog2(`BTB_LEN)-1:0]].state == WEAK_TAKEN) ? 1 : 0;
            btb_packet_out.valid = 1;
            btb_packet_out.target_pc = btb_entrys[if_packet_in.PC[$clog2(`BTB_LEN)-1:0]].target_pc;
        end
    end
end

// initialization and update of btb entry
always_comb begin
    next_btb_entrys = btb_entrys;
    // initialization
    if (id_packet_in.valid) begin
        if (((btb_entrys[id_packet_in.PC[$clog2(`BTB_LEN)-1:0]].tag != id_packet_in.PC[`XLEN-1:$clog2(`BTB_LEN)]) && btb_entrys[id_packet_in.PC[$clog2(`BTB_LEN)-1:0]].busy) || 
            ~btb_entrys[id_packet_in.PC[$clog2(`BTB_LEN)-1:0]].busy) begin // btb entry not hit or is not in use 
            $display(id_packet_in.PC[$clog2(`BTB_LEN)-1:0]);
            next_btb_entrys[id_packet_in.PC[$clog2(`BTB_LEN)-1:0]].busy = 1;
            next_btb_entrys[id_packet_in.PC[$clog2(`BTB_LEN)-1:0]].tag = id_packet_in.PC[`XLEN-1:$clog2(`BTB_LEN)];
            next_btb_entrys[id_packet_in.PC[$clog2(`BTB_LEN)-1:0]].target_pc = 0; 
            next_btb_entrys[id_packet_in.PC[$clog2(`BTB_LEN)-1:0]].state = NOTTAKE;
        end
    end
    // update 
    if (ex_packet_in.valid) begin
        if (btb_entrys[ex_packet_in.PC[$clog2(`BTB_LEN)-1:0]].tag == ex_packet_in.PC[`XLEN-1:$clog2(`BTB_LEN)] && btb_entrys[ex_packet_in.PC[$clog2(`BTB_LEN)-1:0]].busy) begin
            next_btb_entrys[ex_packet_in.PC[$clog2(`BTB_LEN)-1:0]].target_pc = ex_packet_in.target_pc;
            case (btb_entrys[ex_packet_in.PC[$clog2(`BTB_LEN)-1:0]].state)
                TAKEN:          next_btb_entrys[ex_packet_in.PC[$clog2(`BTB_LEN)-1:0]].state = (ex_packet_in.taken ? TAKEN         : WEAK_TAKEN);// double drive?
                WEAK_TAKEN:     next_btb_entrys[ex_packet_in.PC[$clog2(`BTB_LEN)-1:0]].state = (ex_packet_in.taken ? TAKEN         : WEAK_NOTTAKE);
                WEAK_NOTTAKE:   next_btb_entrys[ex_packet_in.PC[$clog2(`BTB_LEN)-1:0]].state = (ex_packet_in.taken ? WEAK_TAKEN    : NOTTAKE);
                NOTTAKE:        next_btb_entrys[ex_packet_in.PC[$clog2(`BTB_LEN)-1:0]].state = (ex_packet_in.taken ? WEAK_NOTTAKE  : NOTTAKE);
            endcase
        end
    end
end

always_ff @(posedge clock) begin
    if (reset) begin
        for (int i = 0; i < `BTB_LEN; i++) begin
            btb_entrys[i].state <= `SD 0;
            btb_entrys[i].busy <= `SD 0;
            btb_entrys[i].tag <= `SD 0;
            btb_entrys[i].target_pc <= `SD 0;
        end
    end
    else btb_entrys         <= `SD next_btb_entrys;
end

endmodule

`endif