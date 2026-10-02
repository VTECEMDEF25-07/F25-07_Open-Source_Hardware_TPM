//////////////////////////////////////////
// Filename: aes.v
// Author
// Date
// Version
// Description
//
//
//////////////////////////////////////

module aes (
    input wire        clock_i,
    input wire        reset_n_i,
    input wire        init_i, // start expanding the supplied key nto AES round keys
    input wire        next_i, // start processing one block using the initialized key
   // input wire        aes_encrypt_i, // 1 selects AES encryption; 0 selects decryption
    input wire        keylen_i, // 0 means AES-128; 1 means AES-256

    input wire [255:0] key_i,
    input wire [127:0] block_i,

    output wire        ready_o, // core is idle; it also starts high after reset
    output wire        result_valid_o, // a completed block result is available. It remains high until cleared by a subsequent operation or reset
    output wire [127:0] block_o
);

    aes_core UNIT_AES_CORE (
        .clk (clock_i),
        .reset_n (reset_n_i),

        .encdec (1'b1), // or aes_encrypt_i if we implement ECB
        .init (init_i),
        .next (next_i),
        .ready (ready_o),
        .key (key_i),
        .keylen (keylen_i),
        .block (block_i),
        .result (block_o),
        .result_valid (result_valid_o)
    );
endmodule