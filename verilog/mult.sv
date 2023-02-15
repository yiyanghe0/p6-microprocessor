/////////////////////////////////////////////////////////////////////////
//                                                                     //
//   Modulename :  mult.sv                                             //
//                                                                     //
//  Description :  A pipelined multiplier module with parameterized    //
//                 number of stages, as seen in project 2.             //
//                 Shouldn't need any changes for project 4.           //
//                                                                     //
/////////////////////////////////////////////////////////////////////////

`ifndef __MULT_SV__
`define __MULT_SV__

`include "sys_defs.svh"

`define MULT_DEFAULT_N_STAGES 4

// TODO: attach this to the alu (add a check in execute if an FU hasn't finished)
// feel free to change this module's input/output behavior as needed, but it must remain pipelined

// also note that there are different types of multiplies that must be handled (upper half, signed/unsigned)

module mult #(parameter NUM_STAGES = `MULT_DEFAULT_N_STAGES) (
	input             clock, reset,
	input             start,
	input             mcand_sign, mplier_sign, // NOTE: need to manually determine sign of mcand/mplier
	input [`XLEN-1:0] mcand, mplier,

	output [(2*`XLEN)-1:0] product,
	output                 done
);

	logic [(2*`XLEN)-1:0] mcand_in, mplier_in, mcand_out, mplier_out; // out signals are unused
	// sign extend the inputs
	assign mcand_in  = mcand_sign  ? {{`XLEN{mcand[`XLEN-1]}}, mcand}   : {`XLEN'('b0), mcand};
	assign mplier_in = mplier_sign ? {{`XLEN{mplier[`XLEN-1]}}, mplier} : {`XLEN'('b0), mplier};

	logic [NUM_STAGES-2:0][2*`XLEN-1:0] internal_mcands, internal_mpliers;
	logic [NUM_STAGES-2:0][2*`XLEN-1:0] internal_products;
	logic [NUM_STAGES-2:0]              internal_dones;
	mult_stage #(.NUM_STAGES(NUM_STAGES)) mstage [NUM_STAGES-1:0] (
		// Inputs
		.clock      (clock),
		.reset      (reset),
		.start      ({internal_dones, start}),
		.mplier_in  ({internal_mpliers, mplier_in}),
		.mcand_in   ({internal_mcands, mcand_in}),
		.product_in ({internal_products, 64'h0}),

		// Outputs
		.mplier_out  ({mplier_out, internal_mpliers}),
		.mcand_out   ({mcand_out, internal_mcands}),
		.product_out ({product, internal_products}),
		.done        ({done, internal_dones})
	);

endmodule // module mult


module mult_stage #(parameter NUM_STAGES = `MULT_DEFAULT_N_STAGES) (
	input                 clock, reset, start,
	input [2*`XLEN-1:0] mplier_in, mcand_in,
	input [2*`XLEN-1:0] product_in,

	output logic                 done,
	output logic [2*`XLEN-1:0] mplier_out, mcand_out,
	output logic [2*`XLEN-1:0] product_out
);

	parameter NUM_BITS = (2*`XLEN)/NUM_STAGES;

	logic [2*`XLEN-1:0] prod_in_reg, partial_prod, next_partial_product;
	logic [2*`XLEN-1:0] next_mplier, next_mcand;

	assign product_out = prod_in_reg + partial_prod;

	assign next_partial_product = mplier_in[NUM_BITS-1:0] * mcand_in;

	assign next_mplier = {NUM_BITS'('b0), mplier_in[2*`XLEN-1:NUM_BITS]};
	assign next_mcand  = {mcand_in[(2*`XLEN-1-NUM_BITS):0], NUM_BITS'('b0)};

	//synopsys sync_set_reset "reset"
	always_ff @(posedge clock) begin
		prod_in_reg  <= `SD product_in;
		partial_prod <= `SD next_partial_product;
		mplier_out   <= `SD next_mplier;
		mcand_out    <= `SD next_mcand;
	end

	// synopsys sync_set_reset "reset"
	always_ff @(posedge clock) begin
		if(reset) begin
			done <= `SD 1'b0;
		end else begin
			done <= `SD start;
		end
	end

endmodule // module mult_stage

`endif //__MULT_SV__
