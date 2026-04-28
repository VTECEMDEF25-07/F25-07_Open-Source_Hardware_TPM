////////////////////////////////////////////////////////////////////////////////////////
// Filename:     symmetric_demo_top.v
// Description:  Board-level visual demo wrapper for symmetric module behavior.
///////////////////////////////////////////////////////////////////////////////////////

module symmetric_demo_top
(
    input         CLOCK_50,
    input  [1:0]  KEY,
    input  [9:0]  SW,
    output [9:0]  LEDR,
    output [6:0]  HEX5,
    output [6:0]  HEX4,
    output [6:0]  HEX3,
    output [6:0]  HEX2,
    output [6:0]  HEX1,
    output [6:0]  HEX0
);

    localparam TPM_CC_ENCRYPT_DECRYPT_2 = 16'h0193;

    localparam SYM_MODE_NULL = 3'd0;
    localparam SYM_MODE_CFB  = 3'd1;
    localparam SYM_MODE_CTR  = 3'd2;

    localparam TPM_RC_SUCCESS = 12'h000;
    localparam TPM_RC_MODE    = 12'h089;
    localparam TPM_RC_SIZE    = 12'h095;

    wire reset_n_w;
    assign reset_n_w = KEY[0];

    reg key1_prev_r;
    always @(posedge CLOCK_50 or negedge reset_n_w) begin
        if (!reset_n_w)
            key1_prev_r <= 1'b1;
        else
            key1_prev_r <= KEY[1];
    end

    wire start_w;
    assign start_w = key1_prev_r & ~KEY[1];

    reg [15:0]  command_code_r;
    reg         session_protect_r;
    reg         session_decrypt_r;
    reg         session_encrypt_r;
    reg         session_use_xor_r;
    reg         key_valid_r;
    reg         session_valid_r;
    reg [2:0]   mode_r;
    reg         decrypt_r;
    reg [4:0]   data_bytes_r;
    reg [255:0] key_r;
    reg [127:0] iv_r;
    reg [127:0] data_in_r;
    reg [127:0] session_mask_r;

    wire [15:0] data_word_w;
    assign data_word_w = {SW[9:0], 6'b000000};

    always @(*) begin
        command_code_r    = TPM_CC_ENCRYPT_DECRYPT_2;
        session_protect_r = 1'b0;
        session_decrypt_r = 1'b0;
        session_encrypt_r = 1'b0;
        session_use_xor_r = 1'b0;

        key_valid_r       = 1'b1;
        session_valid_r   = 1'b1;
        mode_r            = SYM_MODE_CFB;
        decrypt_r         = SW[2];
        data_bytes_r      = 5'd16;

        key_r             = 256'h000102030405060708090A0B0C0D0E0F101112131415161718191A1B1C1D1E1F;
        iv_r              = 128'h00112233445566778899AABBCCDDEEFF;
        data_in_r         = {8{data_word_w}};
        session_mask_r    = 128'hA5A5A5A55A5A5A5AF0F00F0FF00FF0F0;

        case (SW[1:0])
            2'b00: begin
                // Scenario 0: Primitive path valid request
                session_protect_r = 1'b0;
                mode_r            = SYM_MODE_CFB;
            end

            2'b01: begin
                // Scenario 1: Session XOR valid request
                session_protect_r = 1'b1;
                session_use_xor_r = 1'b1;
                mode_r            = SYM_MODE_NULL;
                session_encrypt_r = ~SW[2];
                session_decrypt_r = SW[2];
            end

            2'b10: begin
                // Scenario 2: Session block mode invalid (expect TPM_RC_MODE)
                session_protect_r = 1'b1;
                session_use_xor_r = 1'b0;
                mode_r            = SYM_MODE_CTR;
                session_encrypt_r = 1'b1;
                session_decrypt_r = 1'b0;
            end

            2'b11: begin
                // Scenario 3: Primitive invalid size (expect TPM_RC_SIZE)
                session_protect_r = 1'b0;
                mode_r            = SYM_MODE_CFB;
                data_bytes_r      = 5'd0;
            end
        endcase
    end

    wire        wait_w;
    wire        done_w;
    wire [11:0] tpm_rc_w;
    wire [127:0] data_out_w;
    wire [127:0] iv_out_w;
    wire        primitive_path_w;
    wire        session_path_w;

    symm_top U_SYMM
    (
        .clock_i(CLOCK_50),
        .reset_n_i(reset_n_w),
        .start_i(start_w),

        .command_code_i(command_code_r),
        .session_protect_i(session_protect_r),
        .session_decrypt_i(session_decrypt_r),
        .session_encrypt_i(session_encrypt_r),
        .session_use_xor_i(session_use_xor_r),

        .key_valid_i(key_valid_r),
        .session_valid_i(session_valid_r),
        .mode_i(mode_r),
        .decrypt_i(decrypt_r),
        .data_bytes_i(data_bytes_r),
        .key_i(key_r),
        .iv_i(iv_r),
        .data_in_i(data_in_r),
        .session_mask_i(session_mask_r),

        .wait_o(wait_w),
        .done_o(done_w),
        .tpm_rc_o(tpm_rc_w),
        .data_out_o(data_out_w),
        .iv_out_o(iv_out_w),
        .primitive_path_o(primitive_path_w),
        .session_path_o(session_path_w)
    );

    reg        done_latched_r;
    reg        primitive_latched_r;
    reg        session_latched_r;
    reg [11:0] rc_latched_r;
    reg [127:0] data_latched_r;

    always @(posedge CLOCK_50 or negedge reset_n_w) begin
        if (!reset_n_w) begin
            done_latched_r      <= 1'b0;
            primitive_latched_r <= 1'b0;
            session_latched_r   <= 1'b0;
            rc_latched_r        <= 12'h000;
            data_latched_r      <= 128'h0;
        end
        else begin
            if (start_w)
                done_latched_r <= 1'b0;

            if (done_w) begin
                done_latched_r      <= 1'b1;
                primitive_latched_r <= primitive_path_w;
                session_latched_r   <= session_path_w;
                rc_latched_r        <= tpm_rc_w;
                data_latched_r      <= data_out_w;
            end
        end
    end

    assign LEDR[0] = done_latched_r;
    assign LEDR[1] = wait_w;
    assign LEDR[2] = primitive_latched_r;
    assign LEDR[3] = session_latched_r;
    assign LEDR[4] = ~KEY[1];
    assign LEDR[5] = (rc_latched_r == TPM_RC_SUCCESS);
    assign LEDR[6] = (rc_latched_r == TPM_RC_MODE);
    assign LEDR[7] = (rc_latched_r == TPM_RC_SIZE);
    assign LEDR[9:8] = SW[1:0];

    hex7seg H0(.hex_digit_i(rc_latched_r[3:0]),   .hex_display_o(HEX0));
    hex7seg H1(.hex_digit_i(rc_latched_r[7:4]),   .hex_display_o(HEX1));
    hex7seg H2(.hex_digit_i({1'b0,rc_latched_r[11:8]}), .hex_display_o(HEX2));
    hex7seg H3(.hex_digit_i({2'b00,SW[1:0]}), .hex_display_o(HEX3));
    hex7seg H4(.hex_digit_i(data_latched_r[3:0]), .hex_display_o(HEX4));
    hex7seg H5(.hex_digit_i({done_latched_r,~KEY[1],primitive_latched_r,session_latched_r}), .hex_display_o(HEX5));

endmodule

module hex7seg
(
    input  [3:0] hex_digit_i,
    output reg [6:0] hex_display_o
);

    always @(hex_digit_i) begin
        case(hex_digit_i)
            4'h0:    hex_display_o = 7'h40;
            4'h1:    hex_display_o = 7'h79;
            4'h2:    hex_display_o = 7'h24;
            4'h3:    hex_display_o = 7'h30;
            4'h4:    hex_display_o = 7'h19;
            4'h5:    hex_display_o = 7'h12;
            4'h6:    hex_display_o = 7'h02;
            4'h7:    hex_display_o = 7'h78;
            4'h8:    hex_display_o = 7'h00;
            4'h9:    hex_display_o = 7'h10;
            4'hA:    hex_display_o = 7'h08;
            4'hB:    hex_display_o = 7'h03;
            4'hC:    hex_display_o = 7'h46;
            4'hD:    hex_display_o = 7'h21;
            4'hE:    hex_display_o = 7'h06;
            4'hF:    hex_display_o = 7'h0E;
            default: hex_display_o = 7'h7F;
        endcase
    end

endmodule

