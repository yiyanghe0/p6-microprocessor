/////////////////////////////////////////////////////////////////////////
//                                                                     //
//   Modulename :  mult_tb.sv                                          //
//                                                                     //
//  Description :  An example testbench for the multiplier module      //
//                 the same one as in project 2 :/                     //
//                                                                     //
/////////////////////////////////////////////////////////////////////////

`include "sys_defs.svh"

module mult_tb;

	integer i;
	logic [31:0] a, b;
	logic clock, start, reset;

	logic [63:0] result;
	logic done;

	mult #(.NUM_STAGES(4)) m0(
		.clock(clock),
		.reset(reset),
		.start(start),
		.mcand_sign(1'b0),  // note: this testbench was stolen from project 2
		.mplier_sign(1'b0), // and is not a comprehensive testbench for a signed multiplier
		.mcand(a),
		.mplier(b),
		.product(result),
		.done(done)
	);


	wire [63:0] correct_result = a * b;
	wire correct = (correct_result === result) | ~done;
	always @(posedge clock) begin
		#2 if (!correct) begin
			$display("@@@Failed at time %4.0f", $time);
			$display("correct result = %h result = %h", correct_result, result);
			$finish;
		end
	end


	always begin
		#(`CLOCK_PERIOD/2);
		clock = ~clock;
	end


	// Some students have had problems just using "@(posedge done)" because their
	// "done" signals glitch (even though they are the output of a register). This
	// prevents that by making sure "done" is high at the clock edge.
	task wait_until_done;
		forever begin : wait_loop
			@(posedge done);
			@(negedge clock);
			if(done) disable wait_until_done;
		end
	endtask


	initial begin
		$monitor("Time:%4.0f done:%b a:%h b:%h correct result:%h result:%h",
		         $time, done, a, b, correct_result, result);

		reset = 1;
		clock = 0;
		a = 2;
		b = 3;
		start = 1;

		@(negedge clock);
		reset = 0;
		@(negedge clock);
		start = 0;
		wait_until_done();

		start = 1;
		a = -1;
		@(negedge clock);
		start = 0;
		wait_until_done();

		@(negedge clock);
		start=1;
		a = -20;
		b = 5;
		@(negedge clock);
		start = 0;
		wait_until_done();

		// randomized testing
		for (i = 0; i < 20; i += 1) begin
			start = 1;
			a = $random;
			b = $random;
			@(negedge clock);
			start = 0;
			wait_until_done();
		end
		$display("@@@Passed");
		$finish;
	end

endmodule // module mult_tb
