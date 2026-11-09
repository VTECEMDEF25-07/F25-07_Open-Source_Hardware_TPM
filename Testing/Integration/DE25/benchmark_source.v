// Local benchmark adapter: mode 0 public fixture; mode 1 real ring/Hash_DRBG.
module benchmark_source(input clock_i,reset_n_i,start_valid_i,input mode_i,
 output start_ready_o,input [255:0] seed_i,output word_valid_o,input word_ready_i,
 output [31:0] data_o,output failed_o,output reg [31:0] words_o,blocks_o,
 output reg [31:0] generate_cycles_o,setup_cycles_o,output [31:0] entropy_blocks_o);
 wire test_ready,test_valid,test_failed;wire [31:0] test_data;
 keygen_test_source fixture(.clock_i(clock_i),.reset_n_i(reset_n_i),.start_valid_i(start_valid_i&&!mode_i),.start_ready_o(test_ready),.seed_i(seed_i),.word_valid_o(test_valid),.word_ready_i(word_ready_i&&!mode_i),.data_o(test_data),.failed_o(test_failed));
 wire [255:0] entropy,random_data,digest;wire entropy_valid,random_valid,instantiated,needed;
 wire [7:0] msg;wire msg_valid,msg_last,msg_ready,digest_valid;
 reg [255:0] buffer_reg;reg [3:0] remaining_reg;reg request_reg,active_reg;reg [31:0] entropy_count_reg;
 assign entropy_blocks_o=entropy_count_reg;
 entropy_source raw(.clk(clock_i),.rst_n(reset_n_i),.enable(mode_i),.entropy_output(entropy),.entropy_valid(entropy_valid),.raw_sample(),.raw_sample_valid());
 random_number_generation drbg(.clk(clock_i),.rst_n(reset_n_i),.entropy_input(entropy),.entropy_valid(entropy_valid),.entropy_needed(needed),.gen_req(request_reg),.random_output(random_data),.random_valid(random_valid),.instantiated(instantiated),.hash_msg_data(msg),.hash_msg_valid(msg_valid),.hash_msg_last(msg_last),.hash_msg_ready(msg_ready),.hash_digest(digest),.hash_digest_valid(digest_valid));
 benchmark_sha hash(.clock_i(clock_i),.reset_n_i(reset_n_i),.data_i(msg),.valid_i(msg_valid),.last_i(msg_last),.ready_o(msg_ready),.digest_o(digest),.digest_valid_o(digest_valid));
 assign start_ready_o=mode_i?instantiated:test_ready;
 assign word_valid_o=mode_i?(remaining_reg!=0):test_valid;
 assign data_o=mode_i?buffer_reg[255:224]:test_data;
 assign failed_o=mode_i?1'b0:test_failed;
 always @(posedge clock_i or negedge reset_n_i)begin
  if(!reset_n_i)begin buffer_reg<=0;remaining_reg<=0;request_reg<=0;active_reg<=0;words_o<=0;blocks_o<=0;generate_cycles_o<=0;setup_cycles_o<=0;entropy_count_reg<=0;end
  else begin
   if(mode_i&&!instantiated)setup_cycles_o<=setup_cycles_o+1'b1;
   if(entropy_valid)entropy_count_reg<=entropy_count_reg+1'b1;
   if(start_valid_i&&start_ready_o)active_reg<=1;
   if(mode_i&&active_reg&&remaining_reg==0&&instantiated&&!request_reg)request_reg<=1;
   if(request_reg)generate_cycles_o<=generate_cycles_o+1'b1;
   if(random_valid&&request_reg)begin buffer_reg<=random_data;remaining_reg<=8;request_reg<=0;blocks_o<=blocks_o+1'b1;end
   else if(word_valid_o&&word_ready_i)begin
    words_o<=words_o+1'b1;
    if(mode_i)begin buffer_reg<={buffer_reg[223:0],32'b0};remaining_reg<=remaining_reg-1'b1;end
   end
  end
 end
endmodule
