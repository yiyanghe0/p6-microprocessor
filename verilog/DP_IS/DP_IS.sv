`ifndef DP_IS_sv
`define DP_IS_sv

`include "sys_defs.svh"
`include "ISA.svh"

module DP_IS (
	input                clock,              // system clock
	input                reset,              // system reset
    input IF_ID_PACKET   if_id_packet_in,
    input CDB_PACKET     cdb_packet_in,

    output IS_PACKET is_packet_out,
    output logic struc_hazard
);

// instantiate ID_STAGE

ID_PACKET id_packet_out;
ROB2REG_PACKET rob_retire_packet_in;

id_stage id_stage_0 (
    .clock(clock),
    .reset(reset),
    .rob_retire_packet_in(rob_retire_packet_in),
    .if_id_packet_in(if_id_packet_in),

    .id_packet_out(id_packet_out)
);

//instantiate RS

RS2ROB_PACKET rs2rob_packet_out;
RS2MT_PACKET rs2mt_packet_out;
logic RS_struc_hazard;  

RS RS_0 (
    .clock(clock),
    .reset(reset),
    .squash(rs2rob_packet_out.squash),
    .stall(),
    .id_packet_in(id_packet_out),
    .rob2rs_packet_in(rob2rs_packet_out),
    .mt2rs_packet_in(mt2rs_packet_out),
    .cdb_packet_in(cdb_packet_in),

    .rs2rob_packet_out(rs2rob_packet_out),
    .rs2mt_packet_out(rs2mt_packet_out)
    .is_packet_out(is_packet_out),
    .valid(RS_struc_hazard)
);

// instantiate ROB

ROB2MT_PACKET rob2mt_packet_out;
ROB2RS_PACKET rob2rs_packet_out;
logic rob_struc_hazard;

ROB ROB_0 (
    .clock(clock),
    .reset(reset),
    .rs2rob_packet_in(rs2rob_packet_out)
    .cdb_packet_in(cdb_packet_in),
    .id_packet_in(id_packet_out),

    .rob2rs_packet_out(rob2rs_packet_out),
    .rob2mt_packet_out(rob2mt_packet_out),
    .rob2reg_packet_out(rob_retire_packet_in),
    .rob_struc_hazard (rob_struc_hazard)

);

// instantiate MT

MT2RS_PACKET mt2rs_packet_out;

MT MT_0 (
    .clock(clock),
    .reset(reset),
    .wr_en(),
    .rs2mt_packet_in(rs2mt_packet_out),
    .cdb_packet_in(cdb_packet_in),
    .rob2mt_packet_in(rob2mt_packet_out),

    .mt2rs_packet_out(mt2rs_packet_out)
);

// structural hazard signal to IF/ID pipeline register
assign struc_hazard = RS_struc_hazard | rob_struc_hazard; 

endmodule
