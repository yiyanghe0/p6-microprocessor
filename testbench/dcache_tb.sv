`define TEST_MODE
`include "sys_defs.svh"
module dcache_testbench;

    int          pipe_output;   // used for function pipeline_output
    logic [63:0] debug_counter; // counter used for when pipeline infinite loops, forces termination
    string pipeline_output_file;

    logic clock;
    logic reset;
    logic [10:0] cycle_count;

    // from memory
	logic [3:0]  Dmem2proc_response; // this should be zero unless we got a response
    logic  [63:0] Dmem2proc_data;
	logic [3:0]  Dmem2proc_tag;

	// from ex stage
	logic [`XLEN-1:0] proc2Dcache_addr;
    logic [63:0]      proc2Dcache_data;
    logic [1:0]       proc2Dcache_command; // 0: None, 1: Load, 2: Store
    logic [1:0]       proc2Dcache_size;

	// to memory
	logic [1:0]       proc2Dmem_command;
	logic [`XLEN-1:0] proc2Dmem_addr;
    logic [63:0]      proc2Dmem_data;

	// to ex stage
	logic [63:0] Dcache_data_out; // value is memory[proc2Dcache_addr]
	logic        Dcache_valid_out; // when this is high
	logic 		finished;		// finished current instruction

    `ifdef TEST_MODE
		DCACHE_PACKET [`DCACHE_LINES-1:0] show_dcache_data;
	`endif 

    dcache cache(
        .clock(clock),
        .reset(reset),
        .Dmem2proc_response(Dmem2proc_response),
        .Dmem2proc_data(Dmem2proc_data),
        .Dmem2proc_tag(Dmem2proc_tag),
        .proc2Dcache_addr(proc2Dcache_addr),
        .proc2Dcache_data(proc2Dcache_data),
        .proc2Dcache_command(proc2Dcache_command),
        .mem_size(proc2Dcache_size),
        .proc2Dmem_command(proc2Dmem_command),
        .proc2Dmem_addr(proc2Dmem_addr),
        .proc2Dmem_data(proc2Dmem_data),

        `ifdef TEST_MODE
            .show_dcache_data(show_dcache_data),
        `endif
        .Dcache_data_out(Dcache_data_out),
        .Dcache_valid_out(Dcache_valid_out),
        .finished(finished)
    );

    // Instantiate the Data Memory
	mem memory (
		// Inputs
		.clk              (clock),
		.proc2mem_command (proc2Dmem_command),
		.proc2mem_addr    (proc2Dmem_addr),
		.proc2mem_data    (proc2Dmem_data),

		// Outputs
		.mem2proc_response (Dmem2proc_response),
		.mem2proc_data     (Dmem2proc_data),
		.mem2proc_tag      (Dmem2proc_tag)
	);

    always begin
        #5;
        clock = ~clock;
    end

    always_ff@(posedge clock) begin
    if (reset)
        cycle_count <= 0;
    else 
        cycle_count <= cycle_count + 1;
    end

    task wait_until_finish;
		forever begin : wait_loop
			@(posedge finished);
			@(negedge clock);
			if(finished) begin
				$display("@@@Finish one value calculation");
				// disable wait_until_done;
			end
		end
	endtask

//////////////////////////////////////////////////////////////
//////////////                  DISPLAY
/////////////////////////////////////////////////////////////

task show_cache;
    begin
        $fdisplay(pipe_output,"=====   Cache ram   =====");
        $fdisplay(pipe_output,"|Entry(idx)|valid|dirty|      Tag |             data |");
        for (int i=0; i<32; ++i) begin
            $fdisplay(pipe_output,"| %d | %b | %b | %d | %h |", i, show_dcache_data[i].valid, show_dcache_data[i].dirty, show_dcache_data[i].tags, show_dcache_data[i].data);
        end
        $fdisplay(pipe_output,"-------------------------------------------------");
    end
endtask

task show_input;
    begin
        $fdisplay(pipe_output,"=====   Mem2proc Input   =====");
        $fdisplay(pipe_output,"response: %d,  tag: %d,  data: %h", Dmem2proc_response, Dmem2proc_tag, Dmem2proc_data);
        $fdisplay(pipe_output,"----------------------------------------------------------------- ");
        $fdisplay(pipe_output,"=====   EX Input   =====");
        $fdisplay(pipe_output,"command: %d,  addr: %d,  data: %h", proc2Dcache_command, proc2Dcache_addr, proc2Dcache_data);
        $fdisplay(pipe_output,"----------------------------------------------------------------- ");
    end
endtask

task show_output;
    begin
        $fdisplay(pipe_output,"=====  Cache2Memory Output   =====");
        $fdisplay(pipe_output,"command: %d,  addr: %d,  data: %h", proc2Dmem_command, proc2Dmem_addr, proc2Dmem_data);
        $fdisplay(pipe_output,"---------------------");
        $fdisplay(pipe_output,"=====  Cache2EX Output   =====");
        $fdisplay(pipe_output,"valid: %b , data: %h, finished: %b", Dcache_valid_out, Dcache_data_out, finished);
        $fdisplay(pipe_output,"---------------------");
    end
endtask

always @(negedge clock) begin
    #1;
    if (!reset)  begin
        $fdisplay(pipe_output,"====  Cycle  %4d  ====", cycle_count);
        show_input();
        show_output();
        show_cache();
        $fdisplay(pipe_output,"--------------------------------------------------------------------------------");
    end
end

//////////////////////////////////////////////////////////////
//////////////                  HELP FUNCTION
/////////////////////////////////////////////////////////////

task ST;
    input [`XLEN-1:0] addr;
    input [1:0] size;
        begin
            proc2Dcache_command = 2'b10;
            proc2Dcache_addr = addr;
            proc2Dcache_size = size;
            proc2Dcache_data = $random(64);
        end
