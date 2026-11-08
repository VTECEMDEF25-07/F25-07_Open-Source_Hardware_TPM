// Simulation-only SHA-256 byte-stream service for the RNG regression.
// Author: Aaron Grossman, with Codex assistance (November 2026).
// Behavioral reference: no synthesis, timing, physical entropy or security claim.
// Each accepted last byte completes a message; the digest pulses next cycle.
`timescale 1ns/1ps
module sha256_test_model (
    input wire clk_i, input wire reset_n_i,
    input wire [7:0] data_i, input wire valid_i, input wire last_i,
    output wire ready_o,
    output reg [255:0] digest_reg_o, output reg digest_valid_reg_o
);
    reg [7:0] message_reg [0:2047];
    integer count_reg, cycle_reg;
    reg pending_reg;
    reg [255:0] pending_digest_reg;
    // Deterministic gaps exercise the caller's ready/valid backpressure.
    assign ready_o = reset_n_i && !pending_reg && (cycle_reg % 5 != 0);

    function automatic [31:0] rotate_right;
        input [31:0] value; input integer amount;
        begin rotate_right = (value >> amount) | (value << (32-amount)); end
    endfunction

    task automatic hash_message;
        input integer length;
        output reg [255:0] digest;
        reg [31:0] words [0:63];
        reg [31:0] constants [0:63];
        reg [31:0] h [0:7];
        reg [31:0] a,b,c,d,e,f,g,hh,t1,t2,s0,s1;
        reg [63:0] bit_length;
        integer padded,offset,i,j;
        begin
            constants[0]=32'h428a2f98; constants[1]=32'h71374491;
            constants[2]=32'hb5c0fbcf; constants[3]=32'he9b5dba5;
            constants[4]=32'h3956c25b; constants[5]=32'h59f111f1;
            constants[6]=32'h923f82a4; constants[7]=32'hab1c5ed5;
            constants[8]=32'hd807aa98; constants[9]=32'h12835b01;
            constants[10]=32'h243185be; constants[11]=32'h550c7dc3;
            constants[12]=32'h72be5d74; constants[13]=32'h80deb1fe;
            constants[14]=32'h9bdc06a7; constants[15]=32'hc19bf174;
            constants[16]=32'he49b69c1; constants[17]=32'hefbe4786;
            constants[18]=32'h0fc19dc6; constants[19]=32'h240ca1cc;
            constants[20]=32'h2de92c6f; constants[21]=32'h4a7484aa;
            constants[22]=32'h5cb0a9dc; constants[23]=32'h76f988da;
            constants[24]=32'h983e5152; constants[25]=32'ha831c66d;
            constants[26]=32'hb00327c8; constants[27]=32'hbf597fc7;
            constants[28]=32'hc6e00bf3; constants[29]=32'hd5a79147;
            constants[30]=32'h06ca6351; constants[31]=32'h14292967;
            constants[32]=32'h27b70a85; constants[33]=32'h2e1b2138;
            constants[34]=32'h4d2c6dfc; constants[35]=32'h53380d13;
            constants[36]=32'h650a7354; constants[37]=32'h766a0abb;
            constants[38]=32'h81c2c92e; constants[39]=32'h92722c85;
            constants[40]=32'ha2bfe8a1; constants[41]=32'ha81a664b;
            constants[42]=32'hc24b8b70; constants[43]=32'hc76c51a3;
            constants[44]=32'hd192e819; constants[45]=32'hd6990624;
            constants[46]=32'hf40e3585; constants[47]=32'h106aa070;
            constants[48]=32'h19a4c116; constants[49]=32'h1e376c08;
            constants[50]=32'h2748774c; constants[51]=32'h34b0bcb5;
            constants[52]=32'h391c0cb3; constants[53]=32'h4ed8aa4a;
            constants[54]=32'h5b9cca4f; constants[55]=32'h682e6ff3;
            constants[56]=32'h748f82ee; constants[57]=32'h78a5636f;
            constants[58]=32'h84c87814; constants[59]=32'h8cc70208;
            constants[60]=32'h90befffa; constants[61]=32'ha4506ceb;
            constants[62]=32'hbef9a3f7; constants[63]=32'hc67178f2;
            h[0]=32'h6a09e667; h[1]=32'hbb67ae85;
            h[2]=32'h3c6ef372; h[3]=32'ha54ff53a;
            h[4]=32'h510e527f; h[5]=32'h9b05688c;
            h[6]=32'h1f83d9ab; h[7]=32'h5be0cd19;
            padded=((length+9+63)/64)*64;
            if(padded>2048)$fatal(1,"SHA model message too long");
            message_reg[length]=8'h80;
            for(i=length+1;i<padded;i=i+1)message_reg[i]=0;
            bit_length=length*64'd8;
            for(i=0;i<8;i=i+1)message_reg[padded-1-i]=bit_length[i*8+:8];
            for(offset=0;offset<padded;offset=offset+64)begin
                for(i=0;i<16;i=i+1)begin
                    j=offset+4*i;
                    words[i]={message_reg[j],message_reg[j+1],message_reg[j+2],message_reg[j+3]};
                end
                for(i=16;i<64;i=i+1)begin
                    s0=rotate_right(words[i-15],7)^rotate_right(words[i-15],18)^(words[i-15]>>3);
                    s1=rotate_right(words[i-2],17)^rotate_right(words[i-2],19)^(words[i-2]>>10);
                    words[i]=words[i-16]+s0+words[i-7]+s1;
                end
                a=h[0];b=h[1];c=h[2];d=h[3];e=h[4];f=h[5];g=h[6];hh=h[7];
                for(i=0;i<64;i=i+1)begin
                    s1=rotate_right(e,6)^rotate_right(e,11)^rotate_right(e,25);
                    t1=hh+s1+((e&f)^((~e)&g))+constants[i]+words[i];
                    s0=rotate_right(a,2)^rotate_right(a,13)^rotate_right(a,22);
                    t2=s0+((a&b)^(a&c)^(b&c));
                    hh=g;g=f;f=e;e=d+t1;d=c;c=b;b=a;a=t1+t2;
                end
                h[0]=h[0]+a;h[1]=h[1]+b;h[2]=h[2]+c;h[3]=h[3]+d;
                h[4]=h[4]+e;h[5]=h[5]+f;h[6]=h[6]+g;h[7]=h[7]+hh;
            end
            digest={h[0],h[1],h[2],h[3],h[4],h[5],h[6],h[7]};
        end
    endtask

    always @(posedge clk_i or negedge reset_n_i)begin
        if(!reset_n_i)begin
            count_reg<=0;cycle_reg<=0;pending_reg<=0;
            digest_reg_o<=0;digest_valid_reg_o<=0;pending_digest_reg<=0;
        end else begin
            cycle_reg<=(cycle_reg+1)%35;
            digest_valid_reg_o<=pending_reg;
            if(pending_reg)begin digest_reg_o<=pending_digest_reg;pending_reg<=0;end
            if(valid_i&&ready_o)begin
                if(count_reg>=2040)$fatal(1,"SHA model input overflow");
                message_reg[count_reg]=data_i;
                if(last_i)begin
                    hash_message(count_reg+1,pending_digest_reg);
                    count_reg<=0;pending_reg<=1;
                end else count_reg<=count_reg+1;
            end
        end
    end
endmodule
