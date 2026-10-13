// AI-authored default-unavailable backend regression. No key material.
`timescale 1ns/1ps
module tb_unavailable_keygen_backend;
reg clock;
reg reset_n;
reg start;
reg descriptor_valid;
reg session_validated;
reg [31:0] command_code;
reg [31:0] descriptor_id;
reg [1:0] descriptor_alg;
reg [11:0] descriptor_bits;
reg [1:0] descriptor_mode;
reg [31:0] descriptor_context;
reg [31:0] descriptor_destination;
reg [31:0] descriptor_exponent;
reg cancel;
wire busy;
wire terminal_valid;
reg terminal_ready;
wire [31:0] terminal_code;
wire [31:0] terminal_object;
wire req_valid;
reg req_ready;
wire [31:0] req_id;
wire [1:0] req_alg;
wire [11:0] req_bits;
wire [1:0] req_mode;
wire [31:0] req_context;
wire [31:0] req_destination;
wire [31:0] req_exponent;
wire cancel_valid;
reg cancel_ready;
wire [31:0] cancel_id;
reg rsp_valid;
wire rsp_ready;
reg [31:0] rsp_id;
reg rsp_fail;
reg [31:0] rsp_code;
reg [31:0] rsp_object;
keygen_dispatch_adapter dut(.clock_i(clock),.reset_n_i(reset_n),.start_i(start),.descriptor_valid_i(descriptor_valid),.session_validated_i(session_validated),.command_code_i(command_code),.descriptor_id_i(descriptor_id),.descriptor_alg_i(descriptor_alg),.descriptor_bits_i(descriptor_bits),.descriptor_mode_i(descriptor_mode),.descriptor_context_i(descriptor_context),.descriptor_destination_i(descriptor_destination),.descriptor_exponent_i(descriptor_exponent),.cancel_i(cancel),.busy_o(busy),.terminal_valid_o(terminal_valid),.terminal_ready_i(terminal_ready),.terminal_code_reg_o(terminal_code),.terminal_object_reg_o(terminal_object),.req_valid_o(req_valid),.req_ready_i(req_ready),.req_id_reg_o(req_id),.req_alg_reg_o(req_alg),.req_bits_reg_o(req_bits),.req_mode_reg_o(req_mode),.req_context_reg_o(req_context),.req_destination_reg_o(req_destination),.req_exponent_reg_o(req_exponent),.cancel_valid_o(cancel_valid),.cancel_ready_i(cancel_ready),.cancel_id_o(cancel_id),.rsp_valid_i(rsp_valid),.rsp_ready_o(rsp_ready),.rsp_id_i(rsp_id),.rsp_fail_i(rsp_fail),.rsp_code_i(rsp_code),.rsp_object_i(rsp_object));
always #5 clock=~clock;
initial begin clock=0;
reset_n=0;
start=0;
descriptor_valid=0;
session_validated=0;
command_code=0;
descriptor_id=0;
descriptor_alg=0;
descriptor_bits=0;
descriptor_mode=0;
descriptor_context=0;
descriptor_destination=0;
descriptor_exponent=0;
cancel=0;
terminal_ready=0;
req_ready=0;
cancel_ready=0;
rsp_valid=0;
rsp_id=0;
rsp_fail=0;
rsp_code=0;
rsp_object=0;

 repeat(2) @(negedge clock); reset_n=1; descriptor_valid=1; session_validated=1;
 command_code=32'h153; descriptor_id=1; descriptor_alg=1; descriptor_bits=256;
 req_ready=1; rsp_valid=1; rsp_id=1; rsp_code=0; rsp_fail=0; rsp_object=32'h55;
 @(negedge clock); // Sample low start after reset before arming a new request.
 start=1; @(negedge clock);
 if(!terminal_valid || terminal_code!==32'h143 || terminal_object!==0 || req_valid || rsp_ready)
  $fatal(1,"default unavailable backend did not fail closed");
 repeat(5) @(negedge clock);
 if(terminal_code!==32'h143) $fatal(1,"default error not retained");
 terminal_ready=1; @(negedge clock); terminal_ready=0;
 repeat(5) @(negedge clock);
 if(busy || req_valid || terminal_valid) $fatal(1,"held start retriggered unavailable backend");
 $display("PASS default-unavailable backend never launches or reports success"); $finish;
end
initial begin #2000; $fatal(1,"timeout"); end
endmodule
