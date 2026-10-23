// RNG.v
//
// Top-level module that connects:
// entropy_source -> future Hash.v placeholder -> random_number_generation
//                -> tpm2_get_random (TPM2_GetRandom command)
//
// Hash.v is intentionally not implemented yet. For now, entropy_output is
// passed directly into random_number_generation through hash_output_placeholder
// so this top-level module compiles.
//
// The host talks to the TPM over two 8-bit byte streams: it sends a
// TPM2_GetRandom command frame on cmd_*, and the response frame comes back on
// rsp_*. Random bytes leave the chip only inside a TPM2_GetRandom response,
// never on their own.
//
// Written by Jungyeon Won with the help of generative AI
 
`timescale 1ns/1ps
 
module RNG (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        enable,
 
    // TPM command in
    input  wire [7:0]  cmd_data,
    input  wire        cmd_valid,
    input  wire        cmd_last,
    output wire        cmd_ready,
 
    // TPM response out
    output wire [7:0]  rsp_data,
    output wire        rsp_valid,
    output wire        rsp_last,
    input  wire        rsp_ready
);
 
    wire [255:0] entropy_output;
    wire         entropy_valid;
 
    wire [255:0] hash_output_placeholder;
    wire         hash_valid_placeholder;
    wire [255:0] random_output_internal;
    wire         random_valid_internal;
 
    entropy_source u_entropy_source (
        .clk           (clk),
        .rst_n         (rst_n),
        .enable        (enable),
        .entropy_output(entropy_output),
        .entropy_valid (entropy_valid)
    );
 
    // Future Hash.v connection:
    //
    // Hash u_hash (
    //     .clk        (clk),
    //     .rst_n      (rst_n),
    //     .enable     (entropy_valid),
    //     .hash_input (entropy_output),
    //     .hash_output(hash_output_placeholder),
    //     .hash_valid (hash_valid_placeholder)
    // );
    //
    // Placeholder passthrough until Hash.v is implemented.
    assign hash_output_placeholder = entropy_output;
    assign hash_valid_placeholder  = entropy_valid;
 
    random_number_generation u_random_number_generation (
        .clk          (clk),
        .rst_n        (rst_n),
        .enable       (hash_valid_placeholder),
        .hash_input   (hash_output_placeholder),
        .random_output(random_output_internal),
        .random_valid (random_valid_internal)
    );
 
    tpm2_get_random u_tpm2_get_random (
        .clk            (clk),
        .rst_n          (rst_n),
        .cmd_data       (cmd_data),
        .cmd_valid      (cmd_valid),
        .cmd_last       (cmd_last),
        .cmd_ready      (cmd_ready),
        .rsp_data       (rsp_data),
        .rsp_valid      (rsp_valid),
        .rsp_last       (rsp_last),
        .rsp_ready      (rsp_ready),
        .rng_data       (random_output_internal),
        .rng_valid      (random_valid_internal),
        .tpm_initialized(1'b1),   // drive from TPM2_Startup once it exists
        .rng_fault      (1'b0)    // drive from health tests once they exist
    );
 
endmodule
 