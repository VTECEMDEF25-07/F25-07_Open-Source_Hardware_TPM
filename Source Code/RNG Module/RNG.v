// RNG.v
//
// Top-level module that connects:
//   entropy_source -> random_number_generation (Hash_DRBG)
//                  -> tpm2_get_random (TPM2_GetRandom command)
//
// SHA-256 is NOT computed in this module. The DRBG SENDS every message it
// needs hashed TO THE SEPARATE HASHING MODULE through the hash_* ports below,
// and the hashing module returns the 256-bit digest. Connect those ports to
// the hashing module at the next level up.
//
// The host talks to the TPM over two 8-bit byte streams: it sends a
// TPM2_GetRandom command frame on cmd_*, and the response frame comes back on
// rsp_*. Random bytes leave the chip only inside a TPM2_GetRandom response,
// never on their own.
//
// Written by Jungyeon Won with the help of generative AI

`timescale 1ns/1ps

module RNG (
    input  wire         clk,
    input  wire         rst_n,
    input  wire         enable,

    // TPM command in
    input  wire [7:0]   cmd_data,
    input  wire         cmd_valid,
    input  wire         cmd_last,
    output wire         cmd_ready,

    // TPM response out
    output wire [7:0]   rsp_data,
    output wire         rsp_valid,
    output wire         rsp_last,
    input  wire         rsp_ready,

    // ---- SENT TO THE HASHING MODULE: message byte stream ----
    output wire [7:0]   hash_msg_data,
    output wire         hash_msg_valid,
    output wire         hash_msg_last,
    input  wire         hash_msg_ready,

    // ---- RETURNED FROM THE HASHING MODULE: SHA-256 digest ----
    input  wire [255:0] hash_digest,
    input  wire         hash_digest_valid
);

    wire [255:0] entropy_output;
    wire         entropy_valid;
    wire         entropy_needed;

    wire [255:0] random_output_internal;
    wire         random_valid_internal;
    wire         rng_req;
    wire         drbg_instantiated;

    entropy_source u_entropy_source (
        .clk             (clk),
        .rst_n           (rst_n),
        .enable          (enable),
        .entropy_output  (entropy_output),
        .entropy_valid   (entropy_valid),
        .raw_sample      (),
        .raw_sample_valid()
    );

    // Hash_DRBG. Raw entropy goes straight in: Hash_df inside the DRBG is
    // the conditioning step, and its hashing is done by the hashing module.
    random_number_generation u_random_number_generation (
        .clk              (clk),
        .rst_n            (rst_n),
        .entropy_input    (entropy_output),
        .entropy_valid    (entropy_valid),
        .entropy_needed   (entropy_needed),
        .gen_req          (rng_req),
        .random_output    (random_output_internal),
        .random_valid     (random_valid_internal),
        .instantiated     (drbg_instantiated),
        // to / from the separate hashing module
        .hash_msg_data    (hash_msg_data),
        .hash_msg_valid   (hash_msg_valid),
        .hash_msg_last    (hash_msg_last),
        .hash_msg_ready   (hash_msg_ready),
        .hash_digest      (hash_digest),
        .hash_digest_valid(hash_digest_valid)
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
        .rng_req        (rng_req),
        .tpm_initialized(1'b1),   // drive from TPM2_Startup once it exists
        .rng_fault      (1'b0)    // drive from health tests once they exist
    );

endmodule
