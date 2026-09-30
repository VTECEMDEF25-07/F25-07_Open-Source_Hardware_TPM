`timescale 1ns/1ps
// AI-authored self-checking regression; only synthetic test words, no waveform logging.
module tb_aes_key_assembler;
reg clock=0;always #5 clock=~clock;
reg reset_n=0,work_valid=0,work_cancel=0,rng_valid=0,rng_error=0,out_ready=0,done_ready=0;
reg[31:0]work_id=11,work_public_exponent=0,rng_data=0;reg[11:0]work_key_bits=128;
wire work_ready,busy,rng_ready,out_valid,out_last,done_valid;wire[31:0]out_id,out_word,done_id;wire[3:0]out_component;wire[6:0]out_index;wire[11:0]out_bits;wire[7:0]done_status;
aes_key_assembler dut(.*);
reg[31:0] frozen_word;integer j,n;
task tick;begin @(posedge clock);#1;end endtask
task clearcheck;begin if(dut.key_material!==256'd0||out_word!==0||out_valid||rng_ready)$fatal(1,"secret clear/valid invariant failed");end endtask
task reset;begin reset_n=0;work_valid=0;work_cancel=0;rng_valid=0;rng_error=0;out_ready=0;done_ready=0;work_id=11;work_key_bits=128;work_public_exponent=0;tick;reset_n=1;tick;end endtask
task launch(input integer bits);begin work_key_bits=bits;work_valid=1;#1;if(!work_ready)$fatal(1,"work not ready");tick;if(!rng_ready)$fatal(1,"collect not entered");end endtask
task collect(input integer count);integer k;begin for(k=0;k<count;k=k+1)begin if(!rng_ready)$fatal(1,"RNG readiness/count");rng_valid=1;rng_data=32'h0abc0000+k;tick;rng_valid=0;if(k<count-1)begin tick;if(out_valid||done_valid)$fatal(1,"premature output");end end end endtask
task result(input integer count,input integer bits);integer k;begin if(!out_valid||done_valid)$fatal(1,"missing complete output");for(k=0;k<count;k=k+1)begin frozen_word=out_word;repeat(3)begin tick;if(out_word!==frozen_word||out_index!==k||out_bits!==bits||out_id!==11||out_component!==1||out_last!==(k==count-1))$fatal(1,"stalled output/metadata unstable");end if(out_word!==(32'h0abc0000+k))$fatal(1,"word order incorrect");out_ready=1;tick;out_ready=0;end if(!done_valid||done_status!==0)$fatal(1,"success not published");clearcheck;repeat(3)begin rng_error=1;work_cancel=1;tick;if(!done_valid||done_status!==0)$fatal(1,"published terminal changed");end rng_error=0;work_cancel=0;done_ready=1;tick;done_ready=0;repeat(3)begin tick;if(work_ready||rng_ready||out_valid||done_valid)$fatal(1,"held work retrigger");end work_valid=0;tick;end endtask
initial begin
reset;launch(128);collect(4);if(dut.key_material[255:128]!==0)$fatal(1,"AES128 upperhalf not clear");result(4,128);launch(256);collect(8);result(8,256);launch(128);collect(4);result(4,128);$display("PASS AES128/256/128 counts/order/gaps/stalls/rearm/terminal clearing");
reset;launch(128);collect(3);rng_valid=1;rng_error=1;rng_data=32'hffffffff;#1;if(rng_ready||out_valid||out_word!==0)$fatal(1,"last RNG fault transfer");tick;if(done_status!==2||!done_valid)$fatal(1,"last RNG fault status");clearcheck;$display("PASS RNG failure at final input clears without output");
reset;launch(256);collect(8);out_ready=1;tick;tick;out_ready=0;work_cancel=1;#1;if(out_valid||out_word!==0)$fatal(1,"cancel exposes stalled output");tick;if(done_status!==3||!done_valid)$fatal(1,"partial-output cancel status");clearcheck;$display("PASS partial-output cancel clears local remaining material");
reset;launch(128);collect(4);out_ready=1;tick;tick;tick;rng_error=1;#1;if(out_valid)$fatal(1,"final output fault accepted");tick;if(done_status!==2)$fatal(1,"final output fault lost");clearcheck;$display("PASS RNG failure dominates final output acceptance");
reset;launch(128);rng_data=32'hxxxxxxxx;rng_valid=1;tick;if(done_status!==2||!done_valid)$fatal(1,"unknown RNG data accepted");clearcheck;$display("PASS unknown RNG data fails closed");
reset;work_key_bits=12'd192;work_valid=1;tick;if(done_status!==1||rng_ready||out_valid)$fatal(1,"unsupported size accepted");clearcheck;
reset;work_key_bits=128;work_public_exponent=32'd65537;work_valid=1;tick;if(done_status!==4||rng_ready)$fatal(1,"nonzero exponent accepted");clearcheck;
reset;work_key_bits=128;work_id=32'hxxxxxxxx;work_valid=1;tick;if(done_status!==4||done_id!==0)$fatal(1,"unknown request id accepted");clearcheck;$display("PASS unsupported/bad metadata rejected without secret output");
reset;launch(256);collect(2);reset_n=0;#1;clearcheck;tick;reset_n=1;repeat(3)tick;if(work_ready||rng_ready||out_valid||done_valid)$fatal(1,"reset held-valid replay");work_valid=0;tick;if(!work_ready)$fatal(1,"reset recovery didn't rearm");$display("PASS partial collection reset clears and prevents held-valid replay");
// Captured request survives mutation of the input bus while busy.
reset;launch(128);work_id=99;work_key_bits=256;work_public_exponent=65537;
collect(4);result(4,128);
// Identical numerical words are legal RNG stream beats.
reset;launch(128);rng_valid=1;rng_data=32'h12121212;
repeat(4)tick;rng_valid=0;
for(j=0;j<4;j=j+1)begin
 if(out_word!==32'h12121212 || out_index!==j)$fatal(1,"equal-valued words mishandled");
 out_ready=1;tick;out_ready=0;
end
if(!done_valid||done_status!==0)$fatal(1,"equal-word completion");clearcheck;
// Cancel, RNG fault, and reset in empty/partial collection and stalled/partial output.
for(n=0;n<4;n=n+1)begin
 reset;launch(128);
 if(n==1)collect(2);
 if(n>=2)collect(4);
 if(n==3)begin out_ready=1;tick;out_ready=0;end
 work_cancel=1;#1;if(out_valid||out_word!==0||rng_ready)$fatal(1,"cancel transfer visible");tick;
 if(!done_valid||done_status!==3)$fatal(1,"phase cancellation failed");clearcheck;
 reset;launch(128);
 if(n==1)collect(2);
 if(n>=2)collect(4);
 if(n==3)begin out_ready=1;tick;out_ready=0;end
 rng_error=1;#1;if(out_valid||out_word!==0||rng_ready)$fatal(1,"fault transfer visible");tick;
 if(!done_valid||done_status!==2)$fatal(1,"phase RNG failure failed");clearcheck;
 reset;launch(128);
 if(n==1)collect(2);
 if(n>=2)collect(4);
 if(n==3)begin out_ready=1;tick;out_ready=0;end
 reset_n=0;#1;clearcheck;tick;reset_n=1;repeat(2)tick;
 if(busy||done_valid||rng_ready||work_ready)$fatal(1,"reset replayed held request");
end
reset;work_key_bits=12'hxxx;work_valid=1;tick;
if(!done_valid||done_status!==1)$fatal(1,"unknown size accepted");clearcheck;
reset;work_public_exponent=32'hxxxxxxxx;work_valid=1;tick;
if(!done_valid||done_status!==4)$fatal(1,"unknown exponent accepted");clearcheck;
reset;rng_error=1;work_valid=1;tick;
if(!done_valid||done_status!==2)$fatal(1,"preexisting RNG failure accepted");clearcheck;
reset;launch(128);collect(4);out_ready=1;repeat(4)tick;out_ready=0;
reset_n=0;#1;clearcheck;tick;reset_n=1;repeat(2)tick;
if(done_valid||work_ready||busy)$fatal(1,"terminal reset replay");
$display("PASS AES request latching/equal words/all-phase abort/reset/invalid metadata");
$display("PASS ALL AES assembly regression (no cipher/RNG security tested)");$finish;
end
initial begin #20000;$fatal(1,"global timeout");end
endmodule
