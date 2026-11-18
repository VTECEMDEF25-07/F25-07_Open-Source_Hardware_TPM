// RNG owns raw-source health, sticky failure and output suppression.
// Physical entropy on the integrated image is unverified and needs later
// measurement. Simulated fault detection does not establish entropy adequacy.
// Codex assisted implementation. Production board defaults keep ENABLE=0.
module phase_one_rng #(parameter ENABLE=0)(
    input wire clk, rst_n, request_i, timeout_i,
    output wire [255:0] random_o,
    output wire valid_o, fault_o,
    output wire [7:0] hash_data_o,
    output wire hash_valid_o, hash_last_o,
    input wire hash_ready_i,
    input wire [255:0] digest_i,
    input wire digest_valid_i
);
    wire health_fault, health_ready;
    reg failed;
    always @(posedge clk or negedge rst_n)
        if(!rst_n) failed<=0;
        else if(health_fault || timeout_i) failed<=1;
    assign fault_o = health_fault || failed || timeout_i;
    generate if(ENABLE) begin : enabled
        wire [255:0] entropy_data, drbg_data;
        wire entropy_valid, raw_sample, raw_sample_valid, drbg_valid;
        entropy_source entropy (.clk(clk), .rst_n(rst_n), .enable(!fault_o),
            .entropy_output(entropy_data), .entropy_valid(entropy_valid),
            .raw_sample(raw_sample), .raw_sample_valid(raw_sample_valid));
        entropy_health health (.clk(clk), .rst_n(rst_n),
            .sample_i(raw_sample), .sample_valid_i(raw_sample_valid),
            .fault_o(health_fault), .ready_o(health_ready));
        // Keep outstanding SHA messages draining after a fault; resetting a
        // requester mid-message would strand shared SHA and break TPM2_Hash.
        random_number_generation drbg (.clk(clk), .rst_n(rst_n),
            .entropy_input(entropy_data),
            .entropy_valid(entropy_valid && health_ready && !fault_o),
            .entropy_needed(), .gen_req(request_i && !fault_o),
            .random_output(drbg_data), .random_valid(drbg_valid), .instantiated(),
            .hash_msg_data(hash_data_o), .hash_msg_valid(hash_valid_o),
            .hash_msg_last(hash_last_o), .hash_msg_ready(hash_ready_i),
            .hash_digest(digest_i), .hash_digest_valid(digest_valid_i));
        assign random_o = fault_o ? 256'd0 : drbg_data;
        assign valid_o = drbg_valid && !fault_o;
    end else begin : disabled
        assign health_fault=0; assign health_ready=0;
        assign random_o=0; assign valid_o=0;
        assign hash_data_o=0; assign hash_valid_o=0; assign hash_last_o=0;
    end endgenerate
endmodule
