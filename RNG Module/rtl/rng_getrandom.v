`timescale 1ns/1ps
// TPM2_GetRandom frontend adapted from Jungyeon's command framing.
// Collect -> close/erase provider -> transmit; a stalled host does not own RNG.
// AI-assisted integration, October 23 2026.
module rng_getrandom (
 input wire clock_i,reset_n_i,tpm_initialized_i,
 input wire [7:0] cmd_data_i,input wire cmd_valid_i,cmd_last_i,output wire cmd_ready_o,
 output reg [7:0] rsp_data_o,output wire rsp_valid_o,rsp_last_o,input wire rsp_ready_i,
 output wire open_valid_o,input wire open_ready_i,input wire open_rsp_valid_i,
 output wire open_rsp_ready_o,input wire [3:0] open_status_i,
 input wire word_valid_i,output wire word_ready_o,input wire [31:0] word_data_i,input wire context_fault_i,
 output wire close_valid_o,input wire close_ready_i,input wire close_rsp_valid_i,
 output wire close_rsp_ready_o,input wire close_fault_i,
 output wire busy_o
);
 localparam RECEIVE=0,CHECK=1,OPEN=2,OPEN_WAIT=3,COLLECT=4,CLOSE=5,CLOSE_WAIT=6,SEND=7;
 reg [2:0] state_reg;
 reg [7:0] command_reg[0:11];
 reg [31:0] received_reg,code_reg;
 reg [5:0] bytes_reg,tx_reg;
 reg [3:0] words_reg;
 reg [255:0] payload_reg;
 reg [31:0] check_code;
 wire [15:0] requested={command_reg[10],command_reg[11]};
 wire [5:0] count=requested>32 ? 6'd32 : requested[5:0];
 wire [31:0] response_size=code_reg==0 ? 32'd12+{26'b0,bytes_reg} : 32'd10;
 integer i;
 assign busy_o=state_reg!=RECEIVE || received_reg!=0;
 assign cmd_ready_o=reset_n_i && state_reg==RECEIVE;
 assign rsp_valid_o=reset_n_i && state_reg==SEND;
 assign rsp_last_o=rsp_valid_o && {26'b0,tx_reg}==response_size-1;
 assign open_valid_o=reset_n_i && state_reg==OPEN;
 assign open_rsp_ready_o=reset_n_i && state_reg==OPEN_WAIT;
 assign word_ready_o=reset_n_i && state_reg==COLLECT && !context_fault_i;
 assign close_valid_o=reset_n_i && state_reg==CLOSE;
 assign close_rsp_ready_o=reset_n_i && state_reg==CLOSE_WAIT;
 always @* begin
  check_code=0;
  if(received_reg<10) check_code=32'h09a;
  else if({command_reg[0],command_reg[1]}!=16'h8001) check_code=32'h01e;
  else if({command_reg[2],command_reg[3],command_reg[4],command_reg[5]}!=received_reg) check_code=32'h142;
  else if({command_reg[6],command_reg[7],command_reg[8],command_reg[9]}!=32'h17b) check_code=32'h143;
  else if(!tpm_initialized_i) check_code=32'h100;
  else if(received_reg<12) check_code=32'h1da;
  else if(received_reg>12) check_code=32'h095;
 end
 always @* begin
  rsp_data_o=0;
  if(rsp_valid_o) case(tx_reg)
   0:rsp_data_o=8'h80;1:rsp_data_o=8'h01;
   2:rsp_data_o=response_size[31:24];3:rsp_data_o=response_size[23:16];
   4:rsp_data_o=response_size[15:8];5:rsp_data_o=response_size[7:0];
   6:rsp_data_o=code_reg[31:24];7:rsp_data_o=code_reg[23:16];8:rsp_data_o=code_reg[15:8];9:rsp_data_o=code_reg[7:0];
   10:rsp_data_o=0;11:rsp_data_o={2'b0,bytes_reg};
   default:rsp_data_o=payload_reg[255-({26'b0,tx_reg}-32'd12)*32'd8 -:8];
  endcase
 end
 always @(posedge clock_i or negedge reset_n_i) begin
  if(!reset_n_i) begin
   state_reg<=RECEIVE;received_reg<=0;code_reg<=0;bytes_reg<=0;tx_reg<=0;words_reg<=0;payload_reg<=0;
   for(i=0;i<12;i=i+1) command_reg[i]<=0;
  end else case(state_reg)
   RECEIVE: if(cmd_valid_i) begin
    if(received_reg<12) command_reg[received_reg[3:0]]<=cmd_data_i;
    if(received_reg!=32'hffffffff) received_reg<=received_reg+1'b1;
    if(cmd_last_i) state_reg<=CHECK;
   end
   CHECK: begin
    code_reg<=check_code;bytes_reg<=count;tx_reg<=0;words_reg<=0;payload_reg<=0;
    state_reg<=(check_code!=0 || count==0) ? SEND : OPEN;
   end
   OPEN: if(open_ready_i) state_reg<=OPEN_WAIT;
   OPEN_WAIT: if(open_rsp_valid_i) begin
    if(open_status_i!=0) begin code_reg<=32'h101;bytes_reg<=0;state_reg<=SEND;end
    else state_reg<=COLLECT;
   end
   COLLECT: begin
    if(context_fault_i) begin code_reg<=32'h101;bytes_reg<=0;payload_reg<=0;state_reg<=CLOSE;end
    else if(word_valid_i) begin
     payload_reg[255-words_reg*32 -:32]<=word_data_i;words_reg<=words_reg+1'b1;
     if(({28'b0,words_reg}+32'd1)*32'd4>={26'b0,bytes_reg}) state_reg<=CLOSE;
    end
   end
   CLOSE: begin
    if(context_fault_i) begin code_reg<=32'h101;bytes_reg<=0;payload_reg<=0;end
    if(close_ready_i) state_reg<=CLOSE_WAIT;
   end
   CLOSE_WAIT: if(close_rsp_valid_i) begin
    if(close_fault_i || context_fault_i) begin code_reg<=32'h101;bytes_reg<=0;payload_reg<=0;end
    state_reg<=SEND;
   end
   SEND: if(rsp_ready_i) begin
    if(rsp_last_o) begin
     payload_reg<=0;received_reg<=0;bytes_reg<=0;words_reg<=0;tx_reg<=0;code_reg<=0;
     for(i=0;i<12;i=i+1) command_reg[i]<=0;
     state_reg<=RECEIVE;
    end else tx_reg<=tx_reg+1'b1;
   end
   default: state_reg<=RECEIVE;
  endcase
 end
endmodule
