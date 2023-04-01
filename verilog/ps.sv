/////////////////////////////////////////////////////////////////////////
//                                                                     //
//   Modulename :  ps.sv                                               //
//                                                                     //
//  Description :  A priority selector module with parameterized       //
//                 number of bits.                                     //
//                 Feel free to use as needed for project 4!           //
//                 originally written in 2009!!! (updated in 2023)     //
//                                                                     //
/////////////////////////////////////////////////////////////////////////

`ifndef __PS_SV__
`define __PS_SV__

`define PS_DEFAULT_N_BITS 8

module ps #(parameter N_BITS = `PS_DEFAULT_N_BITS) (
	input [N_BITS-1:0] req,
	input              en,

	output [N_BITS-1:0] gnt,
	output              req_up
);

	wire [N_BITS-2:0] req_ups;
	wire [N_BITS-2:0] enables;

	assign req_up = req_ups[N_BITS-2];
	assign enables[N_BITS-2] = en;

	genvar i,j;
	generate
		// not well-defined for N_BITS < 2 (what are you selecting between?)
		if (N_BITS == 2) begin
			ps2 single (
				.req    (req),
				.en     (en),
				.gnt    (gnt),
				.req_up (req_up)
			);
		end else begin
			for(i = 0; i < N_BITS/2; i = i+1) begin
				ps2 base (
					.req    (req[2*i+1:2*i]),
					.en     (enables[i]),
					.gnt    (gnt[2*i+1:2*i]),
					.req_up (req_ups[i])
				);
			end

			for(j = N_BITS/2; j <= N_BITS-2; j = j+1) begin
				ps2 top (
					.req    (req_ups[2*j-N_BITS+1:2*j-N_BITS]),
					.en     (enables[j]),
					.gnt    (enables[2*j-N_BITS+1:2*j-N_BITS]),
					.req_up (req_ups[j])
				);
			end
		end
	endgenerate

endmodule // module ps


module ps2 (
	input [1:0] req,
	input       en,

	output [1:0] gnt,
	output       req_up
);

	assign gnt[1] = en & req[1];
	assign gnt[0] = en & req[0] & !req[1];
	assign req_up = req[1] | req[0];

endmodule // module ps2

`endif //__PS_SV__
