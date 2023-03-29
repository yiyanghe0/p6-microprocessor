`define DEBUG
module testbench_ex_stage;

    logic clock;
    logic reset;
    IS_PACKET               is_packet_in;
    EX_PACKET               ex_packet_out;
    CHANNEL                 channel_in;
    logic valid;
    logic no_output;

    EX ex_stage(
    .clock(clock), .reset(reset), .is_packet_in(is_packet_in),
    .ex_packet_out(ex_packet_out), .valid(valid),
    .no_output(no_output)
);

//alu task
task check_alu_func;
    input [`XLEN-1:0] correct_alu_result;
    begin 
        #1 assert (ex_packet_out.alu_result == correct_alu_result)          else exit_alu_on_error(correct_alu_result);
    end
endtask

task exit_alu_on_error;
    input [`XLEN-1:0] correct_alu_result;
    begin
        $display("@@@ Incorrect at time %4.0f", $time);
        $display("@@@ Expected alu_result: %h; Actual alu_result: %h", correct_alu_result, ex_packet_out.alu_result);
        $display("@@@ ----------------------------------------- @@@");
        $display("@@@failed");
        $finish;
    end
endtask

//branch task 
task check_branch_func;
    input [`XLEN-1:0] correct_alu_result;
    input             correct_take_branch_result;
    begin 
        #1 assert (ex_packet_out.alu_result == correct_alu_result)                             else exit_branch_on_error(correct_alu_result, correct_take_branch_result);
           assert (ex_packet_out.take_branch == correct_take_branch_result)                    else exit_branch_on_error(correct_alu_result, correct_take_branch_result);
    end
endtask

