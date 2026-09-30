// AI-authored self-checking unit plumbing test. Backend responses below are mocks, not keys.
`timescale 1ns/1ps
module tb_execution_keygen_plumbing;
reg response_ready;
reg command_cancel;
reg keygen_descriptor_valid;
reg keygen_session_validated;
reg [31:0] keygen_id;
reg [1:0] keygen_alg;
reg [11:0] keygen_bits;
reg [1:0] keygen_mode;
reg [31:0] keygen_context;
reg [31:0] keygen_destination;
reg [31:0] keygen_exponent;
wire keygen_busy;
wire [31:0] keygen_object;
wire kg_req_valid;
reg kg_req_ready;
wire [31:0] kg_req_id;
wire [1:0] kg_req_alg;
wire [11:0] kg_req_bits;
wire [1:0] kg_req_mode;
wire [31:0] kg_req_context;
wire [31:0] kg_req_destination;
wire [31:0] kg_req_exponent;
wire kg_cancel_valid;
reg kg_cancel_ready;
wire [31:0] kg_cancel_id;
reg kg_rsp_valid;
wire kg_rsp_ready;
reg [31:0] kg_rsp_id;
reg kg_rsp_fail;
reg [31:0] kg_rsp_code;
reg [31:0] kg_rsp_object;
reg clock;
reg reset_n;
reg command_ready;
reg [15:0] command_tag;
reg [31:0] command_size;
reg [31:0] command_code;
reg [15:0] command_length;
reg [31:0] handle_0;
reg [31:0] handle_1;
reg [31:0] handle_2;
reg [2:0]  op_state;
reg [2:0]  startup_type;
reg phEnable;
reg phEnableNV;
reg shEnable;
reg ehEnable;
reg [15:0] shutdownSave;
reg command_done;
reg [31:0] session0_handle;
reg [31:0] session1_handle;
reg [31:0] session2_handle;
reg [7:0] session0_attributes;
reg [7:0] session1_attributes;
reg [7:0] session2_attributes;
reg [15:0] session0_hmac_size;
reg [15:0] session1_hmac_size;
reg [15:0] session2_hmac_size;
reg session0_valid;
reg session1_valid;
reg session2_valid;
reg [31:0] authorization_size;
reg session_loaded;
reg [15:0] max_session_amount;
reg auth_session;
reg auth_necessary;
reg [31:0] authHandle;
reg [7:0] pcrSelect;
reg auth_done;
reg auth_success;
reg [11:0] auth_response_code;
reg param_decrypt_success;
reg param_decrypt_fail;
reg param_unmarshall_success;
reg param_unmarshall_fail;
reg execution_startup_done;
reg [31:0] execution_response_code;
reg nv_phEnableNV_in;
reg nv_shEnable_in;
reg nv_ehEnable_in;
reg [31:0] tpm_nv_index;
reg [31:0] nv_index_attributes;
reg nv_object_present;
reg nv_index_present;
reg [31:0] entity_hierarchy;
reg [15:0] mem_orderly;
reg ram_available;
reg loaded_object_present;
reg [31:0] object_attributes;
reg [15:0] st_testsRun;
reg [15:0] st_testsPassed;
reg [15:0] st_untested;
wire command_accept, command_busy;
wire response_valid;
wire [31:0] response_code;
wire [15:0] response_length;
wire [3:0]  current_state;
wire command_start;
wire [15:0] orderlyInput;
wire initialized;
wire [15:0] testsRun;
wire [15:0] testsPassed;
wire [15:0] untested;
wire nv_phEnableNV;
wire nv_shEnable;
wire nv_ehEnable;
wire [31:0] authHierarchy;
execution_engine #(.KEYGEN_EXTERNAL_BACKEND(1)) dut(.command_accept(command_accept),.command_busy(command_busy),.response_ready(response_ready),.command_cancel(command_cancel),.keygen_descriptor_valid(keygen_descriptor_valid),.keygen_session_validated(keygen_session_validated),.keygen_id(keygen_id),.keygen_alg(keygen_alg),.keygen_bits(keygen_bits),.keygen_mode(keygen_mode),.keygen_context(keygen_context),.keygen_destination(keygen_destination),.keygen_exponent(keygen_exponent),.keygen_busy(keygen_busy),.keygen_object(keygen_object),.kg_req_valid(kg_req_valid),.kg_req_ready(kg_req_ready),.kg_req_id(kg_req_id),.kg_req_alg(kg_req_alg),.kg_req_bits(kg_req_bits),.kg_req_mode(kg_req_mode),.kg_req_context(kg_req_context),.kg_req_destination(kg_req_destination),.kg_req_exponent(kg_req_exponent),.kg_cancel_valid(kg_cancel_valid),.kg_cancel_ready(kg_cancel_ready),.kg_cancel_id(kg_cancel_id),.kg_rsp_valid(kg_rsp_valid),.kg_rsp_ready(kg_rsp_ready),.kg_rsp_id(kg_rsp_id),.kg_rsp_fail(kg_rsp_fail),.kg_rsp_code(kg_rsp_code),.kg_rsp_object(kg_rsp_object),.clock(clock),.reset_n(reset_n),.command_ready(command_ready),.command_tag(command_tag),.command_size(command_size),.command_code(command_code),.command_length(command_length),.handle_0(handle_0),.handle_1(handle_1),.handle_2(handle_2),.op_state(op_state),.startup_type(startup_type),.phEnable(phEnable),.phEnableNV(phEnableNV),.shEnable(shEnable),.ehEnable(ehEnable),.shutdownSave(shutdownSave),.command_done(command_done),.session0_handle(session0_handle),.session1_handle(session1_handle),.session2_handle(session2_handle),.session0_attributes(session0_attributes),.session1_attributes(session1_attributes),.session2_attributes(session2_attributes),.session0_hmac_size(session0_hmac_size),.session1_hmac_size(session1_hmac_size),.session2_hmac_size(session2_hmac_size),.session0_valid(session0_valid),.session1_valid(session1_valid),.session2_valid(session2_valid),.authorization_size(authorization_size),.session_loaded(session_loaded),.max_session_amount(max_session_amount),.auth_session(auth_session),.auth_necessary(auth_necessary),.authHandle(authHandle),.pcrSelect(pcrSelect),.auth_done(auth_done),.auth_success(auth_success),.auth_response_code(auth_response_code),.param_decrypt_success(param_decrypt_success),.param_decrypt_fail(param_decrypt_fail),.param_unmarshall_success(param_unmarshall_success),.param_unmarshall_fail(param_unmarshall_fail),.execution_startup_done(execution_startup_done),.execution_response_code(execution_response_code),.nv_phEnableNV_in(nv_phEnableNV_in),.nv_shEnable_in(nv_shEnable_in),.nv_ehEnable_in(nv_ehEnable_in),.tpm_nv_index(tpm_nv_index),.nv_index_attributes(nv_index_attributes),.nv_object_present(nv_object_present),.nv_index_present(nv_index_present),.entity_hierarchy(entity_hierarchy),.mem_orderly(mem_orderly),.ram_available(ram_available),.loaded_object_present(loaded_object_present),.object_attributes(object_attributes),.st_testsRun(st_testsRun),.st_testsPassed(st_testsPassed),.st_untested(st_untested),.response_valid(response_valid),.response_code(response_code),.response_length(response_length),.current_state(current_state),.command_start(command_start),.orderlyInput(orderlyInput),.initialized(initialized),.testsRun(testsRun),.testsPassed(testsPassed),.untested(untested),.nv_phEnableNV(nv_phEnableNV),.nv_shEnable(nv_shEnable),.nv_ehEnable(nv_ehEnable),.authHierarchy(authHierarchy));
always #5 clock=~clock;
integer request_count=0, start_count=0, accept_count=0;
always @(posedge clock) if (!reset_n) begin request_count=0; start_count=0; accept_count=0; end else begin if(command_accept) accept_count=accept_count+1; if(kg_req_valid && kg_req_ready) request_count=request_count+1; if(command_start) start_count=start_count+1; end
task defaults; begin
response_ready=0;
command_cancel=0;
keygen_descriptor_valid=0;
keygen_session_validated=0;
keygen_id=0;
keygen_alg=0;
keygen_bits=0;
keygen_mode=0;
keygen_context=0;
keygen_destination=0;
keygen_exponent=0;
kg_req_ready=0;
kg_cancel_ready=0;
kg_rsp_valid=0;
kg_rsp_id=0;
kg_rsp_fail=0;
kg_rsp_code=0;
kg_rsp_object=0;
reset_n=0;
command_ready=0;
command_tag=0;
command_size=0;
command_code=0;
command_length=0;
handle_0=0;
handle_1=0;
handle_2=0;
op_state=0;
startup_type=0;
phEnable=0;
phEnableNV=0;
shEnable=0;
ehEnable=0;
shutdownSave=0;
command_done=0;
session0_handle=0;
session1_handle=0;
session2_handle=0;
session0_attributes=0;
session1_attributes=0;
session2_attributes=0;
session0_hmac_size=0;
session1_hmac_size=0;
session2_hmac_size=0;
session0_valid=0;
session1_valid=0;
session2_valid=0;
authorization_size=0;
session_loaded=0;
max_session_amount=0;
auth_session=0;
auth_necessary=0;
authHandle=0;
pcrSelect=0;
auth_done=0;
auth_success=0;
auth_response_code=0;
param_decrypt_success=0;
param_decrypt_fail=0;
param_unmarshall_success=0;
param_unmarshall_fail=0;
execution_startup_done=0;
execution_response_code=0;
nv_phEnableNV_in=0;
nv_shEnable_in=0;
nv_ehEnable_in=0;
tpm_nv_index=0;
nv_index_attributes=0;
nv_object_present=0;
nv_index_present=0;
entity_hierarchy=0;
mem_orderly=0;
ram_available=0;
loaded_object_present=0;
object_attributes=0;
st_testsRun=0;
st_testsPassed=0;
st_untested=0;
end endtask

task tick(input integer n); repeat(n) begin @(posedge clock); #1; end endtask
task reset; begin defaults; tick(2); reset_n=1; op_state=3; tick(1); end endtask
task expect_state(input integer s); integer n; begin
 n=0; while(current_state !== s[3:0] && n<40) begin tick(1); n=n+1; end
 if(current_state !== s[3:0]) $fatal(1,"state timeout expected%0d actual%0d",s,current_state);
end endtask
task create(input integer id); begin
 command_code=32'h153; command_tag=16'h8002; command_size=64; command_length=64;
 keygen_descriptor_valid=1; keygen_session_validated=1; keygen_id=id; keygen_alg=1;
 keygen_bits=(id==2) ? 128 : 256; keygen_mode=0; keygen_context=32'h12340000+id;
 keygen_destination=32'h80000000+id; keygen_exponent=0; auth_necessary=1;
 command_ready=1; tick(1);
end endtask
task prerequisites; begin auth_done=1; auth_success=1; param_decrypt_success=1; param_unmarshall_success=1; end endtask
task request; integer n; begin
 n=0; while(kg_req_valid !== 1'b1 && n<40) begin tick(1); n=n+1; end
 if(kg_req_valid !== 1'b1) $fatal(1,"request timeout");
end endtask
task response(input reg [31:0] expected); integer n; begin
 n=0; while(response_valid !== 1'b1 && n<40) begin tick(1); n=n+1; end
 if(response_valid !== 1'b1 || response_code !== expected)
  $fatal(1,"response expected%h actual%h valid%b",expected,response_code,response_valid);
end endtask
task nonzero_response; integer n; begin
 n=0; while(response_valid !== 1'b1 && n<40) begin tick(1); n=n+1; end
 if(response_valid !== 1'b1 || response_code === 0 || (^response_code === 1'bx))
  $fatal(1,"expected definite error, got%h",response_code);
 if(request_count != 0) $fatal(1,"unexpected backend side effect");
end endtask
task mock_result(input reg [31:0] id, input reg fail, input reg [31:0] code, input reg [31:0] object); begin
 kg_rsp_id=id; kg_rsp_fail=fail; kg_rsp_code=code; kg_rsp_object=object; kg_rsp_valid=1;
 tick(1); kg_rsp_valid=0;
end endtask
initial begin #30000; $fatal(1,"global timeout"); end
initial begin
 clock=0; reset;
 create(1); // Header/descriptor snapshot must survive changing caller buses.
 command_code=32'h131; keygen_id=99; keygen_alg=2; keygen_bits=2048;
 keygen_context=0; keygen_destination=0; keygen_descriptor_valid=0;
 expect_state(5); tick(5); if(kg_req_valid || current_state!=5) $fatal(1,"auth not gated");
 auth_done=1; auth_success=1; expect_state(6); tick(5);
 if(kg_req_valid || current_state!=6) $fatal(1,"decrypt not gated");
 param_decrypt_success=1; expect_state(7); tick(5);
 if(kg_req_valid || current_state!=7) $fatal(1,"unmarshal not gated");
 param_unmarshall_success=1; request; tick(4);
 if(kg_req_id!==1 || kg_req_alg!==1 || kg_req_bits!==256 || kg_req_context!==32'h12340001 ||
    kg_req_destination!==32'h80000001 || request_count!=0) $fatal(1,"snapshot/backpressure failed");
 kg_req_ready=1; tick(1); kg_req_ready=0; tick(12);
 if(current_state!=8 || request_count!=1 || accept_count!=1 || !command_busy || response_valid) $fatal(1,"busy abandoned/retriggered");
 mock_result(1,1,32'ha5f00101,32'h99); response(32'ha5f00101);
 kg_rsp_code=0; kg_rsp_fail=0; command_cancel=1; tick(5);
 if(response_code!==32'ha5f00101 || !response_valid || keygen_object!==0) $fatal(1,"response not immutable");
 command_cancel=0; response_ready=1; tick(1); response_ready=0; tick(8);
 if(request_count!=1 || accept_count!=1 || command_busy || response_valid || current_state!=0) $fatal(1,"held enable retrigger");
 $display("PASS snapshot, delayed prerequisites, backpressure, busy, full-width error, held enable/status");

 command_ready=0; tick(1); prerequisites;
 create(2); request;
 if(kg_req_bits!==128) $fatal(1,"AES128 external descriptor gate/snapshot failed");
 kg_req_ready=1; tick(1); kg_req_ready=0;
 mock_result(2,0,0,32'h55); response(0);
 if(keygen_object!==32'h55 || request_count!=2 || accept_count!=2) $fatal(1,"repeated command/mocked object failed");
 tick(3); if(!response_valid || keygen_object!==32'h55) $fatal(1,"mock result not retained");
 $display("PASS second AES128 command without reset and isolated mocked success");

 reset; prerequisites; create(3); request; command_cancel=1; kg_req_ready=1; tick(1);
 command_cancel=0; response(32'h101); if(request_count!=0) $fatal(1,"cancel-edge launch");
 $display("PASS cancel before backend acceptance");

 reset; prerequisites; create(4); request; kg_req_ready=1; tick(1); kg_req_ready=0;
 command_cancel=1; tick(1); command_cancel=0; tick(3);
 if(!kg_cancel_valid || kg_cancel_id!==4) $fatal(1,"cancel pulse lost during backpressure");
 kg_cancel_ready=1; mock_result(4,0,0,32'h66); response(32'h101);
 if(keygen_object!==0) $fatal(1,"cancel/error priority failed");
 $display("PASS pending cancellation and simultaneous completion priority");

 reset; prerequisites; create(5); request; kg_req_ready=1; tick(1); kg_req_ready=0;
 reset_n=0; #1;
 if(kg_req_valid || kg_cancel_valid || kg_rsp_ready || response_valid) $fatal(1,"reset didn't suppress transfers");
 tick(2); reset_n=1; tick(1);
 if(current_state!=0 || keygen_object!==0 || kg_req_context!==0) $fatal(1,"reset didn't clear boundary");
 $display("PASS reset while backend busy (shared backend reset required)");

 reset; create(6); auth_done=1; auth_success=0; nonzero_response;
 $display("PASS authorization failure with zero supplied error fails closed");
 reset; create(7); prerequisites; param_decrypt_fail=1; nonzero_response;
 $display("PASS decrypt failure dominates simultaneous success");
 reset; create(8); prerequisites; param_unmarshall_fail=1; nonzero_response;
 $display("PASS unmarshal failure dominates simultaneous success");
 reset; create(9); prerequisites; command_cancel=1; tick(1); command_cancel=0; nonzero_response;
 $display("PASS cancel during validation blocks backend side effects");

 reset; prerequisites; command_code=32'h131; command_tag=16'h8002; command_size=64; command_length=64;
 keygen_descriptor_valid=1; keygen_session_validated=1; command_ready=1; tick(1);
 response(32'h143); if(request_count!=0) $fatal(1,"primary launch");
 $display("PASS CreatePrimary unsupported (no fresh-child alias)");
 reset; prerequisites; keygen_descriptor_valid=1'bx;
 command_code=32'h153; command_tag=16'h8002; command_size=64; command_length=64;
 keygen_session_validated=1; command_ready=1; tick(1); response(32'h143);
 if(request_count!=0) $fatal(1,"unknown approval launch");
 $display("PASS unknown descriptor approval fails closed");
 reset; prerequisites; command_code=32'h144; command_tag=16'h1234; command_size=12; command_length=12;
 command_ready=1; tick(1); nonzero_response; tick(3); if(initialized) $fatal(1,"malformed startup initialized");
 reset; prerequisites; command_code=32'hffff0144; command_tag=16'h8001; command_size=12; command_length=12;
 command_ready=1; tick(1); nonzero_response; tick(3); if(initialized) $fatal(1,"spoof startup initialized");
 $display("PASS rejected malformed/spoofed Startup never initializes");

 reset; param_decrypt_success=1; param_unmarshall_success=1;
 command_code=32'h17a; command_tag=16'h8001; command_size=22; command_length=22;
 command_ready=1; tick(1); expect_state(8); tick(10);
 if(start_count!=1 || response_valid || current_state!=8) $fatal(1,"legacy delayed execution/one-shot failed");
 execution_response_code=32'hdeadbeef; command_done=1; response(32'hdeadbeef); tick(4);
 if(response_code!==32'hdeadbeef) $fatal(1,"legacy code truncated");
 $display("PASS no-auth/no-session progression, legacy one-shot wait and full-width terminal");

 reset; param_decrypt_success=1; param_unmarshall_success=1;
 command_code=32'h144; command_tag=16'h8001; command_size=12; command_length=12;
 command_ready=1; tick(1); expect_state(8); execution_startup_done=1; command_done=1;
 response(0); tick(1); if(!initialized) $fatal(1,"successful Startup did not initialize");
 $display("PASS only successful completed Startup initializes");

 reset; prerequisites; command_code=32'h126; command_tag=16'h8002; command_size=27; command_length=27;
 phEnable=1; handle_0=32'h4000000c; session0_handle=32'h40000009; session0_valid=1;
 command_ready=1; tick(1); nonzero_response;
 $display("PASS legacy session-tagged path explicitly unsupported (no false success)");
 $display("PASS ALL execution/keygen unit checks; no crypto/backend implementation tested"); $finish;
end
endmodule
