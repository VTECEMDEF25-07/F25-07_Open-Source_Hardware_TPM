`timescale 1ns/1ps
// CONTROL-MODEL TEST ONLY. No RNG, AES, RSA or key-generation correctness claim.
module tb_customer_crypto_subsystem_control;
    reg clock=0; always #10 clock=~clock;
    reg reset_n=0,recovery=0,start=0,operational=1;
    wire [11:0] command_addr,response_length;
    wire response_valid,busy,scrubbed,recovery_required,job_accept,commit;
    wire [31:0] response_code,job_id,commit_handle,status_word,status_id,status_sequence;
    wire [7:0] response_byte;
    wire [511:0] metrics;
    wire legacy_ready,legacy_valid; wire [255:0] legacy_key; wire [31:0] legacy_code;
    customer_crypto_subsystem #(.DEMO_PROVIDER_MODE(1),.DEMO_AES_EXPORT_ENABLE(1)) dut (
        .clock_i(clock),.reset_n_i(reset_n),.recovery_pending_i(recovery),.start_i(start),.operational_i(operational),
        .command_tag_i(16'h8001),.command_size_i(32'd26),.command_addr_o(command_addr),.command_byte_i(8'h9a),
        .response_valid_o(response_valid),.response_code_o(response_code),.response_length_o(response_length),
        .response_addr_i(12'h345),.response_byte_o(response_byte),.response_consumed_i(1'b0),
        .busy_o(busy),.scrub_done_o(scrubbed),.recovery_required_o(recovery_required),
        .aes_client_active_i(1'b1),.key_request_i(1'b1),.key_request_ready_o(legacy_ready),.key_handle_i(32'hbad0),
        .key_reply_valid_o(legacy_valid),.key_reply_ready_i(1'b1),.resolved_key_o(legacy_key),.key_reply_code_o(legacy_code),
        .supervisor_recovered_i(1'b1),.supervisor_last_id_i(32'hdead),.supervisor_last_handle_i(32'hbeef),
        .supervisor_last_committed_i(1'b1),.supervisor_last_reason_i(4'hf),
        .job_accept_o(job_accept),.job_id_o(job_id),.commit_o(commit),.commit_handle_o(commit_handle),
        .snapshot_status_word_o(status_word),.snapshot_operation_id_o(status_id),.snapshot_sequence_o(status_sequence),
        .metrics_snapshot_o(metrics));
    integer checks=0,i; reg [31:0] held_sequence;
    task check(input bit condition,input string label);
        begin checks++;if(!condition)$fatal(1,"CONTROL %s",label);end
    endtask
    task step;begin @(posedge clock);#1;end endtask
    function [31:0] word_at(input integer index);word_at=metrics[index*32 +:32];endfunction
    task idle_models;
        begin
            dut.u_packet.scrub_done_o=1;
            dut.u_operation.available_o=1;dut.u_operation.scrub_done_o=1;
            dut.u_store.receiver_scrub_done_o=1;
            dut.u_aes.scrub_done_o=1;
        end
    endtask
    initial begin
        repeat(2)step;reset_n=1;idle_models;repeat(3)step;
        check(dut.u_operation.ENTROPY_WARMUP_CYCLES==4096 && dut.u_operation.ENTROPY_SAMPLE_DIV==1024,"explicit promoted customer entropy profile");
        check(dut.u_packet.operational_i,"startup readiness reaches packet");
        check(!busy && scrubbed,"idle aggregate");
        check(!legacy_ready && !legacy_valid && legacy_key==0 && legacy_code==0,"legacy lookup disabled");
        check(metrics==0,"metrics reset");
        dut.u_packet.command_addr_o=12'h3ab;dut.u_packet.response_valid_o=1;
        dut.u_packet.response_code_o=32'h095;dut.u_packet.response_length_o=12'h043;dut.u_packet.response_byte_o=8'h5c;#1;
        check(command_addr==12'h3ab && dut.u_packet.command_byte_i==8'h9a,"command facade bytes");
        check(response_valid && response_code==32'h095 && response_length==12'h043 && response_byte==8'h5c,"payload-only response facade");
        check(dut.u_packet.response_addr_i==12'h345,"response address facade");
        dut.u_packet.status_valid_o=1;dut.u_packet.status_code_o=5;dut.u_packet.status_detail_o=8'h12;
        dut.u_packet.status_operation_id_o=32'habcd;step;
        check(status_word[3:0]==5 && status_word[7] && status_word[5:4]==1 && status_word[23:16]==8'h12 && status_id==32'habcd,"actual status tuple");
        held_sequence=status_sequence;repeat(4)step;
        check(status_sequence==held_sequence,"no synthetic timed status changes");
        dut.u_packet.status_code_o=7;step;
        check(status_sequence==held_sequence+1 && status_word[3:0]==7,"actual changed status sequence");
        dut.u_operation.release_valid_o=1;dut.u_operation.release_handle_o=32'ha001;
        dut.u_packet.release_valid_o=1;dut.u_packet.release_handle_o=32'hb002;dut.u_store.release_ready_o=1;#1;
        check(dut.u_store.release_valid_i && dut.u_store.release_handle_i==32'ha001 && dut.u_operation.release_ready_i && !dut.u_packet.release_ready_i,"operation release priority");
        step;dut.u_operation.release_valid_o=0;dut.u_packet.release_valid_o=0;
        dut.u_store.release_rsp_valid_o=1;dut.u_store.release_rsp_code_o=32'h18b;
        dut.u_operation.release_rsp_ready_o=0;dut.u_packet.release_rsp_ready_o=1;#1;
        check(dut.u_operation.release_rsp_valid_i && !dut.u_packet.release_rsp_valid_i && !dut.u_store.release_rsp_ready_i && dut.u_operation.release_rsp_code_i==32'h18b,"release owner held under stalls");
        dut.u_operation.release_rsp_ready_o=1;#1;check(dut.u_store.release_rsp_ready_i,"operation release acknowledgement");
        step;dut.u_store.release_rsp_valid_o=0;dut.u_packet.release_valid_o=1;step;
        dut.u_packet.release_valid_o=0;dut.u_store.release_rsp_valid_o=1;#1;
        check(dut.u_packet.release_rsp_valid_i && !dut.u_operation.release_rsp_valid_i && dut.u_store.release_rsp_ready_i,"packet release ownership");
        step;dut.u_store.release_rsp_valid_o=0;
        dut.u_packet.key_request_o=1;dut.u_packet.key_handle_o=32'h81234567;
        dut.u_store.key_request_ready_o=1;dut.u_store.key_reply_valid_o=1;
        dut.u_store.resolved_key_o=256'h0123456789abcdef00112233445566778899aabbccddeefffedcba9876543210;
        dut.u_store.key_reply_code_o=0;dut.u_packet.key_reply_ready_o=1;
        dut.u_packet.aes_use_allowed_o=1;dut.u_packet.aes_client_active_o=1;#1;
        check(dut.u_store.key_request_i && dut.u_store.key_handle_i==32'h81234567 && dut.u_packet.key_request_ready_i && dut.u_packet.key_reply_valid_i,"packet key lookup handshake");
        check(dut.u_packet.resolved_key_i==dut.u_store.resolved_key_o && dut.u_store.key_reply_ready_i && dut.u_store.use_allowed_i && dut.u_store.client_active_i,"protected AES lookup payload and ownership");
        dut.u_packet.public_request_o=1;dut.u_packet.public_handle_o=32'h8a000001;
        dut.u_packet.public_component_o=1;dut.u_packet.public_index_o=0;dut.u_packet.public_reply_ready_o=1;
        dut.u_store.public_request_ready_o=1;dut.u_store.public_reply_valid_o=1;dut.u_store.public_data_o=65537;dut.u_store.public_reply_code_o=0;#1;
        check(dut.u_store.public_request_i && dut.u_store.public_component_i && dut.u_store.public_index_i==0 && dut.u_store.public_handle_i==32'h8a000001,"public n/e request fields");
        check(dut.u_packet.public_data_i==65537 && dut.u_packet.public_reply_valid_i && dut.u_store.public_reply_ready_i,"public n/e reply fields");
        dut.u_packet.aes_job_valid_o=1;dut.u_aes.job_ready_o=1;dut.u_packet.job_id_o=32'ha001;
        dut.u_packet.aes_job_key_o=dut.u_store.resolved_key_o;
        dut.u_packet.aes_job_iv_o=128'hfedcba98765432100123456789abcdef;dut.u_packet.aes_job_bytes_o=1024;#1;
        check(dut.u_aes.job_valid_i && dut.u_aes.job_key_i==dut.u_packet.aes_job_key_o && dut.u_aes.job_iv_i==dut.u_packet.aes_job_iv_o && dut.u_aes.job_bytes_i==1024,"AES descriptor width and key ordering");
        step;dut.u_packet.aes_job_valid_o=0;dut.u_aes.job_ready_o=0;dut.u_packet.job_id_o=32'hbadbad;
        dut.u_aes.busy_o=1;dut.u_aes.status_valid_o=1;dut.u_aes.status_code_o=0;
        dut.u_aes.status_cycles_o=64'h1234567890abcdef;dut.u_aes.status_result_bytes_o=1024;
        dut.u_aes.status_iv_o=128'h1234;dut.u_packet.aes_status_ready_o=0;
        repeat(3)step;check(word_at(0)==0 && busy,"held AES terminal does not update metric");
        dut.u_packet.aes_status_ready_o=1;step;
        check(word_at(0)==1 && word_at(15)==1 && word_at(1)==32'h90abcdef && word_at(2)==32'h12345678 && word_at(9)==32'ha001 && word_at(10)==0,"AES 64-bit terminal metric and accepted job ID");
        dut.u_aes.status_valid_o=0;dut.u_packet.aes_status_ready_o=0;dut.u_aes.busy_o=0;
        dut.u_packet.rsa_job_valid_o=1;dut.u_rsa.job_ready_o=1;
        dut.u_packet.rsa_job_id_o=32'hb003;dut.u_packet.rsa_key_handle_o=32'h8a000001;dut.u_packet.rsa_ciphertext_bytes_o=256;#1;
        check(dut.u_rsa.job_valid_i && dut.u_rsa.job_id_i==32'hb003 && dut.u_rsa.key_handle_i==32'h8a000001 && dut.u_rsa.ciphertext_bytes_i==256,"RSA descriptor fields");
        step;dut.u_packet.rsa_job_valid_o=0;dut.u_rsa.job_ready_o=0;dut.u_rsa.busy_o=1;dut.u_rsa.rsa_client_active_o=1;
        dut.u_rsa.private_request_o=1;dut.u_rsa.private_handle_o=32'h8a000001;dut.u_rsa.private_component_o=1;dut.u_rsa.private_index_o=63;
        dut.u_store.private_request_ready_o=0;dut.u_packet.rsa_use_allowed_o=1;#1;
        check(dut.u_store.private_request_i && dut.u_store.private_component_i && dut.u_store.private_index_i==63 && dut.u_store.private_handle_i==32'h8a000001 && !dut.u_rsa.private_request_ready_i,"private d word index unchanged under stall");
        check(dut.u_store.rsa_client_active_i && dut.u_store.rsa_use_allowed_i,"private store lease ownership");
        dut.u_store.private_request_ready_o=1;#1;check(dut.u_rsa.private_request_ready_i,"private typed request ready");step;
        dut.u_rsa.private_request_o=0;dut.u_store.private_reply_valid_o=1;dut.u_store.private_data_o=32'hdeadc0de;dut.u_store.private_reply_code_o=0;
        dut.u_rsa.private_reply_ready_o=0;#1;
        check(dut.u_rsa.private_reply_valid_i && dut.u_rsa.private_data_i==32'hdeadc0de && !dut.u_store.private_reply_ready_i,"private typed reply held");
        dut.u_rsa.private_reply_ready_o=1;step;dut.u_store.private_reply_valid_o=0;
        dut.u_rsa.private_open_valid_o=1;dut.u_operation.private_open_ready_o=0;#1;
        check(dut.u_operation.private_open_valid_i && !dut.u_rsa.private_open_ready_i,"private open stall");
        dut.u_operation.private_open_ready_o=1;step;dut.u_rsa.private_open_valid_o=0;dut.u_operation.private_active_o=1;#1;
        check(busy && !scrubbed && dut.u_rsa.private_active_i,"lease blocks aggregate clean");
        dut.u_rsa.private_cmd_valid_o=1;dut.u_rsa.private_cmd_op_o=8'h13;
        dut.u_rsa.private_cmd_arg0_o=1216;dut.u_rsa.private_cmd_arg1_o=1152;dut.u_rsa.private_cmd_arg2_o=1088;dut.u_rsa.private_cmd_arg3_o=64;
        dut.u_operation.private_cmd_ready_o=1;#1;
        check(dut.u_operation.private_cmd_valid_i && dut.u_operation.private_cmd_op_i==8'h13 && dut.u_operation.private_cmd_arg0_i==1216 && dut.u_operation.private_cmd_arg1_i==1152 && dut.u_operation.private_cmd_arg2_i==1088 && dut.u_operation.private_cmd_arg3_i==64 && dut.u_rsa.private_cmd_ready_i,"sole math command and full64-limb arguments");
        step;dut.u_rsa.private_cmd_valid_o=0;dut.u_operation.private_rsp_valid_o=1;dut.u_operation.private_rsp_status_o=0;dut.u_rsa.private_rsp_ready_o=1;#1;
        check(dut.u_rsa.private_rsp_valid_i && dut.u_rsa.private_rsp_status_i==0 && dut.u_operation.private_rsp_ready_i,"sole math response");step;dut.u_operation.private_rsp_valid_o=0;
        dut.u_rsa.private_mem_write_en_o=1;dut.u_rsa.private_mem_address_o=1088;dut.u_rsa.private_mem_write_data_o=32'h12345678;dut.u_operation.private_mem_ready_o=1;#1;
        check(dut.u_operation.private_mem_write_en_i && dut.u_operation.private_mem_address_i==1088 && dut.u_operation.private_mem_write_data_i==32'h12345678 && dut.u_rsa.private_mem_ready_i,"private scratch write fields");
        step;dut.u_rsa.private_mem_write_en_o=0;dut.u_rsa.private_mem_read_en_o=1;dut.u_rsa.private_mem_address_o=1216;
        dut.u_operation.private_mem_read_valid_o=1;dut.u_operation.private_mem_read_data_o=32'hffffffff;#1;
        check(dut.u_operation.private_mem_read_en_i && dut.u_operation.private_mem_address_i==1216 && dut.u_rsa.private_mem_read_valid_i && dut.u_rsa.private_mem_read_data_i==32'hffffffff,"private synchronous read pulse and data");
        step;dut.u_rsa.private_mem_read_en_o=0;dut.u_operation.private_mem_read_valid_o=0;
        dut.u_rsa.private_close_valid_o=1;dut.u_operation.private_close_ready_o=1;dut.u_operation.private_close_rsp_valid_o=0;#1;
        check(dut.u_operation.private_close_valid_i && dut.u_rsa.private_close_ready_i && !dut.u_rsa.private_close_rsp_valid_i && !scrubbed,"close waits actual scrub acknowledgment");
        repeat(3)step;check(word_at(0)==1,"no RSA metric before scrub and terminal");
        dut.u_rsa.private_close_valid_o=0;dut.u_operation.private_active_o=0;dut.u_operation.private_close_rsp_valid_o=1;dut.u_rsa.private_close_rsp_ready_o=1;#1;
        check(dut.u_rsa.private_close_rsp_valid_i && dut.u_operation.private_close_rsp_ready_i,"actual close acknowledgment routed");step;dut.u_operation.private_close_rsp_valid_o=0;
        dut.u_rsa.status_valid_o=1;dut.u_rsa.status_id_o=32'hb003;dut.u_rsa.status_code_o=0;dut.u_rsa.status_cycles_o=64'h0000000287654321;dut.u_rsa.status_result_bytes_o=256;
        dut.u_packet.rsa_status_ready_o=0;repeat(2)step;
        check(word_at(0)==1 && !scrubbed,"held RSA terminal remains unpublished in metrics");
        dut.u_packet.rsa_status_ready_o=1;step;
        check(word_at(0)==2 && word_at(15)==2 && word_at(3)==32'h87654321 && word_at(4)==2 && word_at(7)==32'hb003 && word_at(8)==0,"RSA terminal metrics after close scrub");
        dut.u_rsa.status_valid_o=0;dut.u_packet.rsa_status_ready_o=0;dut.u_rsa.busy_o=0;dut.u_rsa.rsa_client_active_o=0;
        dut.u_packet.gen_job_valid_o=1;dut.u_packet.gen_job_id_o=32'hc004;dut.u_packet.gen_job_profile_o=2;dut.u_packet.gen_job_mode_o=1;dut.u_operation.job_ready_o=1;#1;
        check(dut.u_operation.job_valid_i && dut.u_operation.job_id_i==32'hc004 && dut.u_operation.job_profile_i==2 && dut.u_operation.job_mode_i==1,"generation descriptor");step;dut.u_packet.gen_job_valid_o=0;
        dut.u_operation.done_valid_o=1;dut.u_operation.done_id_o=32'hc004;dut.u_operation.done_cycles_o=64'h00000003ffff5555;
        dut.u_operation.done_core_status_o=4'hc;dut.u_operation.done_setup_error_o=4'hb;dut.u_operation.done_teardown_error_o=4'ha;
        dut.u_packet.gen_done_ready_o=0;repeat(2)step;check(word_at(0)==2,"generation held terminal no metric");
        dut.u_packet.gen_done_ready_o=1;step;
        check(word_at(0)==3 && word_at(15)==3 && word_at(5)==32'hffff5555 && word_at(6)==3 && word_at(11)==32'hc004 && word_at(12)==32'habc,"generation terminal raw status packing");
        dut.u_operation.done_valid_o=0;dut.u_packet.gen_done_ready_o=0;
        dut.u_packet.gen_job_valid_o=1;dut.u_packet.gen_job_id_o=32'hc005;step;dut.u_packet.gen_job_valid_o=0;
        dut.u_operation.done_valid_o=1;dut.u_packet.gen_done_ready_o=1;
        dut.u_operation.done_core_status_o=0;dut.u_operation.done_setup_error_o=0;dut.u_operation.done_teardown_error_o=0;
        dut.u_operation.done_ownership_committed_o=0;step;
        check(word_at(0)==4 && word_at(15)==4 && word_at(11)==32'hc005 && word_at(12)==32'h101,"uncommitted generation is not a successful metric");
        dut.u_operation.done_valid_o=0;dut.u_packet.gen_done_ready_o=0;
        for(i=0;i<4;i++)begin
            case(i)
                0:dut.u_packet.recovery_required_o=1;
                1:dut.u_operation.recovery_required_o=1;
                2:dut.u_aes.recovery_required_o=1;
                3:dut.u_rsa.recovery_required_o=1;
            endcase
            start=1;#1;check(recovery_required && !dut.u_packet.start_i && !dut.u_packet.operational_i,"fatal recovery blocks admission");
            dut.u_packet.recovery_required_o=0;dut.u_operation.recovery_required_o=0;dut.u_aes.recovery_required_o=0;dut.u_rsa.recovery_required_o=0;
        end
        recovery=1;dut.u_operation.private_active_o=1;#1;
        check(!dut.u_packet.start_i && !dut.u_packet.operational_i && dut.u_operation.receiver_error_i && dut.u_store.abort_i && dut.u_operation.private_active_o,"pending recovery aborts and blocks without reset/scrub deadlock");
        reset_n=0;step;check(metrics==0 && status_sequence==0 && !dut.startup_ready,"reset clears metric/status/admission ownership");
        reset_n=1;recovery=0;start=0;idle_models;repeat(3)step;
        check(dut.u_packet.operational_i && metrics==0 && !busy && scrubbed,"reset recovery reuse");
        $display("CONTROL_HUB_PASS checks=%0d scope=MOCK_SERVICES_REAL_HUB_AND_STATUS no_crypto_claim",checks);$finish;
    end
    initial begin #1000000;$fatal(1,"control hub timeout");end
endmodule
