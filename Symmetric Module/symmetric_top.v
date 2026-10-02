////////////////////////////////////////////////////////////////////////////////////////
// Filename:     symm_top.v
// Author:       Makeda Solomon
// Date Created: 14/04/26
// Version:      1
// Description:  The symmetric module design is based off the Trusted Computing Group's
//			     Trusted Platform Module 2.0 Specification Revision 1.59.
///////////////////////////////////////////////////////////////////////////////////////


module symm_top
(
    input wire       clock_i, // 50 MHz clock
    input wire       reset_n_i,
    input wire       start_i, // Module is ready to begin

    // Command context from execution engine
    input wire [15:0] command_code_i, // TPM command sent from the Execution Engine
    input wire       session_protect_i, // Status signal that indicates whether to take the session-based path or the primitive path
    input wire       session_decrypt_i, // Status signal to enable the module to decrypt incoming command parameters
    input wire       session_encrypt_i, // Status signal to enable the module to encrypt incoming command parameters
    input wire       session_use_xor_i,  // Select XOR Obfuscation within session protection instead of block ciphers

    // Input validity and cryptography context
    input wire       key_valid_i, // Status signal to indicate a valid symmetric key
    input wire       session_valid_i, // Status signal to indicate a valid session creation for session-based protection
    input wire [2:0] mode_i, // Cipher-block mode selected for the primitive path
    input wire       decrypt_i, // Decrypt status signal 
    input wire [4:0] data_bytes_i, // Valid byte count
    input wire [255:0] key_i, // Primitive key OR session-derived key
    input wire [127:0] iv_i, // Initialization vector used in both paths
    input wire [127:0] data_in_i, // Data to be encrypted or decrypted from Execution Engine
    input wire [127:0] session_mask_i,   // KDFa calcualted mask used in the session-based path

    // Outputs back to execution engine
    output reg            wait_o, // Signal indicating the AES cipher is still computing cipher
    output reg            done_o, // Signal indicating the completion of the symmetric module execution
    output reg   [11:0]   tpm_rc_o, // Error handling output
    output reg   [127:0]  data_out_o, // Plaintext or cipher output
    output reg   [127:0]  iv_out_o, // Final initialization vector
    output reg            primitive_path_o, // Plaintext or cipher output of the primitive path
    output reg            session_path_o // Plaintext or cipher output of the session-based path
);

    // Local constants
    localparam TPM_CC_ENCRYPT_DECRYPT_2 = 16'h0193; // Determined by the TPM 2.0 Specifications by the TCG
    
    // Arbitary numberset representing different possible block cipher modes
   // localparam SYM_MODE_NULL = 3'd0;
    localparam SYM_MODE_CFB  = 3'd1;
   // localparam SYM_MODE_CTR  = 3'd2;
   // localparam SYM_MODE_OFB  = 3'd3;
   // localparam SYM_MODE_CBC  = 3'd4;
   // localparam SYM_MODE_ECB  = 3'd5;

    // Error handling constants. Double check with how Emma Wallace defined the constants
    // TODO: Will likely have to include all of these as output varables as well
    localparam TPM_RC_SUCCESS      = 12'h000;
    localparam TPM_RC_COMMAND_CODE = 12'h143;
    localparam TPM_RC_MODE         = 12'h089;
    localparam TPM_RC_SIZE         = 12'h095;
    localparam TPM_RC_KEY          = 12'h09C;
    localparam TPM_RC_HANDLE       = 12'h08B;
    localparam TPM_RC_ATTRIBUTES   = 12'h082;
    localparam TPM_RC_FAILURE      = 12'h101;

    // FSM states
    localparam ST_IDLE    = 3'd0;
    localparam ST_EXECUTE = 3'd1;
    localparam ST_KEY_BUSY = 3'd2;
    localparam ST_KEY_READY = 3'd3;
    localparam ST_BLOCK_BUSY = 3'd4;
    localparam ST_BLOCK_DONE = 3'd5;
    localparam ST_DONE = 3'd6;
    localparam ST_RELEASE = 3'd7;
    reg [2:0] state_r;


    // Combinational decode/validation ("management unit" behavior)
    reg        request_valid_r;
    reg [11:0] validation_rc_r; //Validation register that tells us the status of the TPM regarding errors. TPM errors are determined by the TPM 2.0 Specifications
    reg [127:0] byte_mask_w;

    reg aes_init_r;
    reg aes_next_r;
    reg [255:0] aes_key_r;
    reg [127:0] aes_feedback_r;
    wire aes_ready_w;
    wire aes_result_valid_w;
    wire [127:0] cipher_stream_block_w;

    reg [127:0] data_r;
    reg [127:0] data_mask_r;
    reg [127:0] xor_mask_r;
    reg use_xor_r;
    reg decrypt_r;
    wire [127:0] cfb_result_w;
    wire [127:0] cfb_feedback_w;
    assign cfb_result_w = (data_r ^ cipher_stream_block_w) & data_mask_r;
    assign cfb_feedback_w = (decrypt_r ? data_r : cfb_result_w) & data_mask_r;

    always @(*) begin
        if (data_bytes_i == 5'd0)
            byte_mask_w = 128'b0;
        else if (data_bytes_i >= 5'd16)
            byte_mask_w = 128'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF;
        else
            byte_mask_w = 128'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF <<
                        ((5'd16 - data_bytes_i) * 8);
        end

// Command/session validation:
    always @(*) begin
        request_valid_r          = 1'b0; // Initialize the register that determines whether the command is valid or not to zero
        validation_rc_r          = TPM_RC_SUCCESS; // Assume initial success of the TPM's functionality?

        if ((command_code_i != TPM_CC_ENCRYPT_DECRYPT_2) && !session_protect_i) begin
            validation_rc_r = TPM_RC_COMMAND_CODE; // The TPM can't NOT take the primitive path while also not being session-based. There are two options. Either primitive or session based. One should be selected.
        end

        // Does the session-based protection path have priority when enabled. How is this determined?
        // Session-Based Path Validation:
        else if (session_protect_i) begin
            if (!session_valid_i) // If the session is invalid, then:
                validation_rc_r = TPM_RC_HANDLE; // ... send the following error handle
            else if (!(session_encrypt_i ^ session_decrypt_i)) // If the session toggles neither an encryption or decryption, then:
                validation_rc_r = TPM_RC_ATTRIBUTES; // ... send the following error handle
            else if (data_bytes_i > 5'd16) // The size must be within the specified size, otherwise:
                validation_rc_r = TPM_RC_SIZE; //... send the following error handle
            // TPM session rule: if block cipher is selected, mode must be CFB.
            else if (!session_use_xor_i && (mode_i != SYM_MODE_CFB))
                validation_rc_r = TPM_RC_MODE; // ... otherwise, send a mode error
            else if (!session_use_xor_i && !key_valid_i)
                validation_rc_r = TPM_RC_KEY;
            else
                request_valid_r = 1'b1; // If none of the above error conditions are true, set the valid command request to TRUE
        end
        // Primitive TPM2_EncryptDecrypt2 Path Validation:
        else begin
            if (!key_valid_i) // key_valid_i is set to a value that is pre-determined
                validation_rc_r = TPM_RC_KEY; // If the key is invalid, then send the following error handle
            else if (mode_i != SYM_MODE_CFB)
                validation_rc_r = TPM_RC_MODE; // If the mode is none of the option cipher blocks, or the NULL path, then send the following error handle.
            else if (data_bytes_i > 5'd16)
                validation_rc_r = TPM_RC_SIZE;
            else
                request_valid_r = 1'b1; // If none of the above error conditions are true, set the valid command request to TRUE
        end
    end

    aes AES_IMPLEMENT (
        .clock_i (clock_i),
        .reset_n_i (reset_n_i),

        .init_i (aes_init_r),
        .next_i (aes_next_r),
        // Initial implementation: AES-256
        .keylen_i (1'b1),
        .key_i (aes_key_r),
        .block_i (aes_feedback_r),
        .ready_o (aes_ready_w),
        .result_valid_o (aes_result_valid_w),
        .block_o (cipher_stream_block_w)
    );
   
    // Sequential control + execution datapath
    // Use <= in clocked logic for non-blocking updates for registers. All registers will update together at a time step
    always @(posedge clock_i or negedge reset_n_i) begin
        if (!reset_n_i) begin
            state_r           <= ST_IDLE;
            aes_init_r        <= 1'b0;
            aes_next_r        <= 1'b0;
            aes_key_r         <= 256'b0;
            aes_feedback_r    <= 128'b0;
            data_r            <= 128'b0;
            data_mask_r       <= 128'b0;
            xor_mask_r        <= 128'b0;
            use_xor_r         <= 1'b0;
            decrypt_r         <= 1'b0;
            wait_o            <= 1'b0;
            done_o            <= 1'b0;
            tpm_rc_o          <= TPM_RC_SUCCESS;
            data_out_o        <= 128'b0;
            iv_out_o          <= 128'b0;
            primitive_path_o  <= 1'b0;
            session_path_o    <= 1'b0;
        end
        else begin
            done_o <= 1'b0;
            aes_init_r <= 1'b0;
            aes_next_r <= 1'b0;

             case (state_r)
                ST_IDLE: begin
                    wait_o <= 1'b0;
                    if (start_i) begin
                        wait_o           <= 1'b1;
                        tpm_rc_o         <= validation_rc_r;
                        data_out_o       <= 128'b0;
                        iv_out_o         <= 128'b0;
                        primitive_path_o <= 1'b0;
                        session_path_o   <= 1'b0;

                        if (!request_valid_r)
                            state_r <= ST_DONE;
                        else begin
                            aes_key_r        <= key_i;
                            aes_feedback_r   <= iv_i;
                            data_r           <= data_in_i;
                            data_mask_r      <= byte_mask_w;
                            xor_mask_r       <= session_mask_i;
                            use_xor_r        <= session_protect_i && session_use_xor_i;
                            decrypt_r        <= session_protect_i ? session_decrypt_i : decrypt_i;
                            primitive_path_o <= !session_protect_i;
                            session_path_o   <= session_protect_i;
                            state_r          <= ST_EXECUTE;
                        end
                    end
                end

                ST_EXECUTE: begin
                    if (data_mask_r == 128'b0) begin
                        // Empty operation: preserve IV and do not start AES.
                        data_out_o <= 128'b0;
                        iv_out_o   <= aes_feedback_r;
                        state_r    <= ST_DONE;
                    end
                    else if (use_xor_r) begin
                        // Mask has already been derived by the session/KDF service.
                        data_out_o <= (data_r ^ xor_mask_r) & data_mask_r;
                        iv_out_o   <= aes_feedback_r;
                        state_r    <= ST_DONE;
                    end
                    else if (aes_ready_w) begin
                        aes_init_r <= 1'b1;
                        state_r    <= ST_KEY_BUSY;
                    end
                    // Otherwise hold this state until the core can accept init.
                end

                ST_KEY_BUSY: begin
                    // Do not mistake the pre-init ready=1 for completion.
                    if (!aes_ready_w)
                        state_r <= ST_KEY_READY;
                end

                ST_KEY_READY: begin
                    if (aes_ready_w) begin
                        // Key expansion completed; start E_key(feedback_IV).
                        aes_next_r <= 1'b1;
                        state_r    <= ST_BLOCK_BUSY;
                    end
                end

                ST_BLOCK_BUSY: begin
                    // Qualify this new launch before looking at result_valid.
                    if (!aes_ready_w)
                        state_r <= ST_BLOCK_DONE;
                end

                ST_BLOCK_DONE: begin
                    if (aes_ready_w && aes_result_valid_w) begin
                        data_out_o     <= cfb_result_w;
                        iv_out_o       <= cfb_feedback_w;
                        aes_feedback_r <= cfb_feedback_w;
                        state_r        <= ST_DONE;
                    end
                end

                ST_DONE: begin
                    done_o  <= 1'b1;
                    state_r <= ST_RELEASE;
                    // wait_o remains high through the result pulse.
                end

                ST_RELEASE: begin
                    // A held legacy start must not retrigger the same job.
                    if (!start_i) begin
                        wait_o  <= 1'b0;
                        state_r <= ST_IDLE;
                    end
                end

                default: begin
                    wait_o           <= 1'b1;
                    tpm_rc_o         <= TPM_RC_FAILURE;
                    data_out_o       <= 128'b0;
                    iv_out_o         <= 128'b0;
                    primitive_path_o <= 1'b0;
                    session_path_o   <= 1'b0;
                    state_r          <= ST_DONE;
                end
            endcase
        end
    end

endmodule
