`ifndef __STORE_SV__
`define __STORE_SV__

`include "sys_defs.svh"

module STORE (
    //input
    input [`XLEN-1:0]           opa,
    input [`XLEN-1:0]           opb,
    input IS_PACKET             is_packet_in,
    input                       start,

    output logic [`XLEN-1:0]    addr_result,
    output IS_PACKET            is_packet_out,
    output logic                done            
);

//address
assign addr_result = opa + opb;
assign done = start;
assign is_packet_out = is_packet_in;

endmodule
`endif