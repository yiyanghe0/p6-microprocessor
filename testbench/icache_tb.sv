`define TEST_MODE
`include "sys_defs.svh"


module prefetch_testbench;

    int          pipe_output;   // used for function pipeline_output
    logic [63:0] debug_counter; // counter used for when pipeline infinite loops, forces termination
    string pipeline_output_file;

    logic clock;
    logic reseti;
    logic resetd;
    logic reset;
    logic [10:0] cycle_count;

    // from if stage
    logic [`XLEN-1:0] proc2Icache_addr;


	// from ex stage
	logic [`XLEN-1:0] proc2Dcache_addr;
    logic [63:0]      proc2Dcache_data;
    logic [1:0]       proc2Dcache_command; // 0: None, 1: Load, 2: Store
    logic [2:0]       proc2Dcache_size;



	// to ex stage
	logic [63:0] Dcache_data_out; // value is memory[proc2Dcache_addr]
	logic        Dcache_valid_out; // when this is high
	logic 		 finished;		// finished current instruction
    logic [63:0]      Icache_data_out;
    logic             Icache_valid_out;

    // cache conctroller
    logic [3:0]       mem2proc_response;
    logic [63:0]      mem2proc_data;
    logic [3:0]       mem2proc_tag;
    logic [1:0]       proc2mem_command;
    logic [`XLEN-1:0] proc2mem_addr;
    logic [1:0]       Icache2ctrl_command;
    logic [`XLEN-1]   Icache2ctrl_addr;
    logic [3:0]       ctrl2Icache_response;
    logic [63:0]      ctrl2Icache_data;
    logic [3:0]       ctrl2Icache_tag;
    logic [1:0]       Dcache2ctrl_command;
    logic [`XLEN-1:0] Dcache2ctrl_addr;
    logic [63:0]      Dcache2ctrl_data;
    logic [3:0]       ctrl2Dcache_response;
    logic [63:0]      ctrl2Dcache_data;
    logic [3:0]       ctrl2Dcache_tag;


    `ifdef TEST_MODE
		ICACHE_PACKET [`CACHE_LINES-1:0] show_icache_data;
	`endif	


    // Instantiate the Data Memory
	mem memory (
		// Inputs
		.clk              (clock),
		.proc2mem_command (proc2mem_command),
		.proc2mem_addr    (proc2mem_addr),
		.proc2mem_data    (proc2mem_data),

		// Outputs
		.mem2proc_response (mem2proc_response),
		.mem2proc_data     (mem2proc_data),
		.mem2proc_tag      (mem2proc_tag)
	);

    ichache icahce(
        .clock(clock),
        .reset(reseti),
        .Imem2proc_response(ctrl2Icache_response),
        .Imem2proc_data(ctrl2Icache_data),
        .Imem2proc_tag(ctrl2Icache_tag),
        .proc2Icache_addr(proc2Icache_addr),
        .proc2Imem_command(Icache2ctrl_command),
        .proc2Imem_addr(Icache2ctrl_addr),
        `ifdef TEST_MODE
		    .show_icache_data(show_icache_data),
        `endif
        .Icache_data_out(Icache_data_out),
        .Icache_valid_out(Icache_valid_out)
    );

   dcache dcache(
         .clock(clock),
         .reset(resetd),
	     .Dmem2proc_response(ctrl2Dcache_response),
	     .Dmem2proc_data(ctrl2Dcache_data),
	     .Dmem2proc_tag(ctrl2Dcache_tag),
	     .proc2Dcache_addr(proc2Dcache_addr),
         .proc2Dcache_data(proc2Dcache_data),
         .proc2Dcache_command(proc2Dcache_command), 
	     .mem_size(proc2Dcache_size), 
	     .proc2Dmem_command(Dcache2ctrl_command),
	     .proc2Dmem_addr(Dcache2ctrl_addr),
         .proc2Dmem_data(Dcache2ctrl_data),
	     .Dcache_data_out(Dcache_data_out), 
	     .Dcache_valid_out(Dcache_valid_out), 
	     .finished(finished)		
    );
 
    cache_controller cache_controller(
         .clock(clock), 
         .rest(reset),
         .mem2proc_response(mem2proc_response), // this should be zero unless we got a response
         .mem2proc_data(mem2proc_data),
         .mem2proc_tag(mem2proc_tag),
         .proc2mem_command(proc2mem_command),
         .proc2mem_addr(proc2mem_addr),
         .proc2Dmem_data(proc2Dmem_data),
         .Icache2ctrl_command(Icache2ctrl_command),
         .Icache2ctrl_addr(Icache2ctrl_addr),
         .ctrl2Icache_response(ctrl2Icache_response),
         .ctrl2Icache_data(ctrl2Icache_data),
         .ctrl2Icache_tag(ctrl2Icache_tag),
         .Dcache2ctrl_command(Dcache2ctrl_command),
         .Dcache2ctrl_addr(Dcache2ctrl_addr),
         .Dcache2ctrl_data(Dcache2ctrl_data),
         .ctrl2Dcache_response(ctrl2Dcache_response),
         .ctrl2Dcache_data(ctrl2Dcache_data),
         .ctrl2Dcache_tag(ctrl2Dcache_tag)
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

    task wait_until_dcache_finish;
		forever begin : wait_loop
			@(posedge finished);
			@(negedge clock);
			if(finished) begin
                $fdisplay(pipe_output,"-------------------------------------------------");
                $fdisplay(pipe_output,"-------------------------------------------------");
				$fdisplay(pipe_output, "@@@Finish one dcache calculation");
                $fdisplay(pipe_output,"-------------------------------------------------");
                $fdisplay(pipe_output,"-------------------------------------------------");
				disable wait_until_dcache_finish;
			end
		end
	endtask

     task wait_until_icache_finish;
		forever begin : wait_loop
			@(posedge Icache_valid_out);
			@(negedge clock);
			if(finished) begin
                $fdisplay(pipe_output,"-------------------------------------------------");
                $fdisplay(pipe_output,"-------------------------------------------------");
				$fdisplay(pipe_output, "@@@Finish one icache calculation");
                $fdisplay(pipe_output,"-------------------------------------------------");
                $fdisplay(pipe_output,"-------------------------------------------------");
				disable wait_until_icache_finish;
			end
		end
	endtask

//////////////////////////////////////////////////////////////
//////////////                  DISPLAY
/////////////////////////////////////////////////////////////

task show_cache;
    begin
        $fdisplay(pipe_output,"=====   Cache ram   =====");
        $fdisplay(pipe_output,"|Entry(idx)|valid|     Tag |             data |");
        for (int i=0; i<32; ++i) begin
            $fdisplay(pipe_output,"| %d | %b | %d | %h |", i, show_icache_data[i].valid, show_icache_data[i].tags, show_icache_data[i].data);
        end
        $fdisplay(pipe_output,"-------------------------------------------------");
    end
endtask

task show_input;
    begin
        $fdisplay(pipe_output,"=====   Mem Input   =====");
        $fdisplay(pipe_output,"response: %d,  tag: %d,  data: %h", proc2mem_command, proc2mem_addr, proc2mem_data);
        $fdisplay(pipe_output,"----------------------------------------------------------------- ");
        $fdisplay(pipe_output,"=====   IF Input   =====");
        $fdisplay(pipe_output,"addr: %d", proc2Icache_addr);
        $fdisplay(pipe_output,"----------------------------------------------------------------- ");
        $fdisplay(pipe_output,"=====   EX Input   =====");
        $fdisplay(pipe_output,"command: %d,  addr: %d,  data: %h size: %d", proc2Dcache_command, proc2Dcache_addr, proc2Dcache_data, proc2Dcache_size);
        $fdisplay(pipe_output,"----------------------------------------------------------------- ");
    end
endtask

task show_output;
    begin
        $fdisplay(pipe_output,"=====  Memory Output   =====");
        $fdisplay(pipe_output,"response: %d,  tag: %d,  data: %h", mem2proc_response, mem2proc_tag, mem2proc_data);
        $fdisplay(pipe_output,"---------------------");
        $fdisplay(pipe_output,"=====  ICache Output   =====");
        $fdisplay(pipe_output,"valid: %b , data: %h", Icache_valid_out, Icache_data_out);
        $fdisplay(pipe_output,"---------------------");
    end
endtask

// task show_cache_controls;
//     begin
//         $fdisplay(pipe_output,"=====  Cache Controls   =====");
//         $fdisplay(pipe_output,"clock: %d,  reset: %d", cache.clock, cache.reset);
//         $fdisplay(pipe_output,"hit: %d,  writeback: %d,  writeback_finished: %d", cache.hit, cache.writeback, cache.writeback_finished);
//         $fdisplay(pipe_output,"current_index: %d,  current_tag: %d,  last_index: %d, last_tag: %d", cache.current_index, cache.current_tag, cache.last_index, cache.last_tag);
//         $fdisplay(pipe_output,"changed_addr: %d,  current_mem_tag: %d,  update_mem_tag: %d", cache.changed_addr, cache.current_mem_tag, cache.update_mem_tag);
//         $fdisplay(pipe_output,"got_mem_data: %d,  unanswered_miss: %d,  miss_outstanding: %d", cache.got_mem_data, cache.unanswered_miss, cache.miss_outstanding);
//         $fdisplay(pipe_output,"command: %d,  addr: %d,  data: %h, mem_size: %d", cache.proc2Dcache_command, cache.proc2Dcache_addr, cache.proc2Dcache_data, cache.mem_size);
//         $fdisplay(pipe_output,"---------------------");
//     end
// endtask

always @(negedge clock) begin
    #1;
    if (!reset)  begin
        $fdisplay(pipe_output,"====  Cycle  %4d  ====", cycle_count);
        show_input();
        show_output();
        show_cache_controls();
        show_cache();
        $fdisplay(pipe_output,"--------------------------------------------------------------------------------");
    end
end

//////////////////////////////////////////////////////////////
//////////////                  HELP FUNCTION
/////////////////////////////////////////////////////////////

task ST;
    input [`XLEN-1:0] addr;
    input [2:0] size;
    input [63:0] data;
        begin
            proc2Dcache_command = 2'b10;
            proc2Dcache_addr = addr;
            proc2Dcache_size = size;
            proc2Dcache_data = data;
        end
endtask

task LD;
    input [`XLEN-1:0] addr;
    input [2:0] size;
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

task Fetch_PC;
    input [`XLEN-1:0] addr;
    begin
        proc2Icache_addr = addr;
    end
endtask


initial begin
    $dumpvars;

    // PIPEPRINT_UNUSED
    if ($value$plusargs("PIPELINE=%s", pipeline_output_file)) begin
        $display("Using pipeline output file: %s", pipeline_output_file);
    end else begin
        $display("Using default pipeline output file: pipeline.out");
        pipeline_output_file = "pipeline.out";
    end


    pipe_output = $fopen(pipeline_output_file);


    clock = 0;
    reset = 1;
    resetd = 1;
    reseti = 1;
    @(negedge clock);
    reset = 0;
    resetd = 0;

    // testcase 1, store with writeback
    ST(16'h0040,3'b100, 64'hFFFF_1234_4321_FFFF);
    wait_until_dcache_finish();
    @(negedge clock);
    ST(16'h8040,3'b100, 64'hFFFF_1234_4321_FFFF);
    wait_until_dcache_finish();
    @(negedge clock);

    // testcase 2, store with writeback
    ST(16'h0044,3'b100, 64'habcd_0110_1001_abcd);
    wait_until_dcache_finish();
    @(negedge clock);
    ST(16'h8044,3'b100, 64'habcd_0110_1001_abcd);
    wait_until_dcache_finish();
    @(negedge clock);

    // testcase 3, store with writeback
    ST(16'h0048,3'b010, 64'hab00_0110_1001_abcd);
    wait_until_dcache_finish();
    @(negedge clock);
    ST(16'h8048,3'b010, 64'hab00_0110_1001_abcd);
    wait_until_dcache_finish();
    @(negedge clock);

    resetd = 1;
    reseti = 0;
    Fetch_PC(16'h0040);
    wait_until_icache_finish();
    #1;
    assert(Icache_data_out == FFFF_1234_4321_FFFF) else begin
        $fdisplay("ERROR: wrong 0040 data");
        $finish;
    end
    @(negedge clock);
    Fetch_PC(16'h0044);
    #1;
    assert(Icache_valid_out == 1) else begin
        $fdisplay("ERROR: 0044 not hit");
        $finish;
    end 
    assert(Icache_data_out == abcd_0110_1001_abcd) else begin
        $fdisplay("wrong 0044 data");
        $finish;
    end
    wait_until_icache_finish();
    @(negedge clock);
    Fetch_PC(16'h0048);
    #1;
    assert(Icache_valid_out == 1) else begin
        $fdisplay("ERROR: 0048 not hit");
        $finish;
    end 
    assert(Icache_data_out == ab00_0110_1001_abcd) else begin
        $fdisplay("wrong 0048 data");
        $finish;
    end
    wait_until_icache_finish();
    @(negedge clock);


    $finish;
end


    always @(negedge clock) begin
		if(reset) begin
			$display("@@\n@@  %t : System STILL at reset, can't show anything\n@@",
			         $realtime);
            debug_counter <= 0;
		end else begin
            if(debug_counter > 1000) begin
                $display("@@ : System halted\n@@");
                $fclose(pipe_output);
                #100 $finish;
            end
            debug_counter <= debug_counter + 1;
        end
    end


endmodule