// Portable AES/RSA core. No board transport, hierarchy seed or production RNG.
module keygen_core #(
    parameter RSA_SOFTCORE=0, parameter ROM_FILE="rsa_control.hex"
) (
    input wire clock_i,input wire reset_n_i,input wire peers_ready_i,
    input wire request_valid_i,output wire request_ready_o,
    input wire [1:0] request_profile_i,input wire [31:0] request_id_i,
    input wire generation_valid_i,output wire generation_ready_o,
    input wire [31:0] generation_data_i,input wire generation_failed_i,
    output wire result_valid_o,input wire result_ready_i,
    output wire [31:0] result_data_o,output wire [2:0] result_component_o,
    output wire [6:0] result_index_o,output wire result_component_last_o,result_last_o,
    output wire [31:0] result_id_o,
    input wire ownership_valid_i,output wire ownership_ready_o,input wire ownership_accept_i,
    output wire result_discard_o,
    output wire status_valid_o,input wire status_ready_i,output wire [3:0] status_code_o,
    output wire [31:0] status_id_o
);
    localparam [3:0] BOOT=0,IDLE=1,AES_START=2,AES_RUN=3,RSA_START=4,RSA_RUN=5,
        READ_REQUEST=6,READ_WAIT=7,EMIT=8,OWNERSHIP=9,RESET_ENGINE=10,SCRUB=11,STATUS=12;
    reg [1:0] reset_release_reg,profile_reg;
    reg [3:0] state_reg,status_reg;
    reg [31:0] id_reg,data_reg;
    reg [2:0] component_reg;
    reg [6:0] index_reg;
    reg discard_reg;
    wire running=reset_n_i && reset_release_reg[1];
    wire engine_reset_n=running && state_reg!=RESET_ENGINE;
    wire aes_selected=(state_reg==AES_START || state_reg==AES_RUN);
    wire rsa_unowned=(state_reg==RSA_START || state_reg==RSA_RUN || state_reg==READ_REQUEST ||
        state_reg==READ_WAIT || state_reg==EMIT || state_reg==OWNERSHIP);
    wire rsa_fault=rsa_unowned && (generation_failed_i || !peers_ready_i);
    wire engine_ready,work_ready,completion_valid,cmd_valid,cmd_ready,rsp_valid,rsp_ready;
    wire [7:0] completion_status,cmd_op,rsp_status;
    wire [31:0] cmd_arg0,cmd_arg1,cmd_arg2,cmd_arg3;
    wire engine_generation_ready,mem_ready,mem_read_valid;
    wire [31:0] mem_read_data;
    reg [11:0] mem_address;
    wire component_last=(component_reg==2) ? index_reg==63 : ((component_reg==3) ? 1'b1 : index_reg==31);
    wire aes_request_ready,aes_generation_ready,aes_result_valid,aes_component_last,aes_last;
    wire aes_ownership_ready,aes_discard,aes_status_valid;
    wire [31:0] aes_data,aes_result_id,aes_status_id;
    wire [2:0] aes_component;
    wire [6:0] aes_index;
    wire [3:0] aes_status;
    assign request_ready_o=running && state_reg==IDLE && peers_ready_i;
    assign generation_ready_o=aes_selected ? aes_generation_ready : (running && state_reg==RSA_RUN && !rsa_fault && engine_generation_ready);
    assign result_valid_o=aes_selected ? aes_result_valid : (running && state_reg==EMIT && !rsa_fault);
    assign result_data_o=aes_selected ? aes_data : (result_valid_o ? data_reg : 32'd0);
    assign result_component_o=aes_selected ? aes_component : (result_valid_o ? component_reg : 3'd0);
    assign result_index_o=aes_selected ? aes_index : (result_valid_o ? index_reg : 7'd0);
    assign result_component_last_o=aes_selected ? aes_component_last : (result_valid_o && component_last);
    assign result_last_o=aes_selected ? aes_last : (result_valid_o && component_reg==5 && component_last);
    assign result_id_o=running ? id_reg : 32'd0;
    assign ownership_ready_o=aes_selected ? aes_ownership_ready : (running && state_reg==OWNERSHIP && !rsa_fault);
    assign result_discard_o=aes_selected ? aes_discard : (running && discard_reg);
    assign status_valid_o=aes_selected ? aes_status_valid : (running && state_reg==STATUS);
    assign status_code_o=aes_selected ? aes_status : (status_valid_o ? status_reg : 4'd0);
    assign status_id_o=running ? id_reg : 32'd0;
    always @* begin
        case(component_reg)
            2: mem_address=12'd287-{5'd0,index_reg};
            4: mem_address=12'd191-{5'd0,index_reg};
            5: mem_address=12'd223-{5'd0,index_reg};
            default: mem_address=12'd0;
        endcase
    end
    always @(posedge clock_i or negedge reset_n_i) begin
        if(!reset_n_i) reset_release_reg<=0;
        else reset_release_reg<={reset_release_reg[0],1'b1};
    end
    keygen_aes_core aes (
        .clock_i(clock_i),.reset_n_i(running),.peers_ready_i(peers_ready_i),
        .request_valid_i(state_reg==AES_START),.request_ready_o(aes_request_ready),
        .request_profile_i(profile_reg),.request_id_i(id_reg),
        .generation_valid_i(generation_valid_i && aes_selected),.generation_ready_o(aes_generation_ready),
        .generation_data_i(generation_data_i),.generation_failed_i(generation_failed_i),
        .result_valid_o(aes_result_valid),.result_ready_i(result_ready_i && aes_selected),
        .result_data_o(aes_data),.result_component_o(aes_component),.result_index_o(aes_index),
        .result_component_last_o(aes_component_last),.result_last_o(aes_last),.result_id_o(aes_result_id),
        .ownership_valid_i(ownership_valid_i && aes_selected),.ownership_ready_o(aes_ownership_ready),
        .ownership_accept_i(ownership_accept_i),.result_discard_o(aes_discard),
        .status_valid_o(aes_status_valid),.status_ready_i(status_ready_i && aes_selected),
        .status_code_o(aes_status),.status_id_o(aes_status_id)
    );
    generate if(RSA_SOFTCORE) begin: softcore
        keygen_rsa_softcore #(.ROM_FILE(ROM_FILE)) controller (
            .clock_i(clock_i),.reset_n_i(engine_reset_n),.work_valid_i(state_reg==RSA_START && !rsa_fault),
            .work_ready_o(work_ready),.completion_valid_o(completion_valid),
            .completion_ready_i(state_reg==RSA_RUN && !rsa_fault),.completion_status_o(completion_status),
            .command_valid_o(cmd_valid),.command_ready_i(cmd_ready),.command_opcode_o(cmd_op),
            .command_arg0_o(cmd_arg0),.command_arg1_o(cmd_arg1),.command_arg2_o(cmd_arg2),.command_arg3_o(cmd_arg3),
            .response_valid_i(rsp_valid),.response_ready_o(rsp_ready),.response_status_i(rsp_status)
        );
    end else begin: dedicated
        keygen_rsa_controller controller (
            .clock_i(clock_i),.reset_n_i(engine_reset_n),.work_valid_i(state_reg==RSA_START && !rsa_fault),
            .work_ready_o(work_ready),.completion_valid_o(completion_valid),
            .completion_ready_i(state_reg==RSA_RUN && !rsa_fault),.completion_status_o(completion_status),
            .cmd_valid_o(cmd_valid),.cmd_ready_i(cmd_ready),.cmd_op_o(cmd_op),
            .cmd_arg0_o(cmd_arg0),.cmd_arg1_o(cmd_arg1),.cmd_arg2_o(cmd_arg2),.cmd_arg3_o(cmd_arg3),
            .rsp_valid_i(rsp_valid),.rsp_ready_o(rsp_ready),.rsp_status_i(rsp_status)
        );
    end endgenerate
    keygen_rsa_engine engine (
        .clock_i(clock_i),.reset_n_i(engine_reset_n),.ready_o(engine_ready),
        .cmd_valid_i(cmd_valid),.cmd_ready_o(cmd_ready),.cmd_op_i(cmd_op),
        .cmd_arg0_i(cmd_arg0),.cmd_arg1_i(cmd_arg1),.cmd_arg2_i(cmd_arg2),.cmd_arg3_i(cmd_arg3),
        .rsp_valid_o(rsp_valid),.rsp_ready_i(rsp_ready),.rsp_status_o(rsp_status),
        .generation_valid_i(generation_valid_i && state_reg==RSA_RUN && !rsa_fault),.generation_ready_o(engine_generation_ready),
        .generation_data_i(generation_data_i),.generation_failed_i(generation_failed_i),
        .mem_read_en_i(state_reg==READ_REQUEST && component_reg!=3 && !rsa_fault),.mem_address_i(mem_address),
        .mem_ready_o(mem_ready),.mem_read_valid_o(mem_read_valid),.mem_read_data_o(mem_read_data)
    );
    always @(posedge clock_i or negedge reset_n_i) begin
        if(!reset_n_i) begin
            state_reg<=BOOT;profile_reg<=0;status_reg<=0;id_reg<=0;data_reg<=0;
            component_reg<=0;index_reg<=0;discard_reg<=0;
        end else if(running) begin
            if(rsa_fault) begin
                status_reg<=generation_failed_i ? 4'd2 : 4'd8;
                discard_reg<=1;data_reg<=0;state_reg<=RESET_ENGINE;
            end else case(state_reg)
                BOOT: if(engine_ready && work_ready && aes_request_ready) state_reg<=IDLE;
                IDLE: if(request_valid_i && request_ready_o) begin
                    profile_reg<=request_profile_i;id_reg<=request_id_i;status_reg<=0;
                    discard_reg<=0;data_reg<=0;index_reg<=0;component_reg<=2;
                    if(request_profile_i<=1) state_reg<=AES_START;
                    else if(request_profile_i==2) state_reg<=RSA_START;
                    else begin status_reg<=1;state_reg<=RESET_ENGINE;end
                end
                AES_START: if(aes_request_ready) state_reg<=AES_RUN;
                AES_RUN: if(aes_status_valid && status_ready_i) state_reg<=IDLE;
                RSA_START: if(work_ready && engine_ready) state_reg<=RSA_RUN;
                RSA_RUN: if(completion_valid) begin
                    if(completion_status==0) begin component_reg<=2;index_reg<=0;state_reg<=READ_REQUEST;end
                    else begin status_reg<=completion_status[3:0];discard_reg<=1;state_reg<=RESET_ENGINE;end
                end
                READ_REQUEST: begin
                    if(component_reg==3) begin data_reg<=32'd65537;state_reg<=EMIT;end
                    else if(mem_ready) state_reg<=READ_WAIT;
                end
                READ_WAIT: if(mem_read_valid) begin data_reg<=mem_read_data;state_reg<=EMIT;end
                EMIT: if(result_ready_i) begin
                    data_reg<=0;
                    if(component_last) begin
                        index_reg<=0;
                        if(component_reg==5) state_reg<=OWNERSHIP;
                        else begin component_reg<=component_reg+1'b1;state_reg<=READ_REQUEST;end
                    end else begin index_reg<=index_reg+1'b1;state_reg<=READ_REQUEST;end
                end
                OWNERSHIP: if(ownership_valid_i) begin
                    if(!ownership_accept_i) begin status_reg<=5;discard_reg<=1;end
                    data_reg<=0;state_reg<=RESET_ENGINE;
                end
                RESET_ENGINE: state_reg<=SCRUB;
                SCRUB: if(engine_ready && work_ready) state_reg<=STATUS;
                STATUS: if(status_ready_i) begin discard_reg<=0;state_reg<=IDLE;end
                default: begin status_reg<=4;discard_reg<=1;data_reg<=0;state_reg<=RESET_ENGINE;end
            endcase
        end
    end
endmodule
