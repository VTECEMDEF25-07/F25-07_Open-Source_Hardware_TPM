////////////////////////////////////////////////////////////////////////////////////////
// Filename:     symmetric.v
// Author:       Makeda Solomon
// Date Created: 14/04/26
// Version:      1
// Description:  The symmetric module design is based off the Trusted Computing Group's
//			     Trusted Platform Module 2.0 Specification Revision 1.59.
///////////////////////////////////////////////////////////////////////////////////////


module symm_top
(
    input            clock_i, // 50 MHz clock
    input            reset_n_i,
    input            start_i, // Module is ready to begin

    // Command context from execution engine
    input   [15:0]   command_code_i, // TPM command sent from the Execution Engine
    input            session_protect_i, // Status signal that indicates whether to take the session-based path or the primitive path
    input            session_decrypt_i, // Status signal to enable the module to decrypt incoming command parameters
    input            session_encrypt_i, // Status signal to enable the module to encrypt incoming command parameters
    input            session_use_xor_i,  // Select XOR Obfuscation within session protection instead of block ciphers

    // Input validity and cryptography context
    input            key_valid_i, // Status signal to indicate a valid symmetric key
    input            session_valid_i, // Status signal to indicate a valid session creation for session-based protection
    input   [2:0]    mode_i, // Cipher-block mode selected for the primitive path
    input            decrypt_i, // Decrypt status signal 
    input   [4:0]    data_bytes_i, // Valid byte count
    input   [255:0]  key_i, // Primitive key OR session-derived key
    input   [127:0]  iv_i, // Initialization vector used in both paths
    input   [127:0]  data_in_i, // Data to be encrypted or decrypted from Execution Engine
    input   [127:0]  session_mask_i,   // KDFa calcualted mask used in the session-based path

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
    localparam SYM_MODE_NULL = 3'd0;
    localparam SYM_MODE_CFB  = 3'd1;
    localparam SYM_MODE_CTR  = 3'd2;
    localparam SYM_MODE_OFB  = 3'd3;
    localparam SYM_MODE_CBC  = 3'd4;
    localparam SYM_MODE_ECB  = 3'd5;

    // Error handling constants. Double check with how Emma Wallace defined the constants
    // TODO: Will likely have to include all of these as output varables as well
    localparam TPM_RC_SUCCESS      = 12'h000;
    localparam TPM_RC_COMMAND_CODE = 12'h043;
    localparam TPM_RC_MODE         = 12'h089;
    localparam TPM_RC_SIZE         = 12'h095;
    localparam TPM_RC_KEY          = 12'h08C;
    localparam TPM_RC_HANDLE       = 12'h08B;
    localparam TPM_RC_ATTRIBUTES   = 12'h082;

    // FSM states
    localparam ST_IDLE    = 2'b00;
    localparam ST_EXECUTE = 2'b01;
    localparam ST_DONE    = 2'b10;

    reg [1:0] state_r;


    // Combinational decode/validation ("management unit" behavior)
    reg        request_valid_r;
    reg [11:0] validation_rc_r; //Validation register that tells us the status of the TPM regarding errors. TPM errors are determined by the TPM 2.0 Specifications
    wire block_mode_w;
    reg [127:0] byte_mask_w;
    reg [127:0] cipher_stream_block_w;

    assign block_mode_w    =
        (mode_i == SYM_MODE_CFB) ||
        (mode_i == SYM_MODE_CTR) ||
        (mode_i == SYM_MODE_OFB) ||
        (mode_i == SYM_MODE_CBC) ||
        (mode_i == SYM_MODE_ECB);

// Command/session validation:
    always @(*) begin
        request_valid_r          = 1'b0; // Initialize the register that determines whether the command is valid or not to zero
        validation_rc_r          = TPM_RC_SUCCESS; // Assume initial success of the TPM's functionality?

        if (!(command_code_i == TPM_CC_ENCRYPT_DECRYPT_2)) && !(session_protect_i))) begin
            validation_rc_r = TPM_RC_COMMAND_CODE; // The TPM can't NOT take the primitive path while also not being session-based. There are two options. Either primitive or session based. One should be selected.
        end

        // TODO: Does the session-based protection path have priority when enabled. How is this determined?
        // Session-Based Path Validation:
        else if (session_protect_i) begin
            if (!session_valid_i) // If the session is invalid, then:
                validation_rc_r = TPM_RC_HANDLE; // ... send the following error handle
        else if (!(session_encrypt_i || session_decrypt_i)) // If the session toggles neither an encryption or decryption, then:
            validation_rc_r = TPM_RC_ATTRIBUTES; // ... send the following error handle
        else if ((data_bytes_i == 5'd0) || (data_bytes_i > 5'd16)) // The size must be within the specified size, otherwise:
            validation_rc_r = TPM_RC_SIZE; //... send the following error handle
            // TPM session rule: if block cipher is selected, mode must be CFB.
         else if (!session_use_xor_i && (mode_i != SYM_MODE_CFB))
            validation_rc_r = TPM_RC_MODE; // ... otherwise, send a mode error
            else
                request_valid_r = 1'b1; // If none of the above error conditions are true, set the valid command request to TRUE
            end
        // Primitive TPM2_EncryptDecrypt2 Path Validation:
        else begin
            if (!key_valid_i) // key_valid_i is set to a value that is pre-determined
                validation_rc_r = TPM_RC_KEY; // If the key is invalid, then send the following error handle
            else if (!((mode_i == SYM_MODE_CBC) || (mode_i == SYM_MODE_CFB) || (mode_i == SYM_MODE_CTR)) 
            || (mode_i == SYM_MODE_NULL))
                validation_rc_r = TPM_RC_MODE; // If the mode is none of the option cipher blocks, or the NULL path, then send the following error handle.
            else if ((data_bytes_i == 5'd0) || (data_bytes_i > 5'd16))
                validation_rc_r = TPM_RC_SIZE;
            // In this starter, CBC/ECB are single full-block only.
            else if (((mode_i == SYM_MODE_CBC) || (mode_i == SYM_MODE_ECB)) &&
                     (data_bytes_i != 5'd16))
                validation_rc_r = TPM_RC_SIZE;
            else
                request_valid_r = 1'b1; // If none of the above error conditions are true, set the valid command request to TRUE
        end
    end

    aes AES_IMPLEMENT (
        .block_i(iv_i),
        .key_i(key_i),
      //  .block_o(cipher_stream_block_w)
    );
   
    // Sequential control + execution datapath
    // Use <= in clocked logic for non-blocking updates for registers. All registers will update together at a time step
    always @(posedge clock_i or negedge reset_n_i) begin
        if (!reset_n_i) begin
            state_r           <= ST_IDLE;
            wait_o            <= 1'b0;
            done_o            <= 1'b0;
            tpm_rc_o          <= TPM_RC_SUCCESS;
            data_out_o        <= 128'h0;
            iv_out_o          <= 128'h0;
            primitive_path_o  <= 1'b0;
            session_path_o    <= 1'b0;
        end
        else begin
            done_o <= 1'b0;

            case (state_r)
                ST_IDLE: begin
                    wait_o           <= 1'b0;
                    primitive_path_o <= 1'b0;
                    session_path_o   <= 1'b0;

                    if (start_i) begin
                        if (!request_valid_r) begin
                        tpm_rc_o <= validation_rc_r;
                        state_r  <= ST_DONE;
                    end
                    else begin
                        tpm_rc_o <= validation_rc_r;
                        state_r  <= ST_EXECUTE;
                    end
                end
            end

                ST_EXECUTE: begin
                    wait_o <= 1'b1;
                    primitive_path_o <= ~session_protect_i;
                    session_path_o <= session_protect_i;

                    if (session_protect_i && session_use_xor_i) begin // Session XOR obfuscation path.
                        data_out_o <= data_in_i ^ (session_mask_i & byte_mask_r);
                        iv_out_o   <= iv_i;
                    end
                    else begin
                        // Primitive or session-CFB path.
                        // TODO: replace pseudo_block_cipher with AES-256 encrypt core.
                        data_out_o <= data_in_i ^ (cipher_stream_block_w & byte_mask_w);
                        iv_out_o   <= cipher_stream_block_w;
                    end

                    state_r <= ST_DONE;
                end

                ST_DONE: begin
                    wait_o <= 1'b0;
                    done_o <= 1'b1;
                    state_r <= ST_IDLE;
                end

                default: begin
                    state_r <= ST_IDLE;
                end
            endcase
        end
    end

endmodule
