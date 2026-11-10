// Volatile demo bytes only; never connect protected keys to this memory.
// Codex-assisted implementation of DE25_DEMO_INTERFACES v0.1 (2026-11-09).
module demo_byte_ram (
    input wire clock_i, reset_n_i,
    input wire ram_req_valid_i,
    output wire ram_req_ready_o,
    input wire ram_req_write_i,
    input wire [11:0] ram_req_addr_i,
    input wire [7:0] ram_req_wdata_i,
    output wire ram_rsp_valid_o,
    input wire ram_rsp_ready_i,
    output wire [7:0] ram_rsp_rdata_o,
    output wire ram_rsp_error_o,
    input wire access_allowed_i,
    input wire clear_valid_i,
    output wire clear_ready_o,
    output wire clear_done_valid_o,
    input wire clear_done_ready_i,
    output wire scrub_done_o
);
    reg [1:0] reset_sync;
    wire active = reset_n_i && reset_sync[1];
    always @(posedge clock_i or negedge reset_n_i)
        if (!reset_n_i) reset_sync <= 0;
        else reset_sync <= {reset_sync[0],1'b1};

    reg [7:0] bytes [0:1023];
    reg clearing, scrubbed, clear_pending, clear_done;
    reg [10:0] scrub_index;
    reg response_valid, response_error;
    reg [7:0] response_data;
    assign scrub_done_o = active && scrubbed;
    assign clear_done_valid_o = active && clear_done;
    assign clear_ready_o = active && !clearing && !response_valid && !clear_done;
    // Clear wins over a simultaneous byte request; no accepted request is lost.
    assign ram_req_ready_o = clear_ready_o && !clear_valid_i;
    assign ram_rsp_valid_o = active && response_valid;
    assign ram_rsp_rdata_o = ram_rsp_valid_o ? response_data : 8'd0;
    assign ram_rsp_error_o = ram_rsp_valid_o && response_error;

    always @(posedge clock_i or negedge reset_n_i) begin
        if (!reset_n_i) begin
            clearing <= 1; scrubbed <= 0; scrub_index <= 0;
            clear_pending <= 0; clear_done <= 0;
            response_valid <= 0; response_data <= 0; response_error <= 0;
        end else if (!active) begin
            clearing <= 1; scrubbed <= 0; scrub_index <= 0;
            clear_pending <= 0; clear_done <= 0;
            response_valid <= 0; response_data <= 0; response_error <= 0;
        end else begin
            if (response_valid && ram_rsp_ready_i) begin
                response_valid <= 0; response_data <= 0; response_error <= 0;
            end
            if (clear_done && clear_done_ready_i) clear_done <= 0;
            if (clearing) begin
                if (scrub_index < 1024) begin
                    bytes[scrub_index[9:0]] <= 0;
                    scrub_index <= scrub_index + 1'b1;
                end else begin
                    response_data <= 0; response_error <= 0;
                    clearing <= 0; scrubbed <= 1;
                    if (clear_pending) clear_done <= 1;
                    clear_pending <= 0;
                end
            end else if (clear_valid_i && clear_ready_o) begin
                clearing <= 1; scrubbed <= 0; scrub_index <= 0;
                clear_pending <= 1;
            end else if (ram_req_valid_i && ram_req_ready_o) begin
                response_valid <= 1; response_data <= 0;
                response_error <= !access_allowed_i || ram_req_addr_i >= 1024;
                if (access_allowed_i && ram_req_addr_i < 1024) begin
                    if (ram_req_write_i) begin
                        bytes[ram_req_addr_i[9:0]] <= ram_req_wdata_i;
                        scrubbed <= 0;
                    end else response_data <= bytes[ram_req_addr_i[9:0]];
                end
            end
        end
    end
endmodule
