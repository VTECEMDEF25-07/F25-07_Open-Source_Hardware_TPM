// ===========================================================================
// random_number_generation.v
//
// Hash_DRBG, NIST SP 800-90A Rev.1 Section 10.1.1, using SHA-256.
//   security strength 256 bits, seedlen = 440 bits, outlen = 256 bits
//
// THIS MODULE DOES NOT COMPUTE SHA-256.
// Every hash this DRBG needs is SENT TO THE SEPARATE HASHING MODULE as a byte
// stream on the hash_msg_* ports, and the 256-bit digest comes back on
// hash_digest / hash_digest_valid. The hashing module is responsible for
// SHA-256 padding and compression. This module only decides WHAT to hash and
// what to do with the result.
//
// Internal state (Section 10.1.1.1):
//   V              440 bits
//   C              440 bits
//   reseed_counter 48 bits
//
// Messages SENT TO THE HASHING MODULE (|| = concatenation, sent first byte
// first, all multi-byte values big-endian):
//
//   Operation              Message sent to hashing module            Bytes
//   ---------------------  ----------------------------------------  -----------------
//   Instantiate, V (x2)    ctr || 0x000001B8 || entropy_input||nonce 5 + 32*SEED_BLOCKS
//   Reseed, V (x2)         ctr || 0x000001B8 || 0x01 || V || entropy 61 + 32*RESEED_BLOCKS
//   New C (x2)             ctr || 0x000001B8 || 0x00 || V           61
//   Generate, output       V                                         55
//   Generate, state update 0x03 || V                                 56
//
//   "(x2)" = Hash_df (Section 10.3.1): 440 output bits need two hashes,
//   ctr = 0x01 then 0x02, result = digest1 || leftmost 184 bits of digest2.
//   0x000001B8 is no_of_bits_to_return = 440.
//
// Flow:
//   reset -> collect SEED_BLOCKS entropy blocks -> instantiate -> idle
//   gen_req -> (reseed first if reseed_counter > RESEED_INTERVAL)
//           -> generate 256 bits -> random_output + random_valid pulse
//
// Entropy: entropy_input || nonce for instantiation is taken as SEED_BLOCKS
// consecutive 256-bit blocks from entropy_source (Section 8.6.7 allows a
// random nonce from the same source). Size these from the SP 800-90B
// min-entropy estimate h (bits of entropy per raw bit):
//   SEED_BLOCKS   * 256 * h >= 384   (256 entropy_input + 128 nonce)
//   RESEED_BLOCKS * 256 * h >= 256
// Defaults (3 and 2) cover h >= 0.5. Re-check after the 90B results.
//
// Request-only: GetRandom asks for at most 32 bytes, so one generate call
// returns exactly one 256-bit block. No additional_input, no personalization
// string, no prediction resistance.
//
// Written by Jungyeon Won with the help of generative AI
// ===========================================================================

