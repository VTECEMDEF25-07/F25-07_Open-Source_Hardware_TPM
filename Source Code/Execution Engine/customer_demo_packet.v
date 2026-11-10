// Frozen customer v2 leaf. No crypto arithmetic or protected-store implementation.
// Codex assisted. response_length_o is PAYLOAD ONLY (metadata+body); lead adds10.
`default_nettype none
module customer_demo_packet #(
    parameter DEMO_PROVIDER_MODE=0, parameter DEMO_AES_EXPORT_ENABLE=0,
    parameter [63:0] DEADLINE_CYCLES=64'd9000000000
)(
    input wire clock_i,reset_n_i,start_i,operational_i,
    input wire [15:0] command_tag_i,
    input wire [31:0] command_size_i,
    output reg [11:0] command_addr_o,input wire [7:0] command_byte_i,
    output reg response_valid_o,output reg [31:0] response_code_o,
    output wire [11:0] response_length_o,
    input wire [11:0] response_addr_i,output reg [7:0] response_byte_o,
    input wire response_consumed_i,
    output wire busy_o,scrub_done_o,output reg recovery_required_o,
    input wire [31:0] snapshot_status_word_i,snapshot_operation_id_i,snapshot_sequence_i,
    output wire gen_job_valid_o,input wire gen_job_ready_i,
    output wire [1:0] gen_job_profile_o,gen_job_mode_o,output wire [31:0] gen_job_id_o,
    input wire gen_done_valid_i,output wire gen_done_ready_o,
    input wire [31:0] gen_done_id_i,gen_done_handle_i,
    input wire [1:0] gen_done_profile_i,gen_done_mode_i,
    input wire [3:0] gen_done_core_status_i,gen_done_setup_error_i,gen_done_teardown_error_i,
    input wire gen_done_ownership_committed_i,
    input wire [63:0] gen_done_cycles_i,
    input wire [3:0] gen_phase_i,
    input wire gen_available_i,gen_busy_i,gen_recovery_required_i,gen_scrub_done_i,
    output wire release_valid_o,input wire release_ready_i,
    output wire [31:0] release_handle_o,
    input wire release_rsp_valid_i,output wire release_rsp_ready_o,
    input wire [31:0] release_rsp_code_i,
    output wire key_request_o,input wire key_request_ready_i,output wire [31:0] key_handle_o,
    input wire key_reply_valid_i,output wire key_reply_ready_o,
    input wire [255:0] resolved_key_i,input wire [31:0] key_reply_code_i,
    output reg aes_use_allowed_o,rsa_use_allowed_o,output wire aes_client_active_o,
    output wire public_request_o,input wire public_request_ready_i,
    output wire [31:0] public_handle_o,output wire public_component_o,
    output wire [5:0] public_index_o,
    input wire public_reply_valid_i,output wire public_reply_ready_o,
    input wire [31:0] public_data_i,public_reply_code_i,
    output wire aes_job_valid_o,input wire aes_job_ready_i,
    output wire [255:0] aes_job_key_o,output wire [127:0] aes_job_iv_o,
    output wire [15:0] aes_job_bytes_o,
    output wire aes_input_valid_o,input wire aes_input_ready_i,output wire [7:0] aes_input_data_o,
    input wire aes_output_valid_i,output wire aes_output_ready_o,input wire [7:0] aes_output_data_i,
    input wire aes_status_valid_i,output wire aes_status_ready_o,
    input wire [31:0] aes_status_code_i,input wire [15:0] aes_status_result_bytes_i,
    input wire [127:0] aes_status_iv_i,input wire [63:0] aes_status_cycles_i,
    input wire aes_busy_i,aes_scrub_done_i,aes_recovery_required_i,
    output wire rsa_job_valid_o,input wire rsa_job_ready_i,
    output wire [31:0] rsa_job_id_o,rsa_key_handle_o,
    output wire [15:0] rsa_ciphertext_bytes_o,
    output wire rsa_input_valid_o,input wire rsa_input_ready_i,output wire [7:0] rsa_input_data_o,
    input wire rsa_output_valid_i,output wire rsa_output_ready_o,input wire [7:0] rsa_output_data_i,
    input wire rsa_status_valid_i,output wire rsa_status_ready_o,
    input wire [31:0] rsa_status_id_i,rsa_status_code_i,
    input wire [15:0] rsa_status_result_bytes_i,input wire [63:0] rsa_status_cycles_i,
    input wire rsa_busy_i,rsa_recovery_required_i,
    input wire [3:0] rsa_phase_i,input wire [7:0] rsa_progress_i,
    output wire status_valid_o,output reg [3:0] status_code_o,
    output reg [7:0] status_detail_o,output wire [31:0] status_operation_id_o,
    output wire job_accept_o,output wire [31:0] job_id_o
);
    localparam SCRUB=0,IDLE=1,PREFIX_WAIT=2,PREFIX_BYTE=3,DISPATCH=4,
        IV_WAIT=5,IV_BYTE=6,LEN_WAIT=7,LEN_BYTE=8,DATA_WAIT=9,DATA_BYTE=10,
        RELEASE_SEND=11,RELEASE_WAIT=12,GEN_SEND=13,GEN_WAIT=14,KEY_SEND=15,KEY_WAIT=16,
        AES_JOB=17,RSA_JOB=18,STREAM_ADDR=19,STREAM_WAIT=20,STREAM_SEND=21,WORK_WAIT=22,
        PUB_SEND=23,PUB_WAIT=24,PUB_WRITE=25,VALIDATE_ADDR=26,VALIDATE_WAIT=27,VALIDATE_BYTE=28,
        SUCCEED=29,ANNOUNCE=30,HOLD=31,SCRUB_LATCH=32,RECOVERY=33;
    reg [5:0] state;
    reg [127:0] prefix;
    wire [127:0] next_prefix={prefix[119:0],command_byte_i};
    reg [31:0] request_id,request_handle,request_size,owned_handle,reply_handle;
    reg [1:0] owned_profile;
    reg [7:0] opcode,field_index,length_hi;
    reg [15:0] data_length,result_length;
    reg [10:0] data_index,input_index,output_count;
    reg [9:0] scrub_index,internal_read_addr;
    reg [1:0] latch_count;
    reg scrub_for_reply,worker_active;
    reg [255:0] aes_key;
    reg [127:0] iv,final_iv;
    reg [11:0] body_length;
    reg [31:0] reply_status_word,reply_status_id,reply_status_sequence;
    reg [31:0] operation_status,cleanup_status;
    reg [63:0] elapsed,last_gen_cycles,last_aes_cycles,last_rsa_cycles;
    reg public_component;
    reg [5:0] public_index;
    reg [31:0] public_word;
    reg [1:0] public_byte_index;
    reg [8:0] validate_index;
    reg [7:0] rsa_length_hi;
    reg [15:0] rsa_message_length;
    reg validation_failed;
    reg [3:0] sticky_state;
    reg [7:0] sticky_detail;

    // Explicit synchronous ports retain block RAM inference; no asynchronous memory reads.
    (* ramstyle="M20K" *) reg [7:0] payload[0:1023];
    reg [7:0] internal_read_data,response_ram_data;
    reg [11:0] response_addr_q;
    reg ram_write_valid;
    reg [9:0] ram_write_addr,response_ram_addr;
    reg [7:0] ram_write_data;
    wire aes_mode=opcode==2;
    wire aes_output_fire=aes_output_valid_i && aes_output_ready_o;
    wire rsa_output_fire=rsa_output_valid_i && rsa_output_ready_o;
    wire [11:0] completed_output_count={1'b0,output_count}+(aes_output_fire || rsa_output_fire);
    wire successful_gen=gen_done_id_i==request_id && gen_done_profile_i==gen_job_profile_o &&
        gen_done_mode_i==DEMO_PROVIDER_MODE && gen_done_core_status_i==0 && gen_done_setup_error_i==0 &&
        gen_done_teardown_error_i==0 && gen_done_ownership_committed_i && gen_done_handle_i!=0 && gen_scrub_done_i;
    wire [15:0] base_flags=(DEMO_AES_EXPORT_ENABLE ? 16'h10 : 16'h0)|16'h20|
        (DEMO_PROVIDER_MODE==1 ? 16'h2 : 16'h0)|(owned_handle!=0 ? 16'h1 : 16'h0);
    wire [31:0] features=(DEMO_AES_EXPORT_ENABLE ? 32'd1 : 32'd0)|32'd6;
    wire [191:0] caps_body={16'd256,16'd2048,16'd1024,16'd240,32'd50000000,32'h00d40f80,32'h00d40fa0,features};
    wire [95:0] status_body={reply_status_word,reply_status_id,reply_status_sequence};

    assign busy_o=reset_n_i && state!=IDLE;
    assign scrub_done_o=reset_n_i && state==IDLE && !recovery_required_o;
    assign response_length_o=response_code_o==0 ? 12'd28+body_length : 12'd0;
    assign gen_job_valid_o=reset_n_i && state==GEN_SEND && !recovery_required_o;
    assign gen_job_profile_o=opcode==1 ? 2'd1 : 2'd2;
    assign gen_job_mode_o=DEMO_PROVIDER_MODE;
    assign gen_job_id_o=request_id;
    assign gen_done_ready_o=reset_n_i && state==GEN_WAIT && gen_scrub_done_i;
    assign release_valid_o=reset_n_i && state==RELEASE_SEND;
    assign release_handle_o=owned_handle;
    assign release_rsp_ready_o=reset_n_i && state==RELEASE_WAIT;
    assign key_request_o=reset_n_i && state==KEY_SEND;
    assign key_handle_o=opcode==1 ? owned_handle : request_handle;
    assign key_reply_ready_o=reset_n_i && state==KEY_WAIT;
    assign aes_client_active_o=reset_n_i && (state==KEY_SEND || state==KEY_WAIT || state==AES_JOB ||
        (worker_active && opcode==2) || (opcode==1 && response_code_o==0 && (state==SUCCEED || state==ANNOUNCE || state==HOLD)));
    assign public_request_o=reset_n_i && state==PUB_SEND;
    assign public_handle_o=owned_handle;
    assign public_component_o=public_component;
    assign public_index_o=public_index;
    assign public_reply_ready_o=reset_n_i && state==PUB_WAIT;
    assign aes_job_valid_o=reset_n_i && state==AES_JOB;
    assign aes_job_key_o=aes_key;
    assign aes_job_iv_o=iv;
    assign aes_job_bytes_o=data_length;
    assign aes_input_valid_o=reset_n_i && state==STREAM_SEND && aes_mode;
    assign aes_input_data_o=internal_read_data;
    assign rsa_input_valid_o=reset_n_i && state==STREAM_SEND && !aes_mode;
    assign rsa_input_data_o=internal_read_data;
    assign aes_output_ready_o=reset_n_i && worker_active && opcode==2 && output_count<data_length;
    assign rsa_output_ready_o=reset_n_i && worker_active && opcode==4 && output_count<256;
    assign aes_status_ready_o=reset_n_i && state==WORK_WAIT && aes_mode && aes_scrub_done_i;
    assign rsa_status_ready_o=reset_n_i && state==WORK_WAIT && !aes_mode;
    assign rsa_job_valid_o=reset_n_i && state==RSA_JOB;
    assign rsa_job_id_o=request_id;
    assign rsa_key_handle_o=request_handle;
    assign rsa_ciphertext_bytes_o=16'd256;
    assign status_valid_o=reset_n_i;
    assign status_operation_id_o=request_id;
    assign job_accept_o=reset_n_i && state==DISPATCH && opcode!=0 && opcode!=5;
    assign job_id_o=request_id;

    always @* begin
        status_code_o=sticky_state; status_detail_o=sticky_detail;
        if(state==GEN_SEND && !gen_available_i) begin status_code_o=2; status_detail_o=opcode; end
        else if(state==GEN_SEND || state==GEN_WAIT) begin
            status_code_o=gen_phase_i==4 ? 2 : opcode==1 ? 3 : 4;
            status_detail_o={4'd0,gen_phase_i};
        end
        else if(worker_active && opcode==2) begin status_code_o=6; status_detail_o=2; end
        else if(worker_active && opcode==4) begin status_code_o=7; status_detail_o=rsa_progress_i; end
        else if(opcode==4 && (state==VALIDATE_ADDR || state==VALIDATE_WAIT || state==VALIDATE_BYTE)) begin
            status_code_o=7; status_detail_o=validate_index[7:0];
        end
        else if(state==RECOVERY) begin status_code_o=9; status_detail_o=8'hff; end
    end

    // One writer; public word packing and worker output never overlap by state.
    always @* begin
        ram_write_valid=0; ram_write_addr=0; ram_write_data=0;
        if(state==SCRUB) begin ram_write_valid=1; ram_write_addr=scrub_index; end
        else if(state==DATA_BYTE) begin
            ram_write_valid=1; ram_write_addr=data_index[9:0]; ram_write_data=command_byte_i;
        end else if(state==PUB_WRITE) begin
            ram_write_valid=1;
            ram_write_addr=(public_component ? 10'd256 : {public_index,2'b00})+public_byte_index;
            ram_write_data=public_word[31-public_byte_index*8 -:8];
        end else if(aes_output_fire || rsa_output_fire) begin
            ram_write_valid=1; ram_write_addr=output_count[9:0];
            ram_write_data=aes_output_fire ? aes_output_data_i : rsa_output_data_i;
        end
    end
    always @* begin
        response_ram_addr=0;
        if(opcode==2 && response_addr_i>=30 && response_addr_i<30+result_length)
            response_ram_addr=response_addr_i-30;
        else if(opcode==4 && response_addr_i>=30 && response_addr_i<30+result_length)
            response_ram_addr=response_addr_i-23; // raw RSA payload begins at byte7
        else if(opcode==3) begin
            if(response_addr_i>=30 && response_addr_i<286) response_ram_addr=response_addr_i-30;
            else if(response_addr_i>=288 && response_addr_i<292) response_ram_addr=response_addr_i-32;
        end
    end
    always @(posedge clock_i) begin
        if(reset_n_i && ram_write_valid) payload[ram_write_addr]<=ram_write_data;
        response_addr_q<=response_addr_i;
        if(!reset_n_i || state==SCRUB || state==SCRUB_LATCH) begin
            internal_read_data<=0; response_ram_data<=0;
        end else begin
            internal_read_data<=payload[internal_read_addr];
            response_ram_data<=payload[response_ram_addr];
        end
    end

    // One-cycle synchronous response-byte interface. CRB must stage the address first.
    reg [11:0] body_offset;
    reg [223:0] meta_bytes;
    always @* begin
        response_byte_o=0; body_offset=response_addr_q-12'd28;
        meta_bytes={8'd2,opcode,8'd0,{4'd0,status_code_o},request_id,reply_handle,
            16'd1024,base_flags,operation_status,cleanup_status,{20'd0,body_length}};
        meta_bytes[207:200]=DEMO_PROVIDER_MODE;
        if(response_code_o==0 && (state==ANNOUNCE || state==HOLD)) begin
            if(response_addr_q<28) response_byte_o=meta_bytes[223-response_addr_q*8 -:8];
            else case(opcode)
                0: if(body_offset<24) response_byte_o=caps_body[191-body_offset*8 -:8];
                1: if(body_offset<32) response_byte_o=aes_key[255-body_offset*8 -:8];
                2: begin
                    if(body_offset==0) response_byte_o=result_length[15:8];
                    else if(body_offset==1) response_byte_o=result_length[7:0];
                    else if(body_offset<2+result_length) response_byte_o=response_ram_data;
                    else if(body_offset<18+result_length)
                        response_byte_o=final_iv[127-(body_offset-2-result_length)*8 -:8];
                end
                3: begin
                    if(body_offset==0) response_byte_o=1;
                    else if(body_offset==1 || body_offset==258) response_byte_o=0;
                    else if(body_offset==259) response_byte_o=4;
                    else if(body_offset<264) response_byte_o=response_ram_data;
                end
                4: begin
                    if(body_offset==0) response_byte_o=result_length[15:8];
                    else if(body_offset==1) response_byte_o=result_length[7:0];
                    else if(body_offset<2+result_length) response_byte_o=response_ram_data;
                end
                5: if(body_offset<12) response_byte_o=status_body[95-body_offset*8 -:8];
                default: response_byte_o=0;
            endcase
        end
    end

    task fail;
        input [31:0] code;
        begin
            response_code_o<=code; body_length<=0; result_length<=0; aes_key<=0;
            sticky_state<=9; sticky_detail<=code[7:0];
            scrub_for_reply<=1; scrub_index<=0; state<=SCRUB;
        end
    endtask
    task recover;
        begin
            recovery_required_o<=1; aes_use_allowed_o<=0; rsa_use_allowed_o<=0;
            aes_key<=0; state<=RECOVERY; sticky_state<=9; sticky_detail<=8'hff;
        end
    endtask

    always @(posedge clock_i or negedge reset_n_i) begin
        if(!reset_n_i) begin
            state<=SCRUB; scrub_for_reply<=0; scrub_index<=0; latch_count<=0;
            command_addr_o<=0; response_valid_o<=0; response_code_o<=0; recovery_required_o<=0;
            prefix<=0; request_id<=0; request_handle<=0; request_size<=0; opcode<=0;
            owned_handle<=0; owned_profile<=0; reply_handle<=0;
            aes_use_allowed_o<=0; rsa_use_allowed_o<=0; aes_key<=0; iv<=0; final_iv<=0;
            data_length<=0; result_length<=0; data_index<=0; input_index<=0; output_count<=0;
            field_index<=0; length_hi<=0; internal_read_addr<=0; worker_active<=0;
            body_length<=0; operation_status<=0; cleanup_status<=0;
            reply_status_word<=0; reply_status_id<=0; reply_status_sequence<=0;
            elapsed<=0; last_gen_cycles<=0; last_aes_cycles<=0; last_rsa_cycles<=0;
            public_component<=0; public_index<=0; public_word<=0; public_byte_index<=0;
            validate_index<=0; rsa_length_hi<=0; rsa_message_length<=0; validation_failed<=0;
            sticky_state<=0; sticky_detail<=0;
        end else begin
            response_valid_o<=0;
            if(state!=IDLE && state!=SCRUB && state!=SCRUB_LATCH && state!=RECOVERY) elapsed<=elapsed+1'b1;
            if(aes_output_fire || rsa_output_fire) output_count<=output_count+1'b1;
            if(state!=SCRUB && state!=SCRUB_LATCH && state!=RECOVERY &&
               (gen_recovery_required_i || aes_recovery_required_i || rsa_recovery_required_i ||
                (state!=IDLE && elapsed>=DEADLINE_CYCLES) ||
                (worker_active && ((opcode==2 && aes_output_valid_i && output_count>=data_length) ||
                                   (opcode==4 && rsa_output_valid_i && output_count>=256))))) recover;
            else case(state)
                SCRUB: if(scrub_index==1023) begin scrub_index<=0; latch_count<=0; state<=SCRUB_LATCH; end
                    else scrub_index<=scrub_index+1'b1;
                SCRUB_LATCH: if(latch_count==2) state<=scrub_for_reply ? ANNOUNCE : IDLE;
                    else latch_count<=latch_count+1'b1;
                IDLE: if(start_i) begin
                    request_size<=command_size_i; command_addr_o<=10; prefix<=0; opcode<=0;
                    request_id<=0; request_handle<=0; reply_handle<=0; response_code_o<=0;
                    operation_status<=0; cleanup_status<=0; body_length<=0; result_length<=0;
                    elapsed<=0; scrub_for_reply<=0; field_index<=0; data_index<=0; output_count<=0;
                    input_index<=0; iv<=0; final_iv<=0; aes_key<=0; worker_active<=0;
                    sticky_state<=0; sticky_detail<=0;
                    if(command_tag_i!=16'h8001) fail(32'h01e);
                    else if(!operational_i) fail(32'h100);
                    else if(command_size_i<26 || command_size_i>1068) fail(32'h095);
                    else state<=PREFIX_WAIT;
                end
                PREFIX_WAIT: state<=PREFIX_BYTE;
                PREFIX_BYTE: begin
                    prefix<=next_prefix; command_addr_o<=command_addr_o+1'b1;
                    if(command_addr_o==25) begin
                        opcode<=next_prefix[119:112]; request_id<=next_prefix[95:64];
                        request_handle<=next_prefix[63:32]; reply_handle<=next_prefix[63:32];
                        if(next_prefix[127:120]!=2 || next_prefix[31:0]!=0 || next_prefix[119:112]>5 ||
                           next_prefix[111:96]!=(next_prefix[119:112]==1 ? 16'd1 : 16'd0) ||
                           ((next_prefix[119:112]==0 || next_prefix[119:112]==1 || next_prefix[119:112]==3 || next_prefix[119:112]==5) &&
                            (next_prefix[63:32]!=0 || request_size!=26))) fail(32'h095);
                        else state<=DISPATCH;
                    end else state<=PREFIX_WAIT;
                end
                DISPATCH: begin
                    case(opcode)
                        0: begin body_length<=24; state<=SUCCEED; end
                        1,3: begin
                            if(opcode==1 && !DEMO_AES_EXPORT_ENABLE) fail(32'h12f);
                            else state<=owned_handle!=0 ? RELEASE_SEND : GEN_SEND;
                        end
                        2,4: begin
                            if(request_handle==0 || request_handle!=owned_handle) fail(32'h18b);
                            else if((opcode==2 && (owned_profile!=1 || !aes_use_allowed_o)) ||
                                    (opcode==4 && (owned_profile!=2 || !rsa_use_allowed_o))) fail(32'h12f);
                            else if((opcode==2 && request_size<44) || (opcode==4 && request_size!=284)) fail(32'h095);
                            else begin field_index<=0; state<=opcode==2 ? IV_WAIT : LEN_WAIT; end
                        end
                        5: begin
                            reply_status_word<=snapshot_status_word_i; reply_status_id<=snapshot_operation_id_i;
                            reply_status_sequence<=snapshot_sequence_i; body_length<=12; state<=SUCCEED;
                        end
                        default: fail(32'h12f);
                    endcase
                end
                IV_WAIT: state<=IV_BYTE;
                IV_BYTE: begin
                    iv<={iv[119:0],command_byte_i}; command_addr_o<=command_addr_o+1'b1;
                    if(field_index==15) begin field_index<=0; state<=LEN_WAIT; end
                    else begin field_index<=field_index+1'b1; state<=IV_WAIT; end
                end
                LEN_WAIT: state<=LEN_BYTE;
                LEN_BYTE: begin
                    command_addr_o<=command_addr_o+1'b1;
                    if(field_index==0) begin length_hi<=command_byte_i; field_index<=1; state<=LEN_WAIT; end
                    else begin
                        data_length<={length_hi,command_byte_i}; data_index<=0;
                        if((opcode==2 && ({length_hi,command_byte_i}>1024 || request_size!=44+{length_hi,command_byte_i})) ||
                           (opcode==4 && {length_hi,command_byte_i}!=256)) fail(32'h095);
                        else state<= {length_hi,command_byte_i}==0 ? KEY_SEND : DATA_WAIT;
                    end
                end
                DATA_WAIT: state<=DATA_BYTE;
                DATA_BYTE: begin
                    command_addr_o<=command_addr_o+1'b1;
                    if(data_index+1==data_length) state<=opcode==2 ? KEY_SEND : RSA_JOB;
                    else begin data_index<=data_index+1'b1; state<=DATA_WAIT; end
                end
                RELEASE_SEND: if(release_ready_i) begin
                    aes_use_allowed_o<=0; rsa_use_allowed_o<=0; state<=RELEASE_WAIT;
                end
                RELEASE_WAIT: if(release_rsp_valid_i) begin
                    if(release_rsp_code_i!=0) fail(release_rsp_code_i);
                    else begin owned_handle<=0; owned_profile<=0; state<=GEN_SEND; end
                end
                GEN_SEND: if(gen_job_ready_i) state<=GEN_WAIT;
                GEN_WAIT: if(gen_done_valid_i && gen_scrub_done_i) begin
                    last_gen_cycles<=gen_done_cycles_i;
                    if(gen_done_id_i!=request_id || gen_done_profile_i!=gen_job_profile_o || gen_done_mode_i!=DEMO_PROVIDER_MODE) recover;
                    else if(!successful_gen) begin
                        aes_use_allowed_o<=0; rsa_use_allowed_o<=0;
                        operation_status<={24'd0,gen_done_setup_error_i,gen_done_core_status_i};
                        cleanup_status<={28'd0,gen_done_teardown_error_i};
                        fail(gen_done_setup_error_i==2 || gen_done_setup_error_i==3 ? 32'h922 : 32'h101);
                    end else begin
                        owned_handle<=gen_done_handle_i; reply_handle<=gen_done_handle_i; owned_profile<=gen_done_profile_i;
                        aes_use_allowed_o<=opcode==1; rsa_use_allowed_o<=opcode==3;
                        if(opcode==1) state<=KEY_SEND;
                        else begin public_component<=0; public_index<=0; state<=PUB_SEND; end
                    end
                end
                KEY_SEND: if(key_request_ready_i) state<=KEY_WAIT;
                KEY_WAIT: if(key_reply_valid_i) begin
                    if(key_reply_code_i!=0) begin aes_use_allowed_o<=0; fail(key_reply_code_i); end
                    else begin
                        aes_key<=resolved_key_i;
                        if(opcode==1) begin body_length<=32; sticky_state<=5; state<=SUCCEED; end
                        else state<=AES_JOB;
                    end
                end
                AES_JOB: if(aes_job_ready_i) begin
                    aes_key<=0; input_index<=0; output_count<=0; worker_active<=1;
                    state<=data_length==0 ? WORK_WAIT : STREAM_ADDR;
                end
                RSA_JOB: if(rsa_job_ready_i) begin
                    input_index<=0; output_count<=0; worker_active<=1; state<=STREAM_ADDR;
                end
                STREAM_ADDR: begin internal_read_addr<=input_index[9:0]; state<=STREAM_WAIT; end
                STREAM_WAIT: state<=STREAM_SEND;
                STREAM_SEND: if(aes_mode ? aes_input_ready_i : rsa_input_ready_i) begin
                    if(input_index+1==data_length) state<=WORK_WAIT;
                    else begin input_index<=input_index+1'b1; state<=STREAM_ADDR; end
                end
                WORK_WAIT: begin
                    if(aes_mode && aes_status_valid_i && aes_scrub_done_i) begin
                        worker_active<=0; last_aes_cycles<=aes_status_cycles_i;
                        if(aes_status_code_i!=0) fail(aes_status_code_i);
                        else if(aes_status_result_bytes_i!=data_length || completed_output_count!=data_length) recover;
                        else begin
                            result_length<=data_length; final_iv<=aes_status_iv_i;
                            body_length<=18+data_length; sticky_state<=8; sticky_detail<=2; state<=SUCCEED;
                        end
                    end else if(!aes_mode && rsa_status_valid_i) begin
                        worker_active<=0; last_rsa_cycles<=rsa_status_cycles_i;
                        if(rsa_status_id_i!=request_id) recover;
                        else if(rsa_status_code_i!=0) fail(rsa_status_code_i);
                        else if(rsa_status_result_bytes_i!=256 || completed_output_count!=256) recover;
                        else begin
                            validate_index<=0; rsa_message_length<=0; rsa_length_hi<=0;
                            validation_failed<=0; state<=VALIDATE_ADDR;
                        end
                    end
                end
                PUB_SEND: if(public_request_ready_i) state<=PUB_WAIT;
                PUB_WAIT: if(public_reply_valid_i) begin
                    if(public_reply_code_i!=0) begin rsa_use_allowed_o<=0; fail(public_reply_code_i); end
                    else if((!public_component && public_index==0 && !public_data_i[31]) ||
                            (!public_component && public_index==63 && !public_data_i[0]) ||
                            (public_component && public_data_i!=32'h00010001)) begin rsa_use_allowed_o<=0; fail(32'h101); end
                    else begin public_word<=public_data_i; public_byte_index<=0; state<=PUB_WRITE; end
                end
                PUB_WRITE: if(public_byte_index==3) begin
                    public_word<=0;
                    if(public_component) begin body_length<=264; sticky_state<=5; state<=SUCCEED; end
                    else if(public_index==63) begin public_component<=1; public_index<=0; state<=PUB_SEND; end
                    else begin public_index<=public_index+1'b1; state<=PUB_SEND; end
                end else public_byte_index<=public_byte_index+1'b1;
                VALIDATE_ADDR: begin internal_read_addr<=validate_index[7:0]; state<=VALIDATE_WAIT; end
                VALIDATE_WAIT: state<=VALIDATE_BYTE;
                VALIDATE_BYTE: begin
                    case(validate_index)
                        0: if(internal_read_data!=0) validation_failed<=1;
                        1: if(internal_read_data!=8'h44) validation_failed<=1;
                        2: if(internal_read_data!=8'h45) validation_failed<=1;
                        3: if(internal_read_data!=8'h32) validation_failed<=1;
                        4: if(internal_read_data!=8'h35) validation_failed<=1;
                        5: rsa_length_hi<=internal_read_data;
                        6: begin
                            rsa_message_length<={rsa_length_hi,internal_read_data};
                            if({rsa_length_hi,internal_read_data}>240) validation_failed<=1;
                        end
                        default: if(validate_index>=7+rsa_message_length && internal_read_data!=0) validation_failed<=1;
                    endcase
                    if(validate_index==255) begin
                        if(validation_failed || (validate_index>=7+rsa_message_length && internal_read_data!=0)) fail(32'h095);
                        else begin
                            result_length<=rsa_message_length; body_length<=2+rsa_message_length;
                            sticky_state<=8; sticky_detail<=4; state<=SUCCEED;
                        end
                    end else begin validate_index<=validate_index+1'b1; state<=VALIDATE_ADDR; end
                end
                SUCCEED: state<=ANNOUNCE;
                ANNOUNCE: begin response_valid_o<=1; state<=HOLD; end
                HOLD: if(response_consumed_i) begin
                    aes_key<=0; iv<=0; final_iv<=0; prefix<=0; public_word<=0;
                    internal_read_addr<=0; scrub_index<=0; scrub_for_reply<=0; state<=SCRUB;
                end
                RECOVERY: begin end
                default: recover;
            endcase
        end
    end
endmodule
`default_nettype wire