endtask

task LD;
    input [`XLEN-1:0] addr;
    input [1:0] size;
        begin
            proc2Dcache_command = 2'b01;
            proc2Dcache_addr = addr;
            proc2Dcache_size = size;
            proc2Dcache_data = $random(64);
        end
endtask

task NONE;
    begin
        proc2Dcache_command = 2'b00;
        proc2Dcache_addr = $random(32);
        proc2Dcache_data = $random(64);
    end
endtask


initial begin
    $dumpvars;

    // PIPEPRINT_UNUSED
    if ($value$plusargs("PIPELINE=%s", pipeline_output_file)) begin
        $display("Using pipeline output file: %s", pipeline_output_file);
    end else begin
        $display("Using default pipeline output file: dcache.out");
        pipeline_output_file = "dcache.out";
    end


    clock = 0;
    reset = 1;
    @(negedge clock);
    reset = 0;
    LD(1,0);
    wait_until_finish();
    @(negedge clock);
    ST(3,2);
    wait_until_finish();
    @(negedge clock);
    ST(4,1);
    wait_until_finish();
    @(negedge clock);
    ST(1,0);
    wait_until_finish();
    @(negedge clock);
    NONE();
    wait_until_finish();
    @(negedge clock);
    LD(1,0);
    wait_until_finish();
    @(negedge clock);
    ST(1,2);
    wait_until_finish();
    @(negedge clock);
    ST(5,3);
    wait_until_finish();
    @(negedge clock);
    ST(4,4);
    wait_until_finish();
    @(negedge clock);
    NONE();
    wait_until_finish();
    @(negedge clock);
    LD(1,4);
    wait_until_finish();
    @(negedge clock);
    LD(4,2);
    wait_until_finish();
    @(negedge clock);
    LD(4,3);
    wait_until_finish();
    @(negedge clock);
    ST(3,2);
    wait_until_finish();
    @(negedge clock);
    ST(4,3);
    wait_until_finish();
    @(negedge clock);
    ST(1,2);
    wait_until_finish();
    @(negedge clock);
    NONE();
    wait_until_finish();
    @(negedge clock);
    LD(1,4);
    wait_until_finish();
    @(negedge clock);
    LD(2,4);
    wait_until_finish();
    @(negedge clock);
    LD(3,2);
    wait_until_finish();
    @(negedge clock);
    ST(3,3);
    @(negedge clock);
    LD(4,2);
    wait_until_finish();
    @(negedge clock);
    ST(1,3);
    wait_until_finish();
    @(negedge clock);
    NONE();
    @(negedge clock);
    LD(1,2);
    wait_until_finish();
    @(negedge clock);
    LD(3,2);
    wait_until_finish();
    @(negedge clock);
    NONE();
    wait_until_finish();

    pipe_output = $fopen(pipeline_output_file);	
    $finish;
end


    always @(negedge clock) begin
		if(reset) begin
			$display("@@\n@@  %t : System STILL at reset, can't show anything\n@@",
			         $realtime);
            debug_counter <= 0;
		end else begin
            if(debug_counter > 50000) begin
                $display("@@ : System halted\n@@");
                $fclose(pipe_output);
                #100 $finish;
            end
            debug_counter <= debug_counter + 1;
        end
    end


endmodule