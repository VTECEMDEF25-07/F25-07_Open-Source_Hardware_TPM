// Filename: demo_rsa_private_worker.v
// Author: Aaron Grossman / Codex-assisted implementation, 2026-11-10.
// Frozen overnight v2: RSA2048 private operation using the EXCLUSIVE leased
// keygen_math64 service. No arithmetic instance, no host/private-key export.
// Input/output are internal 256-byte big-endian streams. Protocol glue must
// validate the decoded teaching frame AND await terminal success after scrub
// before publishing any plaintext. This worker does not implement RSA padding.
`timescale 1ns/1ps
module demo_rsa_private_worker #(
    parameter [63:0] DEADLINE_CYCLES=64'd9000000000
)(
    input wire clock_i, reset_n_i,
    input wire job_valid_i,
    output wire job_ready_o,
    input wire [31:0] job_id_i, key_handle_i,
    input wire [15:0] ciphertext_bytes_i,
    input wire input_valid_i,
    output wire input_ready_o,
    input wire [7:0] input_data_i,
    output wire output_valid_o,
    input wire output_ready_i,
    output wire [7:0] output_data_o,
    output wire status_valid_o,
    input wire status_ready_i,
    output reg [31:0] status_id_o, status_code_o,
    output reg [15:0] status_result_bytes_o,
    output reg [63:0] status_cycles_o,
    output wire busy_o, rsa_client_active_o,
    output reg recovery_required_o,
    output reg [3:0] phase_o,
    output wire [7:0] progress_o,

    output wire private_open_valid_o,
    input wire private_open_ready_i, private_active_i,
    output wire private_cmd_valid_o,
    input wire private_cmd_ready_i,
    output reg [7:0] private_cmd_op_o,
    output reg [31:0] private_cmd_arg0_o, private_cmd_arg1_o,
                           private_cmd_arg2_o, private_cmd_arg3_o,
    input wire private_rsp_valid_i,
    output wire private_rsp_ready_o,
    input wire [7:0] private_rsp_status_i,
    output wire private_mem_write_en_o, private_mem_read_en_o,
    output reg [11:0] private_mem_address_o,
    output wire [31:0] private_mem_write_data_o,
    input wire private_mem_ready_i, private_mem_read_valid_i,
    input wire [31:0] private_mem_read_data_i,
    output wire private_close_valid_o,
    input wire private_close_ready_i, private_close_rsp_valid_i,
    output wire private_close_rsp_ready_o,

    output wire private_request_o,
    input wire private_request_ready_i,
    output wire [31:0] private_handle_o,
    output wire private_component_o,
    output wire [5:0] private_index_o,
    input wire private_reply_valid_i,
    output wire private_reply_ready_o,
    input wire [31:0] private_data_i, private_reply_code_i
);
    localparam [4:0] IDLE=0, OPEN=1, KEY_SEND=2, KEY_WAIT=3,
        KEY_WRITE=4, CIPHER_INPUT=5, CIPHER_WRITE=6, SETUP_SEND=7,
        SETUP_WAIT=8, EXP_SEND=9, EXP_WAIT=10, READ_SEND=11,
        READ_WAIT=12, OUTPUT=13, CLOSE_SEND=14, CLOSE_WAIT=15,
        TERMINAL=16, RECOVERY=17;
    localparam [31:0] OK=32'd0, BAD_HANDLE=32'h18b,
        BAD_VALUE=32'h095, INTERNAL_ERROR=32'h101;
    localparam [11:0] N_BASE=12'd1024, D_BASE=12'd1088,
        C_BASE=12'd1152, R_BASE=12'd1216;
    reg [4:0] state_reg;
    reg [1:0] release_reg, byte_reg;
    reg [5:0] index_reg;
    reg component_reg, d_nonzero_reg, lease_reg;
    reg [31:0] handle_reg, word_reg;
    reg [63:0] elapsed_reg;
    wire running=reset_n_i && release_reg[1];
    wire working=state_reg!=IDLE && state_reg!=TERMINAL && state_reg!=RECOVERY;
    wire expired=working && elapsed_reg>=DEADLINE_CYCLES;

    always @(posedge clock_i or negedge reset_n_i)
        if(!reset_n_i) release_reg<=0;
        else release_reg<={release_reg[0],1'b1};

    assign job_ready_o=running && state_reg==IDLE;
    assign busy_o=running && state_reg!=IDLE;
    assign rsa_client_active_o=busy_o;
    assign input_ready_o=running && state_reg==CIPHER_INPUT;
    assign output_valid_o=running && state_reg==OUTPUT;
    assign output_data_o=output_valid_o ? word_reg[31:24] : 8'd0;
    assign status_valid_o=running && state_reg==TERMINAL;
    assign progress_o={2'd0,index_reg};

    assign private_open_valid_o=running && state_reg==OPEN;
    assign private_cmd_valid_o=running && (state_reg==SETUP_SEND || state_reg==EXP_SEND);
    assign private_rsp_ready_o=running && (state_reg==SETUP_WAIT || state_reg==EXP_WAIT);
    assign private_mem_write_en_o=running && (state_reg==KEY_WRITE || state_reg==CIPHER_WRITE);
    assign private_mem_read_en_o=running && state_reg==READ_SEND;
    assign private_mem_write_data_o=private_mem_write_en_o ? word_reg : 32'd0;
    assign private_close_valid_o=running && state_reg==CLOSE_SEND;
    assign private_close_rsp_ready_o=running && state_reg==CLOSE_WAIT;
    assign private_request_o=running && state_reg==KEY_SEND;
    assign private_handle_o=private_request_o ? handle_reg : 32'd0;
    assign private_component_o=component_reg;
    assign private_index_o=index_reg;
    assign private_reply_ready_o=running && state_reg==KEY_WAIT;

    always @* begin
        private_cmd_op_o=0;
        private_cmd_arg0_o=0; private_cmd_arg1_o=0;
        private_cmd_arg2_o=0; private_cmd_arg3_o=0;
        if(state_reg==SETUP_SEND) begin
            private_cmd_op_o=8'h11;
            private_cmd_arg0_o=32'd1024; private_cmd_arg1_o=32'd1536;
            private_cmd_arg2_o=32'd64;
        end else if(state_reg==EXP_SEND) begin
            private_cmd_op_o=8'h13;
            private_cmd_arg0_o=32'd1216; private_cmd_arg1_o=32'd1152;
            private_cmd_arg2_o=32'd1088; private_cmd_arg3_o=32'd64;
        end
        private_mem_address_o=12'd0;
        if(state_reg==KEY_WRITE)
            private_mem_address_o=(component_reg ? D_BASE : N_BASE)+12'd63-{6'd0,index_reg};
        else if(state_reg==CIPHER_WRITE)
            private_mem_address_o=C_BASE+12'd63-{6'd0,index_reg};
        else if(state_reg==READ_SEND)
            private_mem_address_o=R_BASE+12'd63-{6'd0,index_reg};
        case(state_reg)
            IDLE: phase_o=0;
            OPEN: phase_o=1;
            KEY_SEND,KEY_WAIT,KEY_WRITE: phase_o=2;
            CIPHER_INPUT,CIPHER_WRITE: phase_o=3;
            SETUP_SEND,SETUP_WAIT: phase_o=4;
            EXP_SEND,EXP_WAIT: phase_o=5;
            READ_SEND,READ_WAIT,OUTPUT: phase_o=6;
            CLOSE_SEND,CLOSE_WAIT: phase_o=7;
            TERMINAL: phase_o=status_code_o==0 ? 4'd8 : 4'd9;
            default: phase_o=9;
        endcase
    end

    always @(posedge clock_i or negedge reset_n_i) begin
        if(!reset_n_i) begin
            state_reg<=IDLE; index_reg<=0; byte_reg<=0; component_reg<=0;
            d_nonzero_reg<=0; lease_reg<=0; handle_reg<=0; word_reg<=0;
            elapsed_reg<=0; status_id_o<=0; status_code_o<=0;
            status_result_bytes_o<=0; status_cycles_o<=0; recovery_required_o<=0;
        end else if(running) begin
            if(working && elapsed_reg!=64'hffffffffffffffff) elapsed_reg<=elapsed_reg+1'b1;
            // Unsafe unfinished-command timeout/lost lease requires the common
            // supervisor to reset requester, arithmetic and response state.
            // No terminal success/error is fabricated before physical scrub.
            if(expired || (lease_reg && !private_active_i)) begin
                recovery_required_o<=1; state_reg<=RECOVERY;
                word_reg<=0; status_result_bytes_o<=0;
            end else case(state_reg)
                IDLE: if(job_valid_i && job_ready_o) begin
                    status_id_o<=job_id_i; handle_reg<=key_handle_i;
                    status_code_o<=OK; status_result_bytes_o<=0; status_cycles_o<=0;
                    index_reg<=0; byte_reg<=0; component_reg<=0; d_nonzero_reg<=0;
                    word_reg<=0; elapsed_reg<=0;
                    if(ciphertext_bytes_i!=16'd256) begin
                        status_code_o<=BAD_VALUE; state_reg<=TERMINAL;
                    end else if(key_handle_i==0) begin
                        status_code_o<=BAD_HANDLE; state_reg<=TERMINAL;
                    end else state_reg<=OPEN;
                end
                OPEN: if(private_open_ready_i) begin lease_reg<=1; state_reg<=KEY_SEND; end
                KEY_SEND: if(private_request_ready_i) state_reg<=KEY_WAIT;
                KEY_WAIT: if(private_reply_valid_i) begin
                    if(private_reply_code_i!=0) begin
                        status_code_o<=private_reply_code_i; word_reg<=0; state_reg<=CLOSE_SEND;
                    end else if((!component_reg && index_reg==0 && !private_data_i[31]) ||
                                (!component_reg && index_reg==63 && !private_data_i[0]) ||
                                (component_reg && index_reg==63 && !d_nonzero_reg && private_data_i==0)) begin
                        status_code_o<=BAD_VALUE; word_reg<=0; state_reg<=CLOSE_SEND;
                    end else begin
                        word_reg<=private_data_i;
                        if(component_reg) d_nonzero_reg<=d_nonzero_reg || private_data_i!=0;
                        state_reg<=KEY_WRITE;
                    end
                end
                KEY_WRITE: if(private_mem_ready_i) begin
                    word_reg<=0;
                    if(index_reg==63) begin
                        index_reg<=0;
                        if(component_reg) state_reg<=CIPHER_INPUT;
                        else begin component_reg<=1; state_reg<=KEY_SEND; end
                    end else begin index_reg<=index_reg+1'b1; state_reg<=KEY_SEND; end
                end
                CIPHER_INPUT: if(input_valid_i) begin
                    word_reg<={word_reg[23:0],input_data_i};
                    if(byte_reg==3) begin byte_reg<=0; state_reg<=CIPHER_WRITE; end
                    else byte_reg<=byte_reg+1'b1;
                end
                CIPHER_WRITE: if(private_mem_ready_i) begin
                    word_reg<=0;
                    if(index_reg==63) begin index_reg<=0; state_reg<=SETUP_SEND; end
                    else begin index_reg<=index_reg+1'b1; state_reg<=CIPHER_INPUT; end
                end
                SETUP_SEND: if(private_cmd_ready_i) state_reg<=SETUP_WAIT;
                SETUP_WAIT: if(private_rsp_valid_i) begin
                    if(private_rsp_status_i!=0) begin
                        status_code_o<=private_rsp_status_i==4 ? BAD_VALUE : INTERNAL_ERROR;
                        state_reg<=CLOSE_SEND;
                    end else state_reg<=EXP_SEND;
                end
                EXP_SEND: if(private_cmd_ready_i) state_reg<=EXP_WAIT;
                EXP_WAIT: if(private_rsp_valid_i) begin
                    if(private_rsp_status_i!=0) begin
                        status_code_o<=private_rsp_status_i==4 ? BAD_VALUE : INTERNAL_ERROR;
                        state_reg<=CLOSE_SEND;
                    end else begin index_reg<=0; state_reg<=READ_SEND; end
                end
                READ_SEND: if(private_mem_ready_i) state_reg<=READ_WAIT;
                READ_WAIT: if(private_mem_read_valid_i) begin
                    word_reg<=private_mem_read_data_i; byte_reg<=0; state_reg<=OUTPUT;
                end
                OUTPUT: if(output_ready_i) begin
                    word_reg<={word_reg[23:0],8'd0};
                    if(byte_reg==3) begin
                        byte_reg<=0;
                        if(index_reg==63) state_reg<=CLOSE_SEND;
                        else begin index_reg<=index_reg+1'b1; state_reg<=READ_SEND; end
                    end else byte_reg<=byte_reg+1'b1;
                end
                CLOSE_SEND: if(private_close_ready_i) begin word_reg<=0; state_reg<=CLOSE_WAIT; end
                CLOSE_WAIT: if(private_close_rsp_valid_i) begin
                    lease_reg<=0; word_reg<=0;
                    status_result_bytes_o<=status_code_o==OK ? 16'd256 : 16'd0;
                    status_cycles_o<=elapsed_reg+1'b1; state_reg<=TERMINAL;
                end
                TERMINAL: if(status_ready_i) begin handle_reg<=0; word_reg<=0; state_reg<=IDLE; end
                RECOVERY: begin end
                default: begin recovery_required_o<=1; word_reg<=0; state_reg<=RECOVERY; end
            endcase
        end
    end
endmodule
