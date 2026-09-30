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
    keygen_aes_backend backend(.*);
    keygen_dispatch_adapter #(.EXTERNAL_BACKEND(1)) adapter(
        .clock(clock),.reset_n(reset_n),.start(start),.descriptor_valid(1'b1),
        .session_validated(1'b1),.command_code(32'h153),.descriptor_id(32'd5),
        .descriptor_alg(2'd1),.descriptor_bits(bits),.descriptor_mode(2'd0),
        .descriptor_context(32'd9),.descriptor_destination(32'd10),.descriptor_exponent(32'd0),
        .cancel(cancel),.busy(adapter_busy),.terminal_valid(terminal_valid),
        .terminal_ready(terminal_ready),.terminal_code(terminal_code),.terminal_object(terminal_object),
        .req_valid(req_valid),.req_ready(req_ready),.req_id(req_id),.req_alg(req_alg),
        .req_bits(req_bits),.req_mode(req_mode),.req_context(req_context),
        .req_destination(req_destination),.req_exponent(req_exponent),
        .cancel_valid(cancel_valid),.cancel_ready(cancel_ready),.cancel_id(cancel_id),
        .rsp_valid(rsp_valid),.rsp_ready(rsp_ready),.rsp_id(rsp_id),.rsp_fail(rsp_fail),
        .rsp_code(rsp_code),.rsp_object(rsp_object)
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
