// Demo generation facade, frozen v0.1. Authors: Aaron Grossman; Codex assistance.
// Mode 1 is a PUBLIC deterministic fixture. Mode 0 is UNQUALIFIED physical entropy.
// No entropy-health/certification claim, host seed, or automatic mode fallback.
module demo_generation_service #(
    parameter integer DEMO_PROVIDER_MODE=1,
    parameter integer SEED_BLOCKS=3, RESEED_BLOCKS=2,
    parameter [47:0] RESEED_INTERVAL=48'd1024
) (
    input wire clock_i, reset_n_i,
    input wire open_valid_i, output wire open_ready_o,
    input wire [1:0] open_profile_i, input wire [31:0] open_id_i,
    input wire [1:0] open_mode_i,
    output wire open_rsp_valid_o, input wire open_rsp_ready_i,
    output reg [3:0] open_rsp_error_o,
    output wire word_valid_o, input wire word_ready_i, output wire [31:0] word_data_o,
    output wire context_fault_o, output reg [3:0] context_fault_code_o,
    input wire close_valid_i, output wire close_ready_o,
    input wire [31:0] close_id_i, input wire close_failed_i,
    output wire close_rsp_valid_o, input wire close_rsp_ready_i,
    output reg [3:0] close_rsp_error_o,
    output wire service_ready_o, scrub_done_o
);
    localparam IDLE=0, RELEASE=1, PREPARE=2, OPEN_REPLY=3,
               ACTIVE=4, CLEAR=5, CLOSE_REPLY=6, ERROR_REPLY=7;
    reg [2:0] state_reg;
    reg [1:0] reset_release_reg, local_release_reg;
    reg provider_reset_reg;
    reg [2:0] clear_count_reg;
    reg [31:0] id_reg;
    reg fault_reg;
    wire running=reset_n_i && reset_release_reg[1];
    wire provider_reset_n=running && !provider_reset_reg;
    wire provider_running=provider_reset_n && local_release_reg[1];
    wire [31:0] provider_word;
    wire provider_word_valid, provider_failed, provider_prepared;
    wire word_fire=word_valid_o && word_ready_i;
    assign service_ready_o=running && state_reg==IDLE;
    assign open_ready_o=service_ready_o;
    assign open_rsp_valid_o=running && (state_reg==OPEN_REPLY || state_reg==ERROR_REPLY);
    assign close_ready_o=running && state_reg==ACTIVE;
    assign close_rsp_valid_o=running && state_reg==CLOSE_REPLY;
    assign scrub_done_o=running && provider_reset_reg &&
        (state_reg==IDLE || state_reg==CLOSE_REPLY || state_reg==ERROR_REPLY);
    assign context_fault_o=running && (fault_reg || (provider_running && provider_failed));
    assign word_valid_o=running && state_reg==ACTIVE && !context_fault_o && provider_word_valid;
    assign word_data_o=word_valid_o ? provider_word : 32'd0;

    always @(posedge clock_i or negedge reset_n_i) begin
        if(!reset_n_i) reset_release_reg<=0;
        else reset_release_reg<={reset_release_reg[0],1'b1};
    end
    always @(posedge clock_i or negedge provider_reset_n) begin
        if(!provider_reset_n) local_release_reg<=0;
        else local_release_reg<={local_release_reg[0],1'b1};
    end
    generate if(DEMO_PROVIDER_MODE==1) begin : g_test
        wire start_ready;
        demo_test_source u_source(.clock_i(clock_i),.reset_n_i(provider_running),
            .start_valid_i(state_reg==PREPARE),.start_ready_o(start_ready),.seed_i(256'd0),
            .word_valid_o(provider_word_valid),.word_ready_i(word_fire),
            .data_o(provider_word),.failed_o(provider_failed));
        assign provider_prepared=start_ready;
    end else if(DEMO_PROVIDER_MODE==0) begin : g_fresh
        wire [255:0] entropy, random_block, digest;
        wire entropy_valid, entropy_needed, random_valid, instantiated;
        wire [7:0] hash_data;
        wire hash_valid,hash_last,hash_ready,digest_valid;
        reg [255:0] block_reg;
        reg [2:0] index_reg;
        reg full_reg,pending_reg,protocol_fault_reg;
        wire gen_req=provider_running && state_reg==ACTIVE && !full_reg && !protocol_fault_reg;
        entropy_source u_entropy(.clk(clock_i),.rst_n(provider_running),.enable(provider_running),
            .entropy_output(entropy),.entropy_valid(entropy_valid),.raw_sample(),.raw_sample_valid());
        random_number_generation #(.SEED_BLOCKS(SEED_BLOCKS),.RESEED_BLOCKS(RESEED_BLOCKS),
            .RESEED_INTERVAL(RESEED_INTERVAL)) u_drbg(.clk(clock_i),.rst_n(provider_running),
            .entropy_input(entropy),.entropy_valid(entropy_valid && entropy_needed),
            .entropy_needed(entropy_needed),.gen_req(gen_req),.random_output(random_block),
            .random_valid(random_valid),.instantiated(instantiated),
            .hash_msg_data(hash_data),.hash_msg_valid(hash_valid),.hash_msg_last(hash_last),
            .hash_msg_ready(hash_ready),.hash_digest(digest),.hash_digest_valid(digest_valid));
        hash_subsystem u_sha(.clk_i(clock_i),.reset_n_i(provider_running),
            .raw_request_i(1'b0),.raw_grant_o(),.raw_data_i(8'd0),.raw_valid_i(1'b0),
            .raw_end_i(1'b0),.raw_ready_o(),.raw_digest_o(),.raw_digest_valid_o(),.raw_digest_ready_i(1'b1),
            .hmac_start_en_i(1'b0),.hmac_key_data_i(8'd0),.hmac_key_valid_i(1'b0),.hmac_key_end_i(1'b0),
            .hmac_key_ready_o(),.hmac_message_data_i(8'd0),.hmac_message_valid_i(1'b0),.hmac_message_end_i(1'b0),
            .hmac_message_ready_o(),.hmac_busy_o(),.hmac_digest_o(),.hmac_digest_valid_o(),.hmac_digest_ready_i(1'b1),
            .pcr_extend_start_en_i(1'b0),.pcr_extend_index_i(5'd0),.pcr_measurement_i(256'd0),
            .pcr_busy_o(),.pcr_done_o(),.pcr_error_o(),.pcr_read_index_i(5'd0),
            .pcr_read_data_o(),.pcr_read_valid_o(),.busy_o(),
            .rng_hash_msg_data_i(hash_data),.rng_hash_msg_valid_i(hash_valid),.rng_hash_msg_last_i(hash_last),
            .rng_hash_msg_ready_o(hash_ready),.rng_hash_digest_o(digest),.rng_hash_digest_valid_o(digest_valid));
        assign provider_prepared=instantiated;
        assign provider_word=full_reg ? block_reg[255-index_reg*32 -: 32] : 32'd0;
        assign provider_word_valid=full_reg;
        assign provider_failed=protocol_fault_reg;
        always @(posedge clock_i or negedge provider_running) begin
            if(!provider_running) begin
                block_reg<=0;index_reg<=0;full_reg<=0;pending_reg<=0;protocol_fault_reg<=0;
            end else begin
                if(gen_req) pending_reg<=1;
                if(random_valid) begin
                    if(!pending_reg || full_reg || state_reg!=ACTIVE) protocol_fault_reg<=1;
                    else begin block_reg<=random_block;index_reg<=0;full_reg<=1;pending_reg<=0;end
                end
                if(word_fire) begin
                    block_reg[255-index_reg*32 -: 32]<=0;
                    if(index_reg==7) begin full_reg<=0;index_reg<=0;end
                    else index_reg<=index_reg+1'b1;
                end
            end
        end
    end else begin : g_invalid
        assign provider_prepared=1'b0;
        assign provider_word=32'd0;
        assign provider_word_valid=1'b0;
        assign provider_failed=1'b0;
    end endgenerate

    always @(posedge clock_i or negedge reset_n_i) begin
        if(!reset_n_i) begin
            state_reg<=IDLE;provider_reset_reg<=1;id_reg<=0;clear_count_reg<=0;
            fault_reg<=0;context_fault_code_o<=0;open_rsp_error_o<=0;close_rsp_error_o<=0;
        end else if(running) begin
            if(provider_running && provider_failed) begin
                fault_reg<=1;
                if(context_fault_code_o==0) context_fault_code_o<=4;
            end
            case(state_reg)
                IDLE: if(open_valid_i) begin
                    id_reg<=open_id_i;fault_reg<=0;context_fault_code_o<=0;
                    open_rsp_error_o<=0;close_rsp_error_o<=0;
                    if(open_profile_i==3 || open_mode_i!=DEMO_PROVIDER_MODE || DEMO_PROVIDER_MODE>1) begin
                        open_rsp_error_o<=1;state_reg<=ERROR_REPLY;
                    end else begin provider_reset_reg<=0;state_reg<=RELEASE;end
                end
                RELEASE: if(provider_running) state_reg<=PREPARE;
                PREPARE: if(provider_failed) begin
                    open_rsp_error_o<=4;provider_reset_reg<=1;clear_count_reg<=0;state_reg<=CLEAR;
                end else if(provider_prepared) state_reg<=OPEN_REPLY;
                OPEN_REPLY: if(open_rsp_ready_i) state_reg<=ACTIVE;
                ACTIVE: if(close_valid_i) begin
                    if(close_id_i!=id_reg) begin close_rsp_error_o<=1;fault_reg<=1;context_fault_code_o<=7;end
                    provider_reset_reg<=1;clear_count_reg<=0;state_reg<=CLEAR;
                end
                CLEAR: begin
                    if(clear_count_reg==3) state_reg<=(open_rsp_error_o!=0) ? ERROR_REPLY : CLOSE_REPLY;
                    else clear_count_reg<=clear_count_reg+1'b1;
                end
                CLOSE_REPLY: if(close_rsp_ready_i) begin
                    state_reg<=IDLE;fault_reg<=0;context_fault_code_o<=0;id_reg<=0;
                end
                ERROR_REPLY: if(open_rsp_ready_i) begin state_reg<=IDLE;id_reg<=0;end
                default: begin provider_reset_reg<=1;fault_reg<=1;context_fault_code_o<=7;state_reg<=IDLE;end
            endcase
        end
    end
    // close_failed_i records disposition at the caller; both dispositions erase identically.
endmodule