task exit_branch_on_error;
    input [`XLEN-1:0] correct_alu_result;
    input correct_take_branch_result;

    begin
        $display("@@@ Incorrect at time %4.0f", $time);
        $display("@@@ Expected alu_result: %h; Actual alu_result: %h", correct_alu_result, ex_packet_out.alu_result);
        $display("@@@ Expected take_branch_result: %h; Actual take_branch_result: %h", correct_take_branch_result, ex_packet_out.take_branch);
        $display("@@@ ----------------------------------------- @@@");
        $display("@@@failed");
        $finish;
    end
endtask

always begin
        #5;
        clock = ~clock;
    end

    logic [2:0] func3;
    logic [3:0] et;
    assign is_packet_in.inst.inst = (et << 8) + (func3 << 12);

//Test case begin
    initial begin
    is_packet_in.rs1_value = 32'h87654321;
    is_packet_in.rs2_value = 32'h12345678;

    $monitor("TIME:%4.0f result:%8b channel:%8b valid:%8b no_output:%8b", $time, ex_packet_out.alu_result, channel_in, valid, no_output);
    clock = 0;
    reset = 1;
    @(negedge clock);
    reset = 0;
//case: ALU Func test
    is_packet_in.channel  = ALU;// switch to ALU Func
    is_packet_in.alu_func = 5'h00;//switch to ADD
    is_packet_in.opa_select = 2'h0;// switch to rs1_value
    is_packet_in.opb_select = 2'h0;//switch to rs2_value
    check_alu_func(32'h99999999);

    @(negedge clock);
    is_packet_in.alu_func = 5'h01;//switch to SUB
    is_packet_in.opa_select = 2'h0;// switch to rs1_value
    is_packet_in.opb_select = 2'h0;
    check_alu_func(32'h7530ECA9);

    @(negedge clock);
    is_packet_in.alu_func = 5'h04;//switch to AND
    is_packet_in.opa_select = 2'h0;// switch to rs1_value
    is_packet_in.opb_select = 2'h0;
    check_alu_func(32'h2244220);

    @(negedge clock);
    is_packet_in.alu_func = 5'h05;//switch to OR
    is_packet_in.opa_select = 2'h0;// switch to rs1_value
    is_packet_in.opb_select = 2'h0;
    check_alu_func(32'h97755779);	

    @(negedge clock);
    is_packet_in.alu_func = 5'h06;//switch to XOR
    is_packet_in.opa_select = 2'h0;// switch to rs1_value
    is_packet_in.opb_select = 2'h0;
    check_alu_func(32'h95511559);	

    @(negedge clock);
    is_packet_in.alu_func = 5'h0e;//switch to DIV
    is_packet_in.opa_select = 2'h0;// switch to rs1_value
    is_packet_in.opb_select = 2'h0;
    check_alu_func(32'h7F6E5D9);

//case: Branch Func test  
   @(negedge clock);
   //This beq will branch
    is_packet_in.rs2_value = 32'h87654321;
    is_packet_in.PC = 15;
    is_packet_in.channel  = BR;// switch to Br Func
    func3 = 3'b000;//BEQ
    et = 4'b0010;
    is_packet_in.opa_select = OPA_IS_PC;// switch to rs1_value
    is_packet_in.opb_select = OPB_IS_B_IMM;//switch to rs2_value
    check_branch_func(19,1);

   @(negedge clock);
    //This beq will not branch
    is_packet_in.rs2_value = 32'h12345678;
    is_packet_in.PC = 15;
    is_packet_in.channel  = BR;// switch to Br Func
    func3 = 3'b000;//BEQ
    et = 4'b0010;
    is_packet_in.opa_select = OPA_IS_PC;// switch to rs1_value
    is_packet_in.opb_select = OPB_IS_B_IMM;//switch to rs2_value
    check_branch_func(19,0);

   @(negedge clock);
    //This beq will not branch
    is_packet_in.PC = 15;
    is_packet_in.channel  = BR;// switch to Br Func
    func3 = 3'b001;//BNE
    et = 4'b0010;
    is_packet_in.opa_select = OPA_IS_PC;// switch to rs1_value
    is_packet_in.opb_select = OPB_IS_B_IMM;//switch to rs2_value
    check_branch_func(19,1);
      
   @(negedge clock);
    //This beq will not branch
    is_packet_in.PC = 15;
    is_packet_in.channel  = BR;// switch to Br Func
    func3 = 3'b100;//BLT
    et = 4'b0010;
    is_packet_in.opa_select = OPA_IS_PC;// switch to rs1_value
    is_packet_in.opb_select = OPB_IS_B_IMM;//switch to rs2_value
    check_branch_func(19,1);

   @(negedge clock);
    //This beq will not branch
    is_packet_in.PC = 15;
    is_packet_in.channel  = BR;// switch to Br Func
    func3 = 3'b101;//BGE
    et = 4'b0010;
    is_packet_in.opa_select = OPA_IS_PC;// switch to rs1_value
    is_packet_in.opb_select = OPB_IS_B_IMM;//switch to rs2_value
    check_branch_func(19,0);

   @(negedge clock);
    //This beq will not branch
    is_packet_in.PC = 15;
    is_packet_in.channel  = BR;// switch to Br Func
    func3 = 3'b110;//BLTU
    et = 4'b0010;
    is_packet_in.opa_select = OPA_IS_PC;// switch to rs1_value
    is_packet_in.opb_select = OPB_IS_B_IMM;//switch to rs2_value
    check_branch_func(19,0);

   @(negedge clock);
    //This beq will not branch
    is_packet_in.PC = 15;
    is_packet_in.channel  = BR;// switch to Br Func
    func3 = 3'b111;//BGEU
    et = 4'b0010;
    is_packet_in.opa_select = OPA_IS_PC;// switch to rs1_value
    is_packet_in.opb_select = OPB_IS_B_IMM;//switch to rs2_value
    check_branch_func(19,1);


//case: Branch Mult test  
   @(negedge clock);
    is_packet_in.channel = MULT;
    is_packet_in.rs1_value = 32'h00000001;
    is_packet_in.rs2_value = 32'h00000002;
    is_packet_in.opa_select = 2'h0;// switch to rs1_value
    is_packet_in.opb_select = 2'h0;//switch to rs2_value
    is_packet_in.alu_func = 5'h0a;

  @(negedge clock);
    is_packet_in.rs1_value = 32'h00000003;
    is_packet_in.rs2_value = 32'h00000003;
    is_packet_in.opa_select = 2'h0;// switch to rs1_value
    is_packet_in.opb_select = 2'h0;//switch to rs2_value
    is_packet_in.alu_func = 5'h0b;

  @(negedge clock);
    is_packet_in.channel = ALU;
    is_packet_in.rs1_value = 32'h87654321;
    is_packet_in.rs2_value = 32'h12345678;
    is_packet_in.alu_func = 5'h01;//switch to SUB
    is_packet_in.opa_select = 2'h0;// switch to rs1_value
    is_packet_in.opb_select = 2'h0;
    check_alu_func(32'h7530ECA9);

  @(negedge clock);
    is_packet_in.alu_func = 5'h04;//switch to AND
    is_packet_in.opa_select = 2'h0;// switch to rs1_value
    is_packet_in.opb_select = 2'h0;
    check_alu_func(32'h2244220);

  @(negedge clock);
    is_packet_in.alu_func = 5'h05;//switch to OR
    is_packet_in.opa_select = 2'h0;// switch to rs1_value
    is_packet_in.opb_select = 2'h0;
    check_alu_func(32'h00000002);
   // check_alu_func(32'h97755779);
    	
  
  @(negedge clock);
    is_packet_in.alu_func = 5'h06;//switch to XOR
    is_packet_in.opa_select = 2'h0;// switch to rs1_value
    is_packet_in.opb_select = 2'h0;
    check_alu_func(32'h00000000);
    //check_alu_func(32'h95511559);	

  @(negedge clock);
    is_packet_in.alu_func = 5'h0e;//switch to DIV
    is_packet_in.opa_select = 2'h0;// switch to rs1_value
    is_packet_in.opb_select = 2'h0;

    // check_alu_func(32'h97755779);

 //   check_alu_func(32'h7F6E5D9);
  $display("@@@passed!!!");

  $finish;

 
    
    end

endmodule