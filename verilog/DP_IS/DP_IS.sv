`ifndef DP_IS_sv
`define DP_IS_sv

`include "sys_defs.svh"
`include "ISA.svh"

module DP_IS (
	input                clock,              // system clock
	input                reset,              // system reset
    input                stall,              // 1 - stall DP_IS stage;
    input                is_stall,
    input IF_ID_PACKET   if_id_packet_in,
    input CDB_PACKET     cdb_packet_in,

    output ROB2REG_PACKET rob_retire_packet,

    output logic     rob2store_start,
    output IS_PACKET is_packet_out,
    output logic next_struc_hazard,
    output logic squash,
    output IFID2BTB_PACKET id2btb_packet_out
);

logic struc_hazard;

// instantiate ID_STAGE
ID_PACKET id_packet;
// ROB2REG_PACKET rob_retire_packet;

//instantiate RS
RS2ROB_PACKET rs2rob_packet;
RS2MT_PACKET rs2mt_packet;
logic RS_struc_hazard_inv; // 0 - structural hazard; 1 - no structural hazard

// instantiate ROB
ROB2MT_PACKET rob2mt_packet;
ROB2RS_PACKET rob2rs_packet;
logic rob_struc_hazard; // 0 - no structural hazard; 1 - structural hazard
logic next_rob_struc_hazard; // 0 - no structural hazard; 1 - structural hazard in nxt cycle


// instantiate MT
MT2RS_PACKET mt2rs_packet;

assign squash = rob2rs_packet.squash;

id_stage id_stage_0 (
    .clock(clock),
    .reset(reset),
    .rob_retire_packet_in(rob_retire_packet),
    .if_id_packet_in(if_id_packet_in),

    .id_packet_out(id_packet),
    .id2btb_packet_out(id2btb_packet_out)
);

RS RS_0 (
    .clock(clock),
    .reset(reset),
    .squash(rob2rs_packet.squash),
    // .stall(stall),
    .stall(stall || rob_struc_hazard),
    .is_stall(is_stall),
    .id_packet_in(id_packet),
    .rob2rs_packet_in(rob2rs_packet),
    .mt2rs_packet_in(mt2rs_packet),
    .cdb_packet_in(cdb_packet_in),

    .rs2rob_packet_out(rs2rob_packet),
    .rs2mt_packet_out(rs2mt_packet),
    .is_packet_out(is_packet_out),
    .valid(RS_struc_hazard_inv)
);

ROB ROB_0 (
    .clock(clock),
    .reset(reset),
    // .stall(stall),
    .stall(stall ||(~RS_struc_hazard_inv)),
    .rs2rob_packet_in(rs2rob_packet),
    .cdb_packet_in(cdb_packet_in),
    .id_packet_in(id_packet),

    .rob2store_start(rob2store_start),
    .rob2rs_packet_out(rob2rs_packet),
    .rob2mt_packet_out(rob2mt_packet),
    .rob2reg_packet_out(rob_retire_packet),
    .rob_struc_hazard_out (rob_struc_hazard),
    .next_rob_struc_hazard_out (next_rob_struc_hazard)

);

MAP_TABLE MT_0 (
    .clock(clock),
    .reset(reset),
    // .stall(stall),
    .stall(stall || struc_hazard),
    .rs2mt_packet_in(rs2mt_packet),
    .cdb_packet_in(cdb_packet_in),
    .rob2mt_packet_in(rob2mt_packet),

    .mt2rs_packet_out(mt2rs_packet)
);

// structural hazard signal to IF/ID pipeline register
assign struc_hazard = rob_struc_hazard | (~RS_struc_hazard_inv); 
assign next_struc_hazard = next_rob_struc_hazard | (~RS_struc_hazard_inv); 


endmodule
`endif  // DP_IS__SV