`timescale 1ns/1ps

module random_number_generation #(
    parameter integer SEED_BLOCKS     = 3,        // >= 2 (entropy + nonce)
    parameter integer RESEED_BLOCKS   = 2,        // >= 1
    parameter [47:0]  RESEED_INTERVAL = 48'd1024  // generates per seed, <= 2^48
) (
    input  wire         clk,
    input  wire         rst_n,

    // ---- From entropy_source ----------------------------------------------
    input  wire [255:0] entropy_input,
    input  wire         entropy_valid,     // 1-cycle pulse per block
    output wire         entropy_needed,    // 1 while collecting seed material

    // ---- To / from tpm2_get_random ----------------------------------------
    input  wire         gen_req,           // level: "I need a block"
    output reg  [255:0] random_output,
    output reg          random_valid,      // 1-cycle pulse, data valid
    output reg          instantiated,      // 1 once the DRBG has been seeded

    // ---- SENT TO THE HASHING MODULE: message byte stream ------------------
    // A byte moves when hash_msg_valid && hash_msg_ready. hash_msg_last is
    // high with the final byte of each message.
    output wire  [7:0]  hash_msg_data,
    output wire         hash_msg_valid,
    output wire         hash_msg_last,
    input  wire         hash_msg_ready,

    // ---- RETURNED FROM THE HASHING MODULE: SHA-256 digest -----------------
    input  wire [255:0] hash_digest,
    input  wire         hash_digest_valid  // 1-cycle pulse per message
);

    // -----------------------------------------------------------------------
    // Parameter checks
    // -----------------------------------------------------------------------
    generate
        if (SEED_BLOCKS < 2) begin : bad_seed
            ERROR_SEED_BLOCKS_must_be_at_least_2 u_err();
        end
        if (RESEED_BLOCKS < 1) begin : bad_reseed
            ERROR_RESEED_BLOCKS_must_be_at_least_1 u_err();
        end
    endgenerate

    // -----------------------------------------------------------------------
    // Sizes
    // -----------------------------------------------------------------------
    localparam integer SEED_BITS   = 256 * SEED_BLOCKS;
    localparam integer RESEED_BITS = 256 * RESEED_BLOCKS;
    localparam integer ENT_BLOCKS  = (SEED_BLOCKS > RESEED_BLOCKS) ? SEED_BLOCKS
                                                                   : RESEED_BLOCKS;
    localparam integer ENT_BITS    = 256 * ENT_BLOCKS;

    localparam integer LEN_INST    = 5 + 32 * SEED_BLOCKS;       // bytes
    localparam integer LEN_RESEED  = 5 + 1 + 55 + 32 * RESEED_BLOCKS;
    localparam integer LEN_C       = 5 + 1 + 55;
    localparam integer LEN_GEN     = 55;
    localparam integer LEN_UPDATE  = 1 + 55;

    // Message shift register: longest message plus one spare byte (keeps
    // every zero-fill width below greater than 0).
    localparam integer MSG_BYTES   = ((LEN_INST > LEN_RESEED) ? LEN_INST
                                                              : LEN_RESEED) + 1;
    localparam integer MSG_W       = 8 * MSG_BYTES;

    localparam [31:0]  NO_OF_BITS  = 32'd440;

    // -----------------------------------------------------------------------
    // FSM states
    // -----------------------------------------------------------------------
    localparam [3:0] S_COLLECT = 4'd0,   // gather entropy blocks
                     S_SEED_V1 = 4'd1,   // Hash_df for V, counter 0x01
                     S_SEED_V2 = 4'd2,   // Hash_df for V, counter 0x02
                     S_SEED_C1 = 4'd3,   // Hash_df for C, counter 0x01
                     S_SEED_C2 = 4'd4,   // Hash_df for C, counter 0x02
                     S_IDLE    = 4'd5,
                     S_GEN_OUT = 4'd6,   // Hashgen: output = Hash(V)
                     S_GEN_UPD = 4'd7,   // H = Hash(0x03 || V)
                     S_ADD1    = 4'd8,   // sum = V + C
                     S_ADD2    = 4'd9;   // V = sum + H + reseed_counter

    reg [3:0]   state;
    reg         mode_reseed;   // 0 = instantiate, 1 = reseed
    reg [7:0]   blocks_left;

    // DRBG working state
    reg [439:0] V;
    reg [439:0] C;
    reg [47:0]  reseed_counter;

    // Temporaries (cleared after use)
    reg [ENT_BITS-1:0] ent_buf;    // oldest block in the top bits used
    reg [255:0] digest1;           // first half of a Hash_df result
    reg [255:0] out_r;             // generated block, before the state update
    reg [255:0] h_r;               // H = Hash(0x03 || V)
    reg [439:0] sum_r;             // V + C

    // Hash call engine
    reg             issued;        // message for this state already started
    reg             streaming;     // still sending bytes
    reg [MSG_W-1:0] msg_sr;        // message, next byte in the top 8 bits
    reg [9:0]       bytes_left;

    assign entropy_needed = (state == S_COLLECT);

    // =======================================================================
    // Message to SEND TO THE HASHING MODULE for the current state
    // (left-aligned in MSG_W bits, zero filled; only `len` bytes are sent)
    // =======================================================================
    wire [7:0] df_counter = (state == S_SEED_V1 || state == S_SEED_C1) ? 8'h01
                                                                       : 8'h02;

    // Instantiate: counter || 440 || entropy_input || nonce
    wire [MSG_W-1:0] msg_inst = {df_counter, NO_OF_BITS,
                                 ent_buf[SEED_BITS-1:0],
                                 {(MSG_W - 40 - SEED_BITS){1'b0}}};
    // Reseed: counter || 440 || 0x01 || V || entropy_input
    wire [MSG_W-1:0] msg_reseed = {df_counter, NO_OF_BITS, 8'h01, V,
                                   ent_buf[RESEED_BITS-1:0],
                                   {(MSG_W - 488 - RESEED_BITS){1'b0}}};
    // New C: counter || 440 || 0x00 || V
    wire [MSG_W-1:0] msg_c      = {df_counter, NO_OF_BITS, 8'h00, V,
                                   {(MSG_W - 488){1'b0}}};
    // Generate output (Hashgen, one block): V
    wire [MSG_W-1:0] msg_gen    = {V, {(MSG_W - 440){1'b0}}};
    // Generate state update: 0x03 || V
    wire [MSG_W-1:0] msg_update = {8'h03, V, {(MSG_W - 448){1'b0}}};

    reg [MSG_W-1:0] msg_sel;
    reg [9:0]       len_sel;
    always @(*) begin
        case (state)
            S_SEED_V1, S_SEED_V2: begin
                msg_sel = mode_reseed ? msg_reseed : msg_inst;
                len_sel = mode_reseed ? LEN_RESEED : LEN_INST;
            end
            S_SEED_C1, S_SEED_C2: begin msg_sel = msg_c;      len_sel = LEN_C;      end
            S_GEN_OUT:            begin msg_sel = msg_gen;    len_sel = LEN_GEN;    end
            S_GEN_UPD:            begin msg_sel = msg_update; len_sel = LEN_UPDATE; end
            default:              begin msg_sel = {MSG_W{1'b0}}; len_sel = 10'd0;   end
        endcase
    end

    wire in_hash_state = (state == S_SEED_V1) || (state == S_SEED_V2) ||
                         (state == S_SEED_C1) || (state == S_SEED_C2) ||
                         (state == S_GEN_OUT) || (state == S_GEN_UPD);

    // =======================================================================
    // SEND TO THE HASHING MODULE
    // =======================================================================
    assign hash_msg_data  = msg_sr[MSG_W-1 -: 8];
    assign hash_msg_valid = streaming;
    assign hash_msg_last  = streaming && (bytes_left == 10'd1);
    wire   hash_msg_fire  = hash_msg_valid && hash_msg_ready;

    // Digest for the message we sent (only accepted after the last byte)
    wire   digest_back    = issued && !streaming && hash_digest_valid;

    // =======================================================================
    // Main FSM
    // =======================================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state          <= S_COLLECT;
            mode_reseed    <= 1'b0;
            blocks_left    <= SEED_BLOCKS;
            V              <= 440'd0;
            C              <= 440'd0;
            reseed_counter <= 48'd0;
            instantiated   <= 1'b0;
            ent_buf        <= {ENT_BITS{1'b0}};
            digest1        <= 256'd0;
            out_r          <= 256'd0;
            h_r            <= 256'd0;
            sum_r          <= 440'd0;
            issued         <= 1'b0;
            streaming      <= 1'b0;
            msg_sr         <= {MSG_W{1'b0}};
            bytes_left     <= 10'd0;
            random_output  <= 256'd0;
            random_valid   <= 1'b0;
        end else begin
            random_valid <= 1'b0;
            if (random_valid)
                random_output <= 256'd0;   // handed off, erase our copy

            // ---------------------------------------------------------------
            // Start a hash: load the message that will be SENT TO THE
            // HASHING MODULE for this state.
            // ---------------------------------------------------------------
            if (in_hash_state && !issued) begin
                msg_sr     <= msg_sel;
                bytes_left <= len_sel;
                streaming  <= 1'b1;
                issued     <= 1'b1;
            end

            // ---------------------------------------------------------------
            // SEND TO THE HASHING MODULE: one byte per accepted handshake
            // ---------------------------------------------------------------
            if (hash_msg_fire) begin
                msg_sr     <= {msg_sr[MSG_W-9:0], 8'h00};
                bytes_left <= bytes_left - 10'd1;
                if (bytes_left == 10'd1)
                    streaming <= 1'b0;     // last byte sent; await digest
            end

            if (digest_back)
                issued <= 1'b0;

            case (state)
            // ---------------------------------------------------------------
            S_COLLECT: begin
                if (entropy_valid) begin
                    // shift in; after N blocks, ent_buf[N*256-1:0] holds
                    // them oldest-first (ENT_BLOCKS >= 2 is guaranteed)
                    ent_buf <= {ent_buf[ENT_BITS-257:0], entropy_input};
                    blocks_left <= blocks_left - 8'd1;
                    if (blocks_left == 8'd1)
                        state <= S_SEED_V1;
                end
            end

            // ---------------------------------------------------------------
            // Hash_df -> V   (Instantiate 10.1.1.2 / Reseed 10.1.1.3)
            // ---------------------------------------------------------------
            S_SEED_V1: if (digest_back) begin
                digest1 <= hash_digest;
                state   <= S_SEED_V2;
            end

            S_SEED_V2: if (digest_back) begin
                V       <= {digest1, hash_digest[255:72]};
                digest1 <= 256'd0;
                ent_buf <= {ENT_BITS{1'b0}};   // entropy consumed, erase it
                state   <= S_SEED_C1;
            end

            // ---------------------------------------------------------------
            // Hash_df -> C = Hash_df(0x00 || V, 440)
            // ---------------------------------------------------------------
            S_SEED_C1: if (digest_back) begin
                digest1 <= hash_digest;
                state   <= S_SEED_C2;
            end

            S_SEED_C2: if (digest_back) begin
                C              <= {digest1, hash_digest[255:72]};
                digest1        <= 256'd0;
                reseed_counter <= 48'd1;
                instantiated   <= 1'b1;
                // A reseed is only ever started by a generate request, so
                // carry straight on to the generate.
                state          <= mode_reseed ? S_GEN_OUT : S_IDLE;
            end

            // ---------------------------------------------------------------
            S_IDLE: begin
                // !random_valid: ignore the request line in the cycle the
                // previous block is handed over (requester hasn't dropped
                // it yet).
                if (gen_req && !random_valid) begin
                    if (reseed_counter > RESEED_INTERVAL) begin
                        mode_reseed <= 1'b1;
                        blocks_left <= RESEED_BLOCKS;
                        state       <= S_COLLECT;
                    end else begin
                        state       <= S_GEN_OUT;
                    end
                end
            end

            // ---------------------------------------------------------------
            // Generate (10.1.1.4), no additional_input, 256 bits requested
            // ---------------------------------------------------------------
            S_GEN_OUT: if (digest_back) begin
                out_r <= hash_digest;              // returned_bits = Hash(V)
                state <= S_GEN_UPD;
            end

            S_GEN_UPD: if (digest_back) begin
                h_r   <= hash_digest;              // H = Hash(0x03 || V)
                state <= S_ADD1;
            end

            // V = (V + H + C + reseed_counter) mod 2^440, split over two
            // cycles so each step is a single 440-bit add.
            S_ADD1: begin
                sum_r <= V + C;
                state <= S_ADD2;
            end

            S_ADD2: begin
                V              <= sum_r + {184'd0, h_r} + {392'd0, reseed_counter};
                reseed_counter <= reseed_counter + 48'd1;
                random_output  <= out_r;
                random_valid   <= 1'b1;
                out_r          <= 256'd0;
                h_r            <= 256'd0;
                sum_r          <= 440'd0;
                state          <= S_IDLE;
            end

            default: state <= S_COLLECT;
            endcase
        end
    end

endmodule
