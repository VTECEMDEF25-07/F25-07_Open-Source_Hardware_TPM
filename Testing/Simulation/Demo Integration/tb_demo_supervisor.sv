`timescale 1ns/1ps
module tb_demo_supervisor;
reg clk=0,rst=0,active=0,recovery=0,abort=0,job=0,commit=0;
reg[31:0] id=0,h=0;wire crst,pending,recovered,committed;
wire[31:0]last_id,last_handle;wire[3:0]reason;
always #10 clk=~clk;
demo_recovery_supervisor #(.DEADLINE_CYCLES(4)) dut(
 .clock_i(clk),.reset_n_i(rst),.active_i(active),.recovery_request_i(recovery),
 .transport_abort_i(abort),.job_accept_i(job),.job_id_i(id),.commit_i(commit),
 .commit_handle_i(h),.crypto_reset_n_o(crst),.recovery_pending_o(pending),
 .recovered_o(recovered),.last_id_o(last_id),.last_handle_o(last_handle),
 .last_committed_o(committed),.last_reason_o(reason));
task tick;@(posedge clk);#1;endtask
initial begin
 #1;rst=1;#1;rst=0;#1;rst=1;wait(crst);@(negedge clk);
 id=1;job=1;tick();@(negedge clk);job=0;abort=1;#1;
 if(!pending)$fatal(1,"Abort not visible before acceptance edge");tick();
 if(!recovered || last_id!=1 || reason!=1)$fatal(1,"Recovery snapshot");
 @(negedge clk);abort=0;wait(crst);@(negedge clk);
 id=2;job=1;tick();if(recovered || reason!=0)$fatal(1,"Old recovery attributed to new job");
 @(negedge clk);job=0;tick();@(negedge clk);
 id=3;job=1;abort=1;tick();
 if(!recovered || last_id!=3 || reason!=1)$fatal(1,"Admission overwrote coincident recovery");
 @(negedge clk);job=0;abort=0;wait(crst);@(negedge clk);
 id=4;job=1;tick();@(negedge clk);job=0;commit=1;h=32'h80000001;recovery=1;tick();
 if(!recovered || !committed || last_handle!=h || last_id!=4 || reason!=3)
  $fatal(1,"Held commit must be observed even on recovery");
 @(negedge clk);commit=0;recovery=0;wait(crst);@(negedge clk);
 id=5;job=1;active=1;tick();@(negedge clk);job=0;
 repeat(4)tick();if(!recovered || reason!=2 || last_id!=5 || committed)$fatal(1,"Deadline metadata");
 $display("PASS DEMO SUPERVISOR PRIORITY 5 cases");$finish;
end
initial begin #10000;$fatal(1,"Supervisor test deadline");end
endmodule
