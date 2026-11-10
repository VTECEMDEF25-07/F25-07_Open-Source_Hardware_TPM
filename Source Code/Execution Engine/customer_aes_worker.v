// Customer demo AES256-CFB128 decrypt leaf. No key lookup/export or packet ABI.
// Plaintext is provisional until held status_code_o==0 after reset+RAM scrub.
`default_nettype none
module customer_aes_worker #(
    parameter [63:0] JOB_DEADLINE_CYCLES=64'd50000000,
    parameter [31:0] CLEANUP_DEADLINE_CYCLES=32'd10000
)(
    input wire clock_i,reset_n_i,
    input wire job_valid_i,output wire job_ready_o,
    input wire [255:0] job_key_i,
    input wire [127:0] job_iv_i,
    input wire [15:0] job_bytes_i,
    input wire input_valid_i,output wire input_ready_o,input wire [7:0] input_data_i,
    output wire output_valid_o,input wire output_ready_i,output wire [7:0] output_data_o,
    output wire status_valid_o,input wire status_ready_i,
    output reg [31:0] status_code_o,
    output reg [15:0] status_result_bytes_o,
    output reg [127:0] status_iv_o,
    output reg [63:0] status_cycles_o,
    output wire busy_o,scrub_done_o,output reg recovery_required_o
);
    localparam BOOT=0,IDLE=1,INPUT_BYTE=2,WRITE_WAIT=3,AES_START=4,AES_RUN=5,
        READ_REQ=6,READ_WAIT=7,OUTPUT_BYTE=8,CLEAR_REQ=9,CLEAR_WAIT=10,
        STATUS=11,LOCKED=12;
    reg [3:0] state;
    reg [255:0] key;
    reg [127:0] iv;
    reg [15:0] length;
    reg [10:0] offset;
    reg [7:0] result_byte;
    reg core_enable;
    reg [63:0] active_cycles;
    reg [31:0] cleanup_cycles;
    wire core_reset_n=reset_n_i && core_enable;
    wire aes_done,aes_busy,aes_error;
    wire [11:0] aes_rc;
    wire [127:0] aes_iv;
    wire [31:0] aes_completed;
    wire aes_req_valid,aes_req_ready,aes_req_write,aes_rsp_ready;
    wire [11:0] aes_req_addr;
    wire [7:0] aes_req_data;
    wire ram_req_valid,ram_req_ready,ram_req_write,ram_rsp_valid,ram_rsp_ready,ram_rsp_error;
    wire [11:0] ram_req_addr;
    wire [7:0] ram_req_data,ram_rsp_data;
    wire clear_ready,clear_done,ram_scrubbed;
    wire aes_owner=state==AES_START || state==AES_RUN;
    assign job_ready_o=reset_n_i && state==IDLE && ram_scrubbed && !recovery_required_o;
    assign input_ready_o=reset_n_i && state==INPUT_BYTE && ram_req_ready;
    assign output_valid_o=reset_n_i && state==OUTPUT_BYTE;
    assign output_data_o=output_valid_o ? result_byte : 8'd0;
    assign status_valid_o=reset_n_i && state==STATUS;
    assign busy_o=reset_n_i && state!=IDLE;
    assign scrub_done_o=reset_n_i && ram_scrubbed && !core_enable && key==0 &&
        (state==IDLE || state==STATUS || state==LOCKED);
    assign ram_req_valid=reset_n_i && (aes_owner ? aes_req_valid :
        state==READ_REQ || (state==INPUT_BYTE && input_valid_i));
    assign ram_req_write=aes_owner ? aes_req_write : state==INPUT_BYTE;
    assign ram_req_addr=aes_owner ? aes_req_addr : {1'b0,offset};
    assign ram_req_data=aes_owner ? aes_req_data : input_data_i;
    assign ram_rsp_ready=reset_n_i && (aes_owner ? aes_rsp_ready :
        state==WRITE_WAIT || state==READ_WAIT || state==CLEAR_REQ);
    assign aes_req_ready=aes_owner && ram_req_ready;
    demo_byte_ram buffer (
        .clock_i(clock_i),.reset_n_i(reset_n_i),
        .ram_req_valid_i(ram_req_valid),.ram_req_ready_o(ram_req_ready),
        .ram_req_write_i(ram_req_write),.ram_req_addr_i(ram_req_addr),.ram_req_wdata_i(ram_req_data),
        .ram_rsp_valid_o(ram_rsp_valid),.ram_rsp_ready_i(ram_rsp_ready),
        .ram_rsp_rdata_o(ram_rsp_data),.ram_rsp_error_o(ram_rsp_error),
        .access_allowed_i(1'b1),.clear_valid_i(state==CLEAR_REQ),.clear_ready_o(clear_ready),
        .clear_done_valid_o(clear_done),.clear_done_ready_i(state==CLEAR_WAIT),.scrub_done_o(ram_scrubbed)
    );
    symm_top aes (
        .clock_i(clock_i),.reset_n_i(core_reset_n),.start_i(state==AES_START),
        .command_code_i(16'h0193),.key_valid_i(1'b1),.session_protect_i(1'b0),
        .session_valid_i(1'b0),.session_decrypt_i(1'b0),.session_encrypt_i(1'b0),
        .session_use_xor_i(1'b0),.mode_i(3'd1),.session_value_i(1024'd0),
        .session_value_bytes_i(16'd0),.nonce_newer_i(512'd0),.nonce_older_i(512'd0),
        .nonce_newer_bytes_i(16'd0),.nonce_older_bytes_i(16'd0),
        .hmac_start_o(),.hmac_key_data_o(),.hmac_message_data_o(),
        .hmac_key_valid_o(),.hmac_key_end_o(),.hmac_key_ready_i(1'b0),
        .hmac_message_valid_o(),.hmac_message_end_o(),.hmac_message_ready_i(1'b0),
        .hmac_busy_i(1'b0),.hmac_digest_i(256'd0),.hmac_digest_valid_i(1'b0),.hmac_digest_ready_o(),
        .key_i(key),.iv_i(iv),.decrypt_i(1'b1),.input_base_i(12'd0),.output_base_i(12'd0),
        .data_length_i({16'd0,length}),.busy_o(aes_busy),.done_o(aes_done),.error_o(aes_error),
        .tpm_rc_o(aes_rc),.final_iv_o(aes_iv),.completed_length_o(aes_completed),
        .ram_req_valid_o(aes_req_valid),.ram_req_ready_i(aes_req_ready),
        .ram_req_write_o(aes_req_write),.ram_req_addr_o(aes_req_addr),.ram_req_data_o(aes_req_data),
        .ram_rsp_valid_i(aes_owner && ram_rsp_valid),.ram_rsp_ready_o(aes_rsp_ready),
        .ram_rsp_data_i(ram_rsp_data),.ram_rsp_error_i(ram_rsp_error)
    );
    always @(posedge clock_i or negedge reset_n_i) begin
        if(!reset_n_i)begin
            state<=BOOT;key<=0;iv<=0;length<=0;offset<=0;result_byte<=0;core_enable<=0;
            active_cycles<=0;cleanup_cycles<=0;status_code_o<=0;status_result_bytes_o<=0;
            status_iv_o<=0;status_cycles_o<=0;recovery_required_o<=0;
        end else begin
            if(state!=BOOT && state!=IDLE && state!=STATUS && state!=LOCKED)
                active_cycles<=active_cycles+1'b1;
            if(state==CLEAR_REQ || state==CLEAR_WAIT)cleanup_cycles<=cleanup_cycles+1'b1;
            if(state!=BOOT && state!=IDLE && state!=STATUS && state!=LOCKED &&
                state!=CLEAR_REQ && state!=CLEAR_WAIT && active_cycles>=JOB_DEADLINE_CYCLES)begin
                status_code_o<=32'h101;status_result_bytes_o<=0;status_iv_o<=0;
                key<=0;iv<=0;core_enable<=0;result_byte<=0;recovery_required_o<=1;
                cleanup_cycles<=0;state<=CLEAR_REQ;
            end else if((state==CLEAR_REQ || state==CLEAR_WAIT) && cleanup_cycles>=CLEANUP_DEADLINE_CYCLES)begin
                recovery_required_o<=1;status_code_o<=32'h101;status_result_bytes_o<=0;
                status_iv_o<=0;state<=LOCKED;
            end else case(state)
                BOOT:if(ram_scrubbed)state<=IDLE;
                IDLE:if(job_valid_i && job_ready_o)begin
                    key<=job_key_i;iv<=job_iv_i;length<=job_bytes_i;offset<=0;result_byte<=0;
                    active_cycles<=0;cleanup_cycles<=0;status_cycles_o<=0;
                    status_code_o<=0;status_result_bytes_o<=0;status_iv_o<=0;
                    if(job_bytes_i>1024)begin
                        key<=0;iv<=0;core_enable<=0;status_code_o<=32'h095;state<=CLEAR_REQ;
                    end else begin core_enable<=1;state<=job_bytes_i==0?AES_START:INPUT_BYTE;end
                end
                INPUT_BYTE:if(input_valid_i && input_ready_o)state<=WRITE_WAIT;
                WRITE_WAIT:if(ram_rsp_valid)begin
                    if(ram_rsp_error)begin
                        status_code_o<=32'h101;key<=0;iv<=0;core_enable<=0;
                        recovery_required_o<=1;cleanup_cycles<=0;state<=CLEAR_REQ;
                    end else if(offset==length-1)begin offset<=0;state<=AES_START;end
                    else begin offset<=offset+1'b1;state<=INPUT_BYTE;end
                end
                AES_START:state<=AES_RUN;
                AES_RUN:if(aes_done)begin
                    key<=0;iv<=0;core_enable<=0;offset<=0;
                    if(aes_error || aes_rc!=0 || aes_completed!=length)begin
                        status_code_o<=32'h101;status_result_bytes_o<=0;status_iv_o<=0;
                        recovery_required_o<=1;cleanup_cycles<=0;state<=CLEAR_REQ;
                    end else begin
                        status_result_bytes_o<=length;status_iv_o<=aes_iv;
                        if(length==0)begin cleanup_cycles<=0;state<=CLEAR_REQ;end
                        else state<=READ_REQ;
                    end
                end
                READ_REQ:if(ram_req_ready)state<=READ_WAIT;
                READ_WAIT:if(ram_rsp_valid)begin
                    if(ram_rsp_error)begin
                        status_code_o<=32'h101;status_result_bytes_o<=0;status_iv_o<=0;
                        result_byte<=0;recovery_required_o<=1;cleanup_cycles<=0;state<=CLEAR_REQ;
                    end else begin result_byte<=ram_rsp_data;state<=OUTPUT_BYTE;end
                end
                OUTPUT_BYTE:if(output_ready_i)begin
                    result_byte<=0;
                    if(offset==length-1)begin cleanup_cycles<=0;state<=CLEAR_REQ;end
                    else begin offset<=offset+1'b1;state<=READ_REQ;end
                end
                CLEAR_REQ:if(clear_ready)state<=CLEAR_WAIT;
                CLEAR_WAIT:if(clear_done && ram_scrubbed)begin
                    status_cycles_o<=active_cycles+1'b1;state<=STATUS;
                end
                STATUS:if(status_ready_i)begin
                    status_result_bytes_o<=0;status_iv_o<=0;length<=0;offset<=0;
                    state<=recovery_required_o?LOCKED:IDLE;
                end
                LOCKED:begin key<=0;iv<=0;core_enable<=0;result_byte<=0;end
                default:begin recovery_required_o<=1;key<=0;iv<=0;core_enable<=0;state<=CLEAR_REQ;end
            endcase
        end
    end
endmodule
`default_nettype wire
