`timescale 1ns/1ps
// Asynchronous assertion, two-clock synchronous release in the consumer domain.
module rng_reset_sync(input wire clock_i,reset_n_i,output wire reset_n_o);
 reg [1:0] release_reg;
 always @(posedge clock_i or negedge reset_n_i) begin
  if(!reset_n_i) release_reg<=0;
  else release_reg<={release_reg[0],1'b1};
 end
 assign reset_n_o=reset_n_i && release_reg[1];
endmodule
