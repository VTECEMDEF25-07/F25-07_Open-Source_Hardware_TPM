// Local hardware-test SHA service. Main RNG/keygen logic is unchanged.
module benchmark_sha(input clock_i,reset_n_i,input [7:0] data_i,input valid_i,last_i,
 output ready_o,output reg [255:0] digest_o,output reg digest_valid_o);
 localparam RECEIVE=0,LOAD=1,ROUND=2,FINISH=3,PUBLISH=4;
 reg [2:0] state_reg; reg [1535:0] message_reg;
 reg [7:0] length_reg;reg [1:0] block_reg,blocks_reg;
 reg [255:0] chain_reg;reg [31:0] schedule_reg[0:15];
 reg [31:0] a_reg,b_reg,c_reg,d_reg,e_reg,f_reg,g_reg,h_reg;reg [5:0] round_reg;
 integer i;
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
 wire [3:0] ix=round_reg[3:0], ix2=ix-4'd2,ix7=ix-4'd7,ix15=ix-4'd15;
 wire [31:0] word_value=round_reg<16?schedule_reg[ix]:small_sigma_1(schedule_reg[ix2])+schedule_reg[ix7]+small_sigma_0(schedule_reg[ix15])+schedule_reg[ix];
 wire [31:0] t1=h_reg+big_sigma_1(e_reg)+((e_reg&f_reg)^(~e_reg&g_reg))+round_constant(round_reg)+word_value;
 wire [31:0] t2=big_sigma_0(a_reg)+((a_reg&b_reg)^(a_reg&c_reg)^(b_reg&c_reg));
 assign ready_o=reset_n_i && state_reg==RECEIVE;
 always @(posedge clock_i or negedge reset_n_i) begin
  if(!reset_n_i) begin
   state_reg<=RECEIVE;message_reg<=0;length_reg<=0;block_reg<=0;blocks_reg<=0;
   chain_reg<=0;digest_o<=0;digest_valid_o<=0;round_reg<=0;
   a_reg<=0;b_reg<=0;c_reg<=0;d_reg<=0;e_reg<=0;f_reg<=0;g_reg<=0;h_reg<=0;
   for(i=0;i<16;i=i+1)schedule_reg[i]<=0;
  end else begin
   digest_valid_o<=0;
   case(state_reg)
    RECEIVE:if(valid_i)begin
     message_reg[1535-length_reg*8 -:8]<=data_i;length_reg<=length_reg+1'b1;
     if(last_i)begin
      message_reg[1535-(length_reg+1)*8 -:8]<=8'h80;
      if(length_reg<55)begin blocks_reg<=1;message_reg[1087:1024]<={53'b0,length_reg+8'd1,3'b0};end
      else if(length_reg<119)begin blocks_reg<=2;message_reg[575:512]<={53'b0,length_reg+8'd1,3'b0};end
      else begin blocks_reg<=3;message_reg[63:0]<={53'b0,length_reg+8'd1,3'b0};end
      chain_reg<=256'h6a09e667bb67ae853c6ef372a54ff53a510e527f9b05688c1f83d9ab5be0cd19;
      block_reg<=0;state_reg<=LOAD;
     end
    end
    LOAD:begin
     for(i=0;i<16;i=i+1)schedule_reg[i]<=message_reg[1535-block_reg*512-i*32 -:32];
     {a_reg,b_reg,c_reg,d_reg,e_reg,f_reg,g_reg,h_reg}<=chain_reg;round_reg<=0;state_reg<=ROUND;
    end
    ROUND:begin
     if(round_reg>=16)schedule_reg[ix]<=word_value;
     h_reg<=g_reg;g_reg<=f_reg;f_reg<=e_reg;e_reg<=d_reg+t1;
     d_reg<=c_reg;c_reg<=b_reg;b_reg<=a_reg;a_reg<=t1+t2;
     if(round_reg==63)state_reg<=FINISH;else round_reg<=round_reg+1'b1;
    end
    FINISH:begin
     chain_reg<={chain_reg[255:224]+a_reg,chain_reg[223:192]+b_reg,chain_reg[191:160]+c_reg,chain_reg[159:128]+d_reg,chain_reg[127:96]+e_reg,chain_reg[95:64]+f_reg,chain_reg[63:32]+g_reg,chain_reg[31:0]+h_reg};
     if(block_reg+1<blocks_reg)begin block_reg<=block_reg+1'b1;state_reg<=LOAD;end
     else state_reg<=PUBLISH;
    end
    PUBLISH:begin digest_o<=chain_reg;digest_valid_o<=1;state_reg<=RECEIVE;message_reg<=0;length_reg<=0;end
    default:state_reg<=RECEIVE;
   endcase
  end
 end
endmodule
