`timescale 1ns/1ps
// AI-assisted integration, October 23 2026. Portable Verilog-2001.
// SHA-256 for byte strings up to 111 bytes, left aligned. One transaction at a time.
// All working state is explicitly erased by clear_i and reset.
module rng_sha256 (
 input wire clock_i, reset_n_i, clear_i,
 input wire request_valid_i, output wire request_ready_o,
 input wire [887:0] message_i, input wire [6:0] length_i,
 output wire response_valid_o, input wire response_ready_i,
 output wire [255:0] digest_o
);
 localparam IDLE=0, LOAD=1, ROUND=2, FINISH=3, DONE=4;
 localparam [255:0] INITIAL=256'h6a09e667bb67ae853c6ef372a54ff53a510e527f9b05688c1f83d9ab5be0cd19;
 reg [2:0] state_reg;
 reg [1023:0] message_reg;
 reg second_reg, two_blocks_reg;
 reg [255:0] chain_reg;
 reg [31:0] a_reg,b_reg,c_reg,d_reg,e_reg,f_reg,g_reg,h_reg;
 reg [31:0] schedule_reg[0:15];
 reg [5:0] round_reg;
 reg [1023:0] padded;
 integer i,j;
 always @* begin
   padded=0;
   for(j=0;j<111;j=j+1) if(j<length_i) padded[1023-j*8 -:8]=message_i[887-j*8 -:8];
   if(length_i<=111) padded[1023-length_i*8 -:8]=8'h80;
   if(length_i<56) padded[575:512]={54'b0,length_i,3'b0};
   else padded[63:0]={54'b0,length_i,3'b0};
 end
    function [31:0] rotate_right;
        input [31:0] value_i;
        input integer amount_i;
        begin rotate_right = (value_i >> amount_i) | (value_i << (32-amount_i)); end
    endfunction
    function [31:0] small_sigma_0;
        input [31:0] value_i;
        begin small_sigma_0 = rotate_right(value_i,7) ^ rotate_right(value_i,18) ^ (value_i >> 3); end
    endfunction
    function [31:0] small_sigma_1;
        input [31:0] value_i;
        begin small_sigma_1 = rotate_right(value_i,17) ^ rotate_right(value_i,19) ^ (value_i >> 10); end
    endfunction
    function [31:0] big_sigma_0;
        input [31:0] value_i;
        begin big_sigma_0 = rotate_right(value_i,2) ^ rotate_right(value_i,13) ^ rotate_right(value_i,22); end
    endfunction
    function [31:0] big_sigma_1;
        input [31:0] value_i;
        begin big_sigma_1 = rotate_right(value_i,6) ^ rotate_right(value_i,11) ^ rotate_right(value_i,25); end
    endfunction
    function [31:0] round_constant;
        input [5:0] index_i;
        begin
            case (index_i)
                0: round_constant=32'h428a2f98; 1: round_constant=32'h71374491;
                2: round_constant=32'hb5c0fbcf; 3: round_constant=32'he9b5dba5;
                4: round_constant=32'h3956c25b; 5: round_constant=32'h59f111f1;
                6: round_constant=32'h923f82a4; 7: round_constant=32'hab1c5ed5;
                8: round_constant=32'hd807aa98; 9: round_constant=32'h12835b01;
                10: round_constant=32'h243185be; 11: round_constant=32'h550c7dc3;
                12: round_constant=32'h72be5d74; 13: round_constant=32'h80deb1fe;
                14: round_constant=32'h9bdc06a7; 15: round_constant=32'hc19bf174;
                16: round_constant=32'he49b69c1; 17: round_constant=32'hefbe4786;
                18: round_constant=32'h0fc19dc6; 19: round_constant=32'h240ca1cc;
                20: round_constant=32'h2de92c6f; 21: round_constant=32'h4a7484aa;
                22: round_constant=32'h5cb0a9dc; 23: round_constant=32'h76f988da;
                24: round_constant=32'h983e5152; 25: round_constant=32'ha831c66d;
                26: round_constant=32'hb00327c8; 27: round_constant=32'hbf597fc7;
                28: round_constant=32'hc6e00bf3; 29: round_constant=32'hd5a79147;
                30: round_constant=32'h06ca6351; 31: round_constant=32'h14292967;
                32: round_constant=32'h27b70a85; 33: round_constant=32'h2e1b2138;
                34: round_constant=32'h4d2c6dfc; 35: round_constant=32'h53380d13;
                36: round_constant=32'h650a7354; 37: round_constant=32'h766a0abb;
                38: round_constant=32'h81c2c92e; 39: round_constant=32'h92722c85;
                40: round_constant=32'ha2bfe8a1; 41: round_constant=32'ha81a664b;
                42: round_constant=32'hc24b8b70; 43: round_constant=32'hc76c51a3;
                44: round_constant=32'hd192e819; 45: round_constant=32'hd6990624;
                46: round_constant=32'hf40e3585; 47: round_constant=32'h106aa070;
                48: round_constant=32'h19a4c116; 49: round_constant=32'h1e376c08;
                50: round_constant=32'h2748774c; 51: round_constant=32'h34b0bcb5;
                52: round_constant=32'h391c0cb3; 53: round_constant=32'h4ed8aa4a;
                54: round_constant=32'h5b9cca4f; 55: round_constant=32'h682e6ff3;
                56: round_constant=32'h748f82ee; 57: round_constant=32'h78a5636f;
                58: round_constant=32'h84c87814; 59: round_constant=32'h8cc70208;
                60: round_constant=32'h90befffa; 61: round_constant=32'ha4506ceb;
                62: round_constant=32'hbef9a3f7; 63: round_constant=32'hc67178f2;
                default: round_constant=32'b0;
            endcase
        end
    endfunction


 wire [3:0] index=round_reg[3:0], index2=index-4'd2, index7=index-4'd7, index15=index-4'd15;
 wire [31:0] word_value=round_reg<16 ? schedule_reg[index] : small_sigma_1(schedule_reg[index2])+schedule_reg[index7]+small_sigma_0(schedule_reg[index15])+schedule_reg[index];
 wire [31:0] t1=h_reg+big_sigma_1(e_reg)+((e_reg&f_reg)^(~e_reg&g_reg))+round_constant(round_reg)+word_value;
 wire [31:0] t2=big_sigma_0(a_reg)+((a_reg&b_reg)^(a_reg&c_reg)^(b_reg&c_reg));
 assign request_ready_o=reset_n_i && !clear_i && state_reg==IDLE && length_i<=111;
 assign response_valid_o=reset_n_i && !clear_i && state_reg==DONE;
 assign digest_o=response_valid_o ? chain_reg : 256'b0;
 always @(posedge clock_i or negedge reset_n_i) begin
  if(!reset_n_i) begin
   state_reg<=IDLE;message_reg<=0;second_reg<=0;two_blocks_reg<=0;chain_reg<=0;round_reg<=0;
   a_reg<=0;b_reg<=0;c_reg<=0;d_reg<=0;e_reg<=0;f_reg<=0;g_reg<=0;h_reg<=0;
   for(i=0;i<16;i=i+1) schedule_reg[i]<=0;
  end else if(clear_i || (response_valid_o && response_ready_i)) begin
   state_reg<=IDLE;message_reg<=0;second_reg<=0;two_blocks_reg<=0;chain_reg<=0;round_reg<=0;
   a_reg<=0;b_reg<=0;c_reg<=0;d_reg<=0;e_reg<=0;f_reg<=0;g_reg<=0;h_reg<=0;
   for(i=0;i<16;i=i+1) schedule_reg[i]<=0;
  end else case(state_reg)
   IDLE: if(request_valid_i && request_ready_o) begin
    message_reg<=padded;chain_reg<=INITIAL;two_blocks_reg<=length_i>=56;second_reg<=0;state_reg<=LOAD;
   end
   LOAD: begin
    for(i=0;i<16;i=i+1) schedule_reg[i]<=message_reg[1023-i*32 -:32];
    {a_reg,b_reg,c_reg,d_reg,e_reg,f_reg,g_reg,h_reg}<=chain_reg;
    round_reg<=0;state_reg<=ROUND;
   end
   ROUND: begin
    if(round_reg>=16) schedule_reg[index]<=word_value;
    h_reg<=g_reg;g_reg<=f_reg;f_reg<=e_reg;e_reg<=d_reg+t1;
    d_reg<=c_reg;c_reg<=b_reg;b_reg<=a_reg;a_reg<=t1+t2;
    if(round_reg==63) state_reg<=FINISH;else round_reg<=round_reg+1'b1;
   end
   FINISH: begin
    chain_reg<={chain_reg[255:224]+a_reg,chain_reg[223:192]+b_reg,chain_reg[191:160]+c_reg,chain_reg[159:128]+d_reg,chain_reg[127:96]+e_reg,chain_reg[95:64]+f_reg,chain_reg[63:32]+g_reg,chain_reg[31:0]+h_reg};
    if(two_blocks_reg && !second_reg) begin message_reg<={message_reg[511:0],512'b0};second_reg<=1;state_reg<=LOAD;end
    else state_reg<=DONE;
   end
   DONE: begin end
   default: state_reg<=IDLE;
  endcase
 end
endmodule
