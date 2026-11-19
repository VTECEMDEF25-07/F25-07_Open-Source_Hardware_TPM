// Phase One packet/stream adapter. Codex assisted implementation.
// Sticky health status comes from the real source monitor in the containing
// image; deterministic tests do not establish physical entropy adequacy.
module execution_engine_getrandom #(
    parameter integer WAIT_LIMIT = 1000000, parameter SHARED_SERVICE=0
)(
    input wire clock_i, reset_n_i, start_i, enabled_i, operational_i,
    input wire [31:0] command_size_i,
    output reg [11:0] command_addr_o,
    input wire [7:0] command_byte_i,
    output reg response_valid_o,
    output reg [31:0] response_code_o,
    output reg [11:0] response_length_o,
    input wire [11:0] response_addr_i,
    output wire [7:0] response_byte_o,
    input wire [255:0] random_i,
    input wire random_valid_i, fault_i,
    output wire random_request_o,
    input wire source_wait_i, output wire source_commit_o,
    output reg timeout_o
);
    localparam IDLE=0, READ_WAIT=1, FEED=2, COLLECT=3, REPLY=4;
    reg [2:0] state;
    reg [31:0] size, wait_count;
    reg [5:0] received;
    reg [7:0] reply [0:43];
    wire cmd_ready, rsp_valid, rsp_last;
    wire [7:0] rsp_data;
    wire local_reset_n = reset_n_i && state != IDLE;
    assign response_byte_o = response_addr_i < 34 ? reply[response_addr_i+10] : 0;
    tpm2_get_random handler (
        .clk(clock_i), .rst_n(local_reset_n), .cmd_data(command_byte_i),
        .cmd_valid(state == FEED), .cmd_last(command_addr_o == size-1),
        .cmd_ready(cmd_ready), .rsp_data(rsp_data), .rsp_valid(rsp_valid),
        .rsp_last(rsp_last), .rsp_ready(state == COLLECT),
        .rng_data(random_i), .rng_valid(random_valid_i && !fault_i && !timeout_o),
        .rng_req(random_request_o), .tpm_initialized(operational_i),
        .rng_fault(fault_i || timeout_o)
    );
    assign source_commit_o = reset_n_i && state==REPLY;
    integer i;
    always @(posedge clock_i or negedge reset_n_i) begin
        if (!reset_n_i) begin
            state <= IDLE; command_addr_o <= 0; size <= 0;
            response_valid_o <= 0; response_code_o <= 0; response_length_o <= 10;
            received <= 0; wait_count <= 0; timeout_o <= 0;
            for(i=0;i<44;i=i+1) reply[i] <= 0;
        end else begin
            response_valid_o <= 0;
            case(state)
                IDLE: if(start_i) begin
                    for(i=0;i<44;i=i+1) reply[i] <= 0;
                    command_addr_o <= 0; size <= command_size_i;
                    received <= 0; wait_count <= 0;
                    response_code_o <= 0; response_length_o <= 10;
                    if(!enabled_i) begin response_code_o <= 32'h143; state <= REPLY; end
                    else if(command_size_i < 10 || command_size_i > 13) begin
                        response_code_o <= 32'h142; state <= REPLY;
                    end else state <= READ_WAIT;
                end
                READ_WAIT: state <= FEED;
                FEED: if(cmd_ready) begin
                    if(command_addr_o == size-1) state <= COLLECT;
                    else begin command_addr_o <= command_addr_o+1'b1; state <= READ_WAIT; end
                end
                COLLECT: begin
                    // Bound missing seed/digest waits and latch until global reset.
                    if(!rsp_valid && !timeout_o && !(SHARED_SERVICE && source_wait_i)) begin
                        if(wait_count == WAIT_LIMIT-1) timeout_o <= 1;
                        else wait_count <= wait_count+1'b1;
                    end
                    if(rsp_valid) begin
                        reply[received] <= rsp_data;
                        received <= received+1'b1;
                        if(received >= 6 && received <= 9)
                            response_code_o <= {response_code_o[23:0],rsp_data};
                        if(rsp_last) begin
                            response_length_o <= {6'd0,received}+12'd1;
                            state <= REPLY;
                        end
                    end
                end
                REPLY: begin
                    // Commit a failure if health is revoked during collection.
                    if(enabled_i && (fault_i || timeout_o) && response_code_o == 0) begin
                        response_code_o <= 32'h101; response_length_o <= 10;
                        for(i=0;i<44;i=i+1) reply[i] <= 0;
                    end
                    response_valid_o <= 1; state <= IDLE;
                end
                default: state <= IDLE;
            endcase
        end
    end
endmodule
