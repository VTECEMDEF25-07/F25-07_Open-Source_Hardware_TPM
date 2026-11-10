// Frozen demo v0.1 operation owner. Aaron Grossman; Codex-assisted implementation.
// Secret words remain between provider, unchanged keygen_core, and protected store.
module demo_keygen_operation #(
    parameter integer DEMO_PROVIDER_MODE=1, IP_TYPE=0,
    parameter DEVICE_FAMILY="Agilex 5",
    parameter [63:0] DEADLINE_CYCLES=64'd9000000000,
    parameter [31:0] CLEANUP_CYCLES=32'd4096
) (
    input wire clock_i,reset_n_i,
    input wire job_valid_i,output wire job_ready_o,
    input wire [1:0] job_profile_i,job_mode_i,input wire [31:0] job_id_i,
    output wire done_valid_o,input wire done_ready_i,
    output reg [31:0] done_id_o,output reg [1:0] done_profile_o,done_mode_o,
    output reg [3:0] done_core_status_o,done_setup_error_o,done_teardown_error_o,
    output reg done_ownership_committed_o,output reg [31:0] done_handle_o,
    output wire busy_o,available_o,output reg recovery_required_o,
    output wire scrub_done_o,abort_o,
    output wire reserve_valid_o,input wire reserve_ready_i,
    output wire [1:0] reserve_profile_o,reserve_mode_o,output wire [31:0] reserve_id_o,
    output wire reserve_demo_use_o,
    input wire receiver_ready_i,receiver_error_i,input wire [3:0] receiver_error_code_i,
    input wire receiver_scrub_done_i,
    output wire result_valid_o,input wire result_ready_i,output wire [31:0] result_data_o,
    output wire [2:0] result_component_o,output wire [6:0] result_index_o,
    output wire result_component_last_o,result_last_o,output wire [31:0] result_id_o,
    output wire result_discard_o,
    output wire decision_valid_o,input wire decision_ready_i,output wire decision_accept_o,
    input wire ownership_valid_i,output wire ownership_ready_o,input wire ownership_accept_i,
    input wire commit_valid_i,output wire commit_ready_o,input wire [31:0] commit_handle_i,commit_id_i,
    input wire [1:0] commit_mode_i,
    output wire release_valid_o,input wire release_ready_i,output wire [31:0] release_handle_o,
    input wire release_rsp_valid_i,output wire release_rsp_ready_o,input wire [31:0] release_rsp_code_i
);
    localparam IDLE=0,VALIDATE=1,RESERVE=2,OPEN=3,OPEN_WAIT=4,REQUEST=5,RUN=6,
        CLOSE=7,CLOSE_WAIT=8,RECONCILE=9,RELEASE=10,RELEASE_WAIT=11,
        RECEIVER_CLEAR=12,ACK_CORE=13,DONE=14,RECOVERY=15;
    reg [3:0] state_reg;
    reg [1:0] reset_release_reg;
    reg reserved_reg,core_admitted_reg,source_open_reg,fault_reg,report_reg;
    reg [63:0] cycles_reg;
    reg [31:0] cleanup_cycles_reg;
    reg [13:0] boot_count_reg;
    // Existing core has no independent scrub-ready output. Its documented longest
    // reset sweep is 4098 edges plus reset synchronizers. The frozen 8192-edge
    // allowance safely covers that boot sweep without changing the core API.
    wire boot_done=boot_count_reg==14'd8192;
    wire running=reset_n_i && reset_release_reg[1];
    wire source_open_ready,source_rsp_valid,source_close_ready,source_close_valid;
    wire [3:0] source_rsp_error,source_close_error,source_fault_code;
    wire source_fault,source_ready,source_scrub,word_valid,word_ready;
    wire [31:0] word_data;
    wire core_request_ready,core_status_valid,core_ownership_ready,core_discard,core_generation_ready;
    wire [3:0] core_status;
    wire [31:0] core_status_id,core_result_data,core_result_id;
    wire core_result_valid,core_component_last,core_result_last;
    wire [2:0] core_component;wire [6:0] core_index;
    wire owns_context=state_reg!=IDLE && state_reg!=DONE && state_reg!=RECOVERY;
    wire cleaning=state_reg>=CLOSE && state_reg<=ACK_CORE;
    wire observed_fault=source_open_reg && source_fault;
    wire receiver_fault=reserved_reg && receiver_error_i;
    wire failure=(done_core_status_o!=0 || done_setup_error_o!=0 || done_teardown_error_o!=0);
    wire abort_active=owns_context && reserved_reg && (fault_reg || observed_fault || receiver_fault ||
        ((state_reg==RECONCILE || state_reg==RECEIVER_CLEAR || state_reg==ACK_CORE) && failure));
    assign abort_o=running && (abort_active || recovery_required_o);
    assign busy_o=running && state_reg!=IDLE;
    assign available_o=running && boot_done && state_reg==IDLE && source_ready && !recovery_required_o;
    assign job_ready_o=available_o;
    assign done_valid_o=running && state_reg==DONE;
    assign scrub_done_o=running && boot_done && source_scrub && (state_reg==IDLE || state_reg==DONE);
    assign reserve_valid_o=running && state_reg==RESERVE;
    assign reserve_profile_o=done_profile_o;assign reserve_mode_o=done_mode_o;
    assign reserve_id_o=done_id_o;assign reserve_demo_use_o=1'b1;
    assign result_valid_o=running && core_result_valid && !abort_o;
    assign result_data_o=result_valid_o ? core_result_data : 32'd0;
    assign result_component_o=core_component;assign result_index_o=core_index;
    assign result_component_last_o=core_component_last;assign result_last_o=core_result_last;
    assign result_id_o=core_result_id;
    assign result_discard_o=running && (core_discard || abort_o);
    assign decision_valid_o=running && state_reg==RUN && !abort_o && !done_ownership_committed_o;
    assign decision_accept_o=1'b1;
    assign ownership_ready_o=running && core_ownership_ready && !abort_o;
    assign commit_ready_o=running && owns_context && !report_reg;
    assign release_valid_o=running && state_reg==RELEASE;
    assign release_handle_o=done_handle_o;
    assign release_rsp_ready_o=running && state_reg==RELEASE_WAIT;
    assign word_ready=core_generation_ready && !abort_o && state_reg==RUN;
    demo_generation_service #(.DEMO_PROVIDER_MODE(DEMO_PROVIDER_MODE)) u_source(
        .clock_i(clock_i),.reset_n_i(reset_n_i),
        .open_valid_i(state_reg==OPEN && running),.open_ready_o(source_open_ready),
        .open_profile_i(done_profile_o),.open_id_i(done_id_o),.open_mode_i(done_mode_o),
        .open_rsp_valid_o(source_rsp_valid),.open_rsp_ready_i(state_reg==OPEN_WAIT),.open_rsp_error_o(source_rsp_error),
        .word_valid_o(word_valid),.word_ready_i(word_ready),.word_data_o(word_data),
        .context_fault_o(source_fault),.context_fault_code_o(source_fault_code),
        .close_valid_i(state_reg==CLOSE && running),.close_ready_o(source_close_ready),
        .close_id_i(done_id_o),.close_failed_i(failure),
        .close_rsp_valid_o(source_close_valid),.close_rsp_ready_i(state_reg==CLOSE_WAIT),
        .close_rsp_error_o(source_close_error),.service_ready_o(source_ready),.scrub_done_o(source_scrub));
    keygen_core #(.IP_TYPE(IP_TYPE),.DEVICE_FAMILY(DEVICE_FAMILY)) u_core(
        .clock_i(clock_i),.reset_n_i(reset_n_i),
        .peers_ready_i(source_open_reg && reserved_reg && !abort_o),
        .request_valid_i(state_reg==REQUEST && receiver_ready_i && !abort_o && running),.request_ready_o(core_request_ready),
        .request_profile_i(done_profile_o),.request_id_i(done_id_o),
        .generation_valid_i(word_valid && state_reg==RUN && !abort_o),.generation_ready_o(core_generation_ready),
        .generation_data_i(word_data),.generation_failed_i(fault_reg || observed_fault || receiver_fault),
        .result_valid_o(core_result_valid),.result_ready_i(result_ready_i && !abort_o),
        .result_data_o(core_result_data),.result_component_o(core_component),.result_index_o(core_index),
        .result_component_last_o(core_component_last),.result_last_o(core_result_last),.result_id_o(core_result_id),
        .ownership_valid_i(ownership_valid_i && !abort_o),.ownership_ready_o(core_ownership_ready),
        .ownership_accept_i(ownership_accept_i),.result_discard_o(core_discard),
        .status_valid_o(core_status_valid),.status_ready_i(state_reg==ACK_CORE),
        .status_code_o(core_status),.status_id_o(core_status_id));
    always @(posedge clock_i or negedge reset_n_i) begin
        if(!reset_n_i) reset_release_reg<=0;
        else reset_release_reg<={reset_release_reg[0],1'b1};
    end
    always @(posedge clock_i or negedge reset_n_i) begin
        if(!reset_n_i) boot_count_reg<=0;
        else if(running && !boot_done) boot_count_reg<=boot_count_reg+1'b1;
    end
    always @(posedge clock_i or negedge reset_n_i) begin
        if(!reset_n_i) begin
            state_reg<=IDLE;done_id_o<=0;done_profile_o<=0;done_mode_o<=2;
            done_core_status_o<=0;done_setup_error_o<=0;done_teardown_error_o<=0;
            done_ownership_committed_o<=0;done_handle_o<=0;recovery_required_o<=0;
            reserved_reg<=0;core_admitted_reg<=0;source_open_reg<=0;fault_reg<=0;report_reg<=0;cycles_reg<=0;cleanup_cycles_reg<=0;
        end else if(running) begin
            if(owns_context) cycles_reg<=cycles_reg+1'b1;
            if(cleaning) cleanup_cycles_reg<=cleanup_cycles_reg+1'b1;
            else cleanup_cycles_reg<=0;
            if(observed_fault || receiver_fault) begin
                fault_reg<=1;
                if(done_setup_error_o==0) done_setup_error_o<=observed_fault ?
                    ((source_fault_code==0) ? 4'd4 : source_fault_code) : 4'd2;
            end
            if(ownership_valid_i && ownership_ready_o && ownership_accept_i)
                done_ownership_committed_o<=1;
            if(commit_valid_i && commit_ready_o) begin
                report_reg<=1;done_handle_o<=commit_handle_i;
                if(commit_id_i!=done_id_o || commit_mode_i!=done_mode_o || commit_handle_i==0) begin
                    fault_reg<=1;if(done_setup_error_o==0) done_setup_error_o<=7;
                end
            end
            if(owns_context && (cycles_reg>=DEADLINE_CYCLES-1 ||
                (cleaning && cleanup_cycles_reg>=CLEANUP_CYCLES-1))) begin
                recovery_required_o<=1;done_teardown_error_o<=4;
                if(done_setup_error_o==0) done_setup_error_o<=6;
                state_reg<=RECOVERY;
            end else case(state_reg)
                IDLE: if(job_valid_i && job_ready_o) begin
                    done_id_o<=job_id_i;done_profile_o<=job_profile_i;done_mode_o<=job_mode_i;
                    done_core_status_o<=0;done_setup_error_o<=0;done_teardown_error_o<=0;
                    done_ownership_committed_o<=0;done_handle_o<=0;fault_reg<=0;report_reg<=0;
                    reserved_reg<=0;source_open_reg<=0;core_admitted_reg<=0;cycles_reg<=0;state_reg<=VALIDATE;
                end
                VALIDATE: begin
                    if(done_profile_o==3 || done_mode_o!=DEMO_PROVIDER_MODE || DEMO_PROVIDER_MODE>1) begin
                        done_setup_error_o<=1;state_reg<=DONE;
                    end else if(!reserve_ready_i) begin done_setup_error_o<=2;state_reg<=DONE;end
                    else state_reg<=RESERVE;
                end
                RESERVE: if(reserve_ready_i) begin reserved_reg<=1;state_reg<=OPEN;end
                OPEN: if(source_open_ready) state_reg<=OPEN_WAIT;
                OPEN_WAIT: if(source_rsp_valid) begin
                    if(source_rsp_error!=0) begin
                        done_setup_error_o<=source_rsp_error;fault_reg<=1;state_reg<=RECEIVER_CLEAR;
                    end else begin source_open_reg<=1;state_reg<=REQUEST;end
                end
                REQUEST: begin
                    if(abort_o) state_reg<=CLOSE;
                    else if(core_request_ready && receiver_ready_i) begin core_admitted_reg<=1;state_reg<=RUN;end
                end
                RUN: if(core_status_valid && (!done_ownership_committed_o || report_reg)) begin
                    done_core_status_o<=core_status;
                    if(core_status_id!=done_id_o && done_setup_error_o==0) done_setup_error_o<=7;
                    state_reg<=CLOSE;
                end
                CLOSE: if(source_close_ready) state_reg<=CLOSE_WAIT;
                CLOSE_WAIT: if(source_close_valid) begin
                    source_open_reg<=0;
                    if(source_close_error!=0) done_teardown_error_o<=source_close_error;
                    state_reg<=RECONCILE;
                end
                RECONCILE: begin
                    if(failure && done_ownership_committed_o) state_reg<=RELEASE;
                    else if(failure && reserved_reg) state_reg<=RECEIVER_CLEAR;
                    else if(!done_ownership_committed_o) begin
                        done_setup_error_o<=7;fault_reg<=1;state_reg<=RECEIVER_CLEAR;
                    end else state_reg<=ACK_CORE;
                end
                RELEASE: if(release_ready_i) state_reg<=RELEASE_WAIT;
                RELEASE_WAIT: if(release_rsp_valid_i) begin
                    if(release_rsp_code_i!=0) begin done_teardown_error_o<=2;recovery_required_o<=1;state_reg<=RECOVERY;end
                    else state_reg<=RECEIVER_CLEAR;
                end
                RECEIVER_CLEAR: if(receiver_scrub_done_i) begin
                    if(core_admitted_reg) state_reg<=ACK_CORE;else state_reg<=DONE;
                end
                ACK_CORE: if(core_status_valid) begin reserved_reg<=0;state_reg<=DONE;end
                DONE: if(done_ready_i) begin reserved_reg<=0;state_reg<=IDLE;end
                RECOVERY: recovery_required_o<=1;
                default: begin recovery_required_o<=1;state_reg<=RECOVERY;end
            endcase
        end
    end
    // decision_ready_i belongs to the store-mediated ownership edge; ownership_* is authoritative.
    // receiver_error_code_i is retained by the receiver; host maps this category to setup=2.
endmodule
