// Standalone RAM-backed primitive integration top. The legacy symm_top session
// interface is unchanged. Production execution-engine/RAM adapters are future work.
`default_nettype none
module symmetric_ram_top #(
    parameter MAX_SYM_DATA_BYTES = 1024,
    parameter RAM_ADDR_WIDTH = 12
)(
    input wire clock_i, reset_n_i, start_i,
    input wire [255:0] key_i,
    input wire [127:0] iv_i,
    input wire decrypt_i,
    input wire [RAM_ADDR_WIDTH-1:0] input_base_i, output_base_i,
    input wire [31:0] data_length_i,
    output wire busy_o, done_o, error_o,
    output wire [11:0] tpm_rc_o,
    output wire [127:0] final_iv_o,
    output wire [31:0] completed_length_o,
    output wire ram_req_valid_o,
    input wire ram_req_ready_i,
    output wire ram_req_write_o,
    output wire [RAM_ADDR_WIDTH-1:0] ram_req_addr_o,
    output wire [7:0] ram_req_data_o,
    input wire ram_rsp_valid_i,
    output wire ram_rsp_ready_o,
    input wire [7:0] ram_rsp_data_i,
    input wire ram_rsp_error_i
);
    wire cfb_start_w, cfb_done_w, cfb_decrypt_w;
    wire [255:0] cfb_key_w;
    wire [127:0] cfb_iv_w, cfb_data_w, cfb_result_w, cfb_final_iv_w;
    wire [4:0] cfb_bytes_w;
    wire [11:0] cfb_rc_w;
    encrypt_decrypt2_ram_controller #(
        .MAX_SYM_DATA_BYTES(MAX_SYM_DATA_BYTES), .RAM_ADDR_WIDTH(RAM_ADDR_WIDTH)
    ) CONTROLLER (
        .clock_i(clock_i), .reset_n_i(reset_n_i), .start_i(start_i),
        .key_i(key_i), .iv_i(iv_i), .decrypt_i(decrypt_i),
        .input_base_i(input_base_i), .output_base_i(output_base_i), .data_length_i(data_length_i),
        .busy_o(busy_o), .done_o(done_o), .error_o(error_o), .tpm_rc_o(tpm_rc_o),
        .final_iv_o(final_iv_o), .completed_length_o(completed_length_o),
        .ram_req_valid_o(ram_req_valid_o), .ram_req_ready_i(ram_req_ready_i),
        .ram_req_write_o(ram_req_write_o), .ram_req_addr_o(ram_req_addr_o), .ram_req_data_o(ram_req_data_o),
        .ram_rsp_valid_i(ram_rsp_valid_i), .ram_rsp_ready_o(ram_rsp_ready_o),
        .ram_rsp_data_i(ram_rsp_data_i), .ram_rsp_error_i(ram_rsp_error_i),
        .cfb_start_o(cfb_start_w), .cfb_key_o(cfb_key_w), .cfb_iv_o(cfb_iv_w),
        .cfb_data_o(cfb_data_w), .cfb_bytes_o(cfb_bytes_w), .cfb_decrypt_o(cfb_decrypt_w),
        .cfb_done_i(cfb_done_w), .cfb_rc_i(cfb_rc_w),
        .cfb_data_i(cfb_result_w), .cfb_iv_i(cfb_final_iv_w)
    );
    cfb_block WORKER (
        .clock_i(clock_i), .reset_n_i(reset_n_i), .start_i(cfb_start_w),
        .key_i(cfb_key_w), .iv_i(cfb_iv_w), .data_in_i(cfb_data_w),
        .data_bytes_i(cfb_bytes_w), .decrypt_i(cfb_decrypt_w),
        .wait_o(), .done_o(cfb_done_w), .tpm_rc_o(cfb_rc_w),
        .data_out_o(cfb_result_w), .iv_out_o(cfb_final_iv_w)
    );
endmodule
`default_nettype wire
