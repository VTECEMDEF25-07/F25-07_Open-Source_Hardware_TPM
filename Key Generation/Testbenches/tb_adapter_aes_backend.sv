// AI-authored adapter -> real controller/assembler integration, test-only peers.
`timescale 1ns/1ps
module tb_adapter_aes_backend;
    reg clock=0; always #5 clock=~clock;
    reg reset_n=0,start=0,cancel=0,terminal_ready=0;
    reg [11:0] bits=128;
    wire terminal_valid,adapter_busy;
    wire [31:0] terminal_code,terminal_object;
    wire req_valid,req_ready,cancel_valid,cancel_ready,rsp_valid,rsp_ready,rsp_fail;
    wire [31:0] req_id,req_context,req_destination,req_exponent,cancel_id;
    wire [1:0] req_alg,req_mode;
    wire [11:0] req_bits;
    wire [31:0] rsp_id,rsp_code,rsp_object;
    wire busy,health_fault; wire [7:0] health_status;
    reg rng_valid=1,rng_error=0,store_available=1,store_error=0;
    wire rng_ready;integer rn=0,dn=0,bn=0;
    wire [31:0] rng_data=32'habcd1200+rn;
    reg store_begin_ready=1,store_data_ready=1,store_finish_ready=1;
    wire store_begin_valid,store_data_valid,store_data_last,store_finish_valid,store_finish_abort;
    wire [31:0] store_begin_id,store_begin_context,store_begin_destination;
    wire [1:0] store_begin_alg;
    wire [11:0] store_begin_key_bits,store_data_bits;
    wire [31:0] store_data_id,store_data_word,store_finish_id;
    wire [3:0] store_data_component;wire [6:0] store_data_index;
    reg store_rsp_valid=0;wire store_rsp_ready;
    reg [31:0] store_rsp_id=5,store_rsp_object=32'h80000042;
    reg [7:0] store_rsp_status=0;
    keygen_aes_backend backend(.clock_i(clock), .reset_n_i(reset_n), .req_valid_i(req_valid), .req_ready_o(req_ready), .req_id_i(req_id), .req_context_i(req_context), .req_destination_i(req_destination), .req_exponent_i(req_exponent), .req_alg_i(req_alg), .req_mode_i(req_mode), .req_bits_i(req_bits), .cancel_valid_i(cancel_valid), .cancel_ready_o(cancel_ready), .cancel_id_i(cancel_id), .rsp_valid_o(rsp_valid), .rsp_ready_i(rsp_ready), .rsp_id_reg_o(rsp_id), .rsp_code_reg_o(rsp_code), .rsp_object_reg_o(rsp_object), .rsp_fail_reg_o(rsp_fail), .busy_o(busy), .health_fault_reg_o(health_fault), .health_status_reg_o(health_status), .rng_data_i(rng_data), .rng_valid_i(rng_valid), .rng_error_i(rng_error), .rng_ready_o(rng_ready), .store_available_i(store_available), .store_error_i(store_error), .store_begin_valid_o(store_begin_valid), .store_begin_ready_i(store_begin_ready), .store_begin_id_o(store_begin_id), .store_begin_context_o(store_begin_context), .store_begin_destination_o(store_begin_destination), .store_begin_alg_o(store_begin_alg), .store_begin_key_bits_o(store_begin_key_bits), .store_data_valid_o(store_data_valid), .store_data_ready_i(store_data_ready), .store_data_id_o(store_data_id), .store_data_word_o(store_data_word), .store_data_component_o(store_data_component), .store_data_index_o(store_data_index), .store_data_bits_o(store_data_bits), .store_data_last_o(store_data_last), .store_finish_valid_o(store_finish_valid), .store_finish_ready_i(store_finish_ready), .store_finish_id_o(store_finish_id), .store_finish_abort_o(store_finish_abort), .store_rsp_valid_i(store_rsp_valid), .store_rsp_ready_o(store_rsp_ready), .store_rsp_id_i(store_rsp_id), .store_rsp_object_i(store_rsp_object), .store_rsp_status_i(store_rsp_status));
    keygen_dispatch_adapter #(.EXTERNAL_BACKEND(1)) adapter(
        .clock_i(clock),.reset_n_i(reset_n),.start_i(start),.descriptor_valid_i(1'b1),
        .session_validated_i(1'b1),.command_code_i(32'h153),.descriptor_id_i(32'd5),
        .descriptor_alg_i(2'd1),.descriptor_bits_i(bits),.descriptor_mode_i(2'd0),
        .descriptor_context_i(32'd9),.descriptor_destination_i(32'd10),.descriptor_exponent_i(32'd0),
        .cancel_i(cancel),.busy_o(adapter_busy),.terminal_valid_o(terminal_valid),
        .terminal_ready_i(terminal_ready),.terminal_code_reg_o(terminal_code),.terminal_object_reg_o(terminal_object),
        .req_valid_o(req_valid),.req_ready_i(req_ready),.req_id_reg_o(req_id),.req_alg_reg_o(req_alg),
        .req_bits_reg_o(req_bits),.req_mode_reg_o(req_mode),.req_context_reg_o(req_context),
        .req_destination_reg_o(req_destination),.req_exponent_reg_o(req_exponent),
        .cancel_valid_o(cancel_valid),.cancel_ready_i(cancel_ready),.cancel_id_o(cancel_id),
        .rsp_valid_i(rsp_valid),.rsp_ready_o(rsp_ready),.rsp_id_i(rsp_id),.rsp_fail_i(rsp_fail),
        .rsp_code_i(rsp_code),.rsp_object_i(rsp_object)
    );
    task tick;begin @(posedge clock);#1;end endtask
    integer n,j;
    always @(posedge clock or negedge reset_n)begin
        if(!reset_n)begin rn<=0;dn<=0;bn<=0;end
        else begin
            if(rng_valid&&rng_ready)rn<=rn+1;
            if(store_begin_valid&&store_begin_ready)begin
                bn<=bn+1;
                if(store_begin_id!==5||store_begin_context!==9||store_begin_destination!==10)
                    $fatal(1,"adapter/backend metadata mismatch");
            end
            if(store_data_valid&&store_data_ready)begin
                if(store_data_word!==(32'habcd1200+dn)||store_data_index!==dn)
                    $fatal(1,"adapter/backend data order");
                dn<=dn+1;
            end
            if(store_finish_valid&&store_finish_ready)
                if(store_finish_abort||dn!=bits/32||backend.worker.key_material!==0)
                    $fatal(1,"adapter/backend early commit");
        end
    end
    initial begin
        for(j=0;j<2;j=j+1)begin
            reset_n=0;start=0;store_rsp_valid=0;terminal_ready=0;bits=j==0?128:256;
            tick;reset_n=1;tick;start=1;
            n=0;while(!store_finish_valid&&n<80)begin tick;n=n+1;end
            if(!store_finish_valid)$fatal(1,"integration finish timeout");tick;
            repeat(4)begin tick;if(terminal_valid)$fatal(1,"adapter success before commit acknowledgment");end
            store_rsp_valid=1;tick;store_rsp_valid=0;tick;
            if(!terminal_valid||terminal_code!==0||terminal_object!==32'h80000042||
                health_fault||rn!=bits/32||dn!=bits/32)$fatal(1,"integration completion mismatch");
            repeat(3)tick;terminal_ready=1;tick;terminal_ready=0;
            repeat(3)tick;if(bn!=1||adapter_busy||busy)$fatal(1,"integration held-start replay");
        end
        $display("PASS adapter -> actual AES backend/worker, both sizes, store-ack gating and no replay");$finish;
    end
    initial begin #20000;$fatal(1,"integration timeout");end
endmodule
