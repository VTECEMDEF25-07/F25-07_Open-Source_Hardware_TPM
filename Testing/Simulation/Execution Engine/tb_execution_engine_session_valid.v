`timescale 1ns/1ps

module tb_execution_engine_session_valid;

    // ============================================================================
    // TPM COMMAND CODES (subset to influence command_code_tag in DUT)
    // ============================================================================
    localparam TPM_CC_STARTUP = 16'h0144;  // (maps to NO_SESSIONS in DUT tag logic)
    localparam TPM_CC_CLEAR   = 16'h0126;  // (maps to SESSIONS in DUT tag logic)

    // ============================================================================
    // COMMAND TAGS
    // ============================================================================
    localparam TPM_ST_NO_SESSIONS = 16'h8001;
    localparam TPM_ST_SESSIONS    = 16'h8002;

    // ============================================================================
    // SESSION HANDLE TYPE (top byte of session*_handle)
    // ============================================================================
    localparam [7:0] TPM_HT_HMAC_SESSION   = 8'h02;
    localparam [7:0] TPM_HT_POLICY_SESSION = 8'h03;

    // Password authorisation magic value accepted in compare path
    localparam [31:0] TPM_RS_PW = 32'h4000_0009;

    // ============================================================================
    // Clock / Reset
    // ============================================================================
    reg clk;
    reg reset_n;
    always #5 clk = ~clk;

// ==================
// DUT input signals
// ==================
reg         command_ready;      // Active-high command ready
reg  [15:0] command_tag;
reg  [31:0] command_size;
reg  [31:0] command_code;
reg  [15:0] command_length;

reg  [31:0] handle_0;
reg  [31:0] handle_1;
reg  [31:0] handle_2;

// Management module inputs (EXACT MATCH)
reg  [2:0]  op_state;
reg  [2:0]  startup_type;
reg         phEnable;
reg         phEnableNV;
reg         shEnable;
reg         ehEnable;
reg  [15:0] shutdownSave;

// Command processing
reg         command_done;

// Session validation inputs
reg  [31:0] session0_handle;
reg  [31:0] session1_handle;
reg  [31:0] session2_handle;

reg  [7:0]  session0_attributes;
reg  [7:0]  session1_attributes;
reg  [7:0]  session2_attributes;

reg  [15:0] session0_hmac_size;
reg  [15:0] session1_hmac_size;
reg  [15:0] session2_hmac_size;

reg         session0_valid;
reg         session1_valid;
reg         session2_valid;

reg  [31:0] authorization_size;
reg         session_loaded;
reg  [15:0] max_session_amount;
reg         auth_session;
reg         auth_necessary;

reg  [31:0] authHandle;         // Authorization control domain
reg  [7:0]  pcrSelect;

// Authorization / param-preprocessing results
reg         auth_success;
reg         auth_done;
reg         param_decrypt_success;
reg         param_decrypt_fail;
reg         param_unmarshall_success;
reg         param_unmarshall_fail;

// NV memory submodule inputs
reg         nv_phEnableNV_in;
reg         nv_shEnable_in;
reg         nv_ehEnable_in;
reg  [31:0] tpm_nv_index;
reg  [31:0] nv_index_attributes;
reg         nv_object_present;
reg         nv_index_present;
reg  [31:0] entity_hierarchy;
reg [31:0] object_attributes;

// Memory submodule inputs
reg  [15:0] mem_orderly;
reg         ram_available;
reg         loaded_object_present;

// Self-test submodule inputs
reg  [15:0] st_testsRun;
reg  [15:0] st_testsPassed;
reg  [15:0] st_untested;
//startup error signal
reg execution_startup_done;
//execution response code
reg execution_response_code;
reg [11:0] auth_response_code;
// ===================
// DUT output signals
// ===================
wire        response_valid;
wire [31:0] response_code;
wire [15:0] response_length;
wire [3:0]  current_state;
wire        command_start;

wire [15:0] orderlyInput;
wire        initialized;
wire [15:0] testsRun;
wire [15:0] testsPassed;
wire [15:0] untested;
wire        nv_phEnableNV;
wire        nv_shEnable;
wire        nv_ehEnable;
wire [31:0] authHierarchy;

    // =====================
    // Device Under Test
    // =====================
 execution_engine DUT (
    .clock_i(clk),
    .reset_n_i(reset_n),
    .command_ready_i(command_ready),
    .command_tag_i(command_tag),
    .command_size_i(command_size),
    .command_code_i(command_code),
    .command_length_i(command_length),
    // command buffer inputs
    .handle_0_i(handle_0),
    .handle_1_i(handle_1),
    .handle_2_i(handle_2),
    .session0_handle_i(session0_handle),
    .session1_handle_i(session1_handle),
    .session2_handle_i(session2_handle),
    .session0_attributes_i(session0_attributes),
    .session1_attributes_i(session1_attributes),
    .session2_attributes_i(session2_attributes),
    .session0_hmac_size_i(session0_hmac_size),
    .session1_hmac_size_i(session1_hmac_size),
    .session2_hmac_size_i(session2_hmac_size),
    .session0_valid_i(session0_valid),
    .session1_valid_i(session1_valid),
    .session2_valid_i(session2_valid),
    .authorization_size_i(authorization_size),
    .session_loaded_i(session_loaded),
    .max_session_amount_i(max_session_amount),
    .auth_session_i(auth_session),
    .auth_necessary_i(auth_necessary),
    .authHandle_i(authHandle),
    .pcrSelect_i(pcrSelect),
    // Authorization submodule inputs
    .auth_success_i(auth_success),
    .auth_done_i(auth_done),
    .auth_response_code_i(auth_response_code),
    // param decrypt / unmarshall submodule inputs
    .param_decrypt_success_i(param_decrypt_success),
    .param_decrypt_fail_i(param_decrypt_fail),
    .param_unmarshall_success_i(param_unmarshall_success),
    .param_unmarshall_fail_i(param_unmarshall_fail),

    .execution_startup_done_i(execution_startup_done),
    .execution_response_code_i(execution_response_code),
    // NV memory submodule inputs
    .nv_phEnableNV_in_i(nv_phEnableNV_in),
    .nv_shEnable_in_i(nv_shEnable_in),
    .nv_ehEnable_in_i(nv_ehEnable_in),
    .tpm_nv_index_i(tpm_nv_index),
    .nv_index_attributes_i(nv_index_attributes),
    .nv_object_present_i(nv_object_present),
    .nv_index_present_i(nv_index_present),
    .entity_hierarchy_i(entity_hierarchy),
    // Memory submodule inputs
    .mem_orderly_i(mem_orderly),
    .ram_available_i(ram_available),
    .loaded_object_present_i(loaded_object_present),
    .object_attributes_i(object_attributes),
    // Self-test submodule inputs
    .st_testsRun_i(st_testsRun),
    .st_testsPassed_i(st_testsPassed),
    .st_untested_i(st_untested),
    // Management module inputs
    .op_state_i(op_state),
    .startup_type_i(startup_type),
    .phEnable_i(phEnable),
    .phEnableNV_i(phEnableNV),
    .shEnable_i(shEnable),
    .ehEnable_i(ehEnable),
    .shutdownSave_i(shutdownSave),
    .command_done_i(command_done),
    // management outputs
    .testsPassed_o(testsPassed),
    .untested_o(untested),
    .nv_phEnableNV_o(nv_phEnableNV),
    .nv_shEnable_o(nv_shEnable),
    .nv_ehEnable_o(nv_ehEnable),
    .orderlyInput_o(orderlyInput),
    .initialized_o(initialized),
    .testsRun_o(testsRun),
    .authHierarchy_o(authHierarchy),
    // Response outputs
    .response_valid_o(response_valid),
    .response_code_o(response_code),
    .response_length_o(response_length),
    .current_state_o(current_state),
    .command_start_o(command_start)
);

    // ============================================================================
    // Defaults
    // ============================================================================
    initial begin
      // Clock/reset defaults
    clk                  = 1'b0;
    reset_n              = 1'b0;

    auth_response_code = 12'd0;
    // Top-level command interface
    command_ready        = 1'b0;
    command_tag          = 16'd0;
    command_size         = 32'd0;
    command_code         = 32'd0;
    command_length       = 16'd0;

    // Command buffer inputs
    handle_0             = 32'd0;
    handle_1             = 32'd0;
    handle_2             = 32'd0;

    // Management inputs
    op_state             = 3'b011;
    startup_type         = 3'd0;
    phEnable             = 1'b0;
    phEnableNV           = 1'b0;
    shEnable             = 1'b0;
    ehEnable             = 1'b0;
    shutdownSave         = 16'd0;

    // Command processing
    command_done         = 1'b0;

    // Session validation
    session0_handle      = 32'd0;
    session1_handle      = 32'd0;
    session2_handle      = 32'd0;

    session0_attributes  = 8'd0;
    session1_attributes  = 8'd0;
    session2_attributes  = 8'd0;

    session0_hmac_size   = 16'd0;
    session1_hmac_size   = 16'd0;
    session2_hmac_size   = 16'd0;

    session0_valid       = 1'b0;
    session1_valid       = 1'b0;
    session2_valid       = 1'b0;

    authorization_size   = 32'd0;
    session_loaded       = 1'b0;
    max_session_amount   = 16'd0;
    auth_session         = 1'b0;
    auth_necessary       = 1'b0;

    authHandle           = 32'd0;
    pcrSelect            = 8'd0;

    // Authorization / param-preprocessing
    auth_success             = 1'b0;
    auth_done                = 1'b0;
    param_decrypt_success    = 1'b0;
    param_decrypt_fail       = 1'b0;
    param_unmarshall_success = 1'b0;
    param_unmarshall_fail    = 1'b0;

    // NV memory submodule inputs
    nv_phEnableNV_in     = 1'b0;
    nv_shEnable_in       = 1'b0;
    nv_ehEnable_in       = 1'b0;
    tpm_nv_index         = 32'd0;
    nv_index_attributes  = 32'd0;
    nv_object_present    = 1'b0;
    nv_index_present     = 1'b0;
    entity_hierarchy     = 32'd0;

    // Memory submodule inputs
    mem_orderly          = 16'd0;
    ram_available        = 1'b0;
    loaded_object_present= 1'b0;
    object_attributes    = 32'd0;
    // Self-test submodule inputs
    st_testsRun          = 16'd0;
    st_testsPassed       = 16'd0;
    st_untested          = 16'd0;
    //startup error signal
    execution_startup_done = 1'b0;
    //execution response code
    execution_response_code = 1'b0;
        // reset release
        #20 reset_n = 1'b1;
    end

    // ============================================================================
    // Stimulus ? Phased, no tasks. You read the waves.
    // ============================================================================
    initial begin
        // Wait after reset
        #40;

        // ----------------------------------------------------------------------
        // PHASE 1: command_tag = NO_SESSIONS, command_code_tag (DUT) = SESSIONS
        // Maps to: s_response_code <= TPM_RC_AUTH_CONTEXT
        // ----------------------------------------------------------------------
        command_ready   = 1'b1;
        command_tag     = TPM_ST_NO_SESSIONS;
        command_code    = {8'h0E, TPM_CC_CLEAR};   // drives SESSIONS tag inside DUT
        command_size    = 32'd8;
        command_length  = 16'd8;

        // sessions benign (won't be used by NO_SESSIONS)
        session0_handle     = 32'd0;
        session0_attributes = 8'd0;
        session0_valid      = 1'b0;
        session_loaded      = 1'b0;
        auth_session        = 1'b0;
        #40;
        command_ready = 1'b0;

        // ----------------------------------------------------------------------
        // PHASE 2: command_tag = SESSIONS, command_code_tag (DUT) = NO_SESSIONS
        // Maps to: s_response_code <= TPM_RC_AUTH_MISSING
        // ----------------------------------------------------------------------
        #40;
        max_session_amount  = 2'd1;
        command_ready   = 1'b1;
        command_tag     = TPM_ST_SESSIONS;
        command_code    = {8'h0E, TPM_CC_STARTUP}; // drives NO_SESSIONS tag inside DUT
        command_size    = 32'd8;
        command_length  = 16'd8;

        // provide one valid-looking session in lane 0
        session0_handle     = {TPM_HT_HMAC_SESSION,24'h000000};
        session0_attributes = 8'b10000000; // set 'auth' bit as you encode it
        session0_valid      = 1'b1;
        session_loaded      = 1'b1;
        auth_session        = 1'b1;
        #40;
        command_ready = 1'b0;

        // ----------------------------------------------------------------------
        // PHASE 3: SESSIONS/SESSIONS with invalid session type (top byte)
        // Maps to: s_response_code <= TPM_RC_HANDLE (earlier branch)
        // ----------------------------------------------------------------------
        #40;
        max_session_amount  = 2'd1;
        command_ready   = 1'b1;
        command_tag     = TPM_ST_SESSIONS;
        command_code    = {8'h0E, TPM_CC_CLEAR}; // SESSIONS inside DUT
        command_size    = 32'd8;
        command_length  = 16'd8;

        session0_handle     = {8'hAA, 24'h000000}; // invalid type 0xAA
        session0_attributes = 8'b00000000;
        session0_valid      = 1'b1;
        session_loaded      = 1'b1;
        auth_session        = 1'b1;
        #40;
        command_ready = 1'b0;

        // ----------------------------------------------------------------------
        // PHASE 4: SESSIONS/SESSIONS, valid type but NOT LOADED
        // Maps to: s_response_code <= TPM_RC_REFERENCE_S0 + session_index
        // ----------------------------------------------------------------------
        #40;
        command_ready   = 1'b1;
        command_tag     = TPM_ST_SESSIONS;
        command_code    = {8'h0E, TPM_CC_CLEAR};
        command_size    = 32'd8;
        command_length  = 16'd8;
        // choose lane1 semantics by populating lane1 (DUT selects via internal index)
        session0_handle     = {TPM_HT_HMAC_SESSION,24'h000000};
        session0_attributes = 8'b00000000;
        session0_valid      = 1'b1;

        // still present but mark not loaded
        session_loaded      = 1'b0;
        auth_session        = 1'b1;
        max_session_amount  = 2'd1;
        #40;
        command_ready = 1'b0;

        // ----------------------------------------------------------------------
        // PHASE 5: SESSIONS/SESSIONS AUTHSIZE (max == index && authorization_size > 0)
        // Maps to: s_response_code <= TPM_RC_AUTHSIZE
        // ----------------------------------------------------------------------
        #40;
        command_ready       = 1'b1;
        command_tag         = TPM_ST_SESSIONS;
        command_code        = {8'h40, TPM_CC_CLEAR};
        command_size        = 32'd8;
        command_length      = 16'd8;

        session0_handle     = {8'h00,24'h000000};
        session0_attributes = 8'b10000000;
        session0_valid      = 1'b1;

        session_loaded      = 1'b1;
        auth_session        = 1'b1;

        max_session_amount  = 2'd3;
        authorization_size  = 32'd8;
        #40;
        command_ready       = 1'b0;
        authorization_size  = 32'd0;

        // ----------------------------------------------------------------------
        // PHASE 6: SESSIONS/SESSIONS ATTRIBUTES (none of flags set)
        // Maps to: s_response_code <= TPM_RC_ATTRIBUTES
        // ----------------------------------------------------------------------
        #40;
        command_ready       = 1'b1;
        command_tag         = TPM_ST_SESSIONS;
        command_code        = {8'h0E, TPM_CC_CLEAR};
        command_size        = 32'd8;
        command_length      = 16'd8;

        session0_handle     = {8'h00,24'h000000};
        session0_attributes = 8'b00000000; // no audit/decrypt/encrypt/auth bits
        session0_valid      = 1'b1;
        max_session_amount  = 2'd1;
        session_loaded      = 1'b1;
        auth_session        = 1'b0;
        #40;
        command_ready       = 1'b0;

        // ----------------------------------------------------------------------
        // PHASE 7: SESSIONS/SESSIONS AUTH_MISSING (required but auth_session=0)
        // Maps to: s_response_code <= TPM_RC_AUTH_MISSING
        // ----------------------------------------------------------------------
        #40;
        max_session_amount  = 2'd3;
        command_ready       = 1'b1;
        command_tag         = TPM_ST_SESSIONS;
        command_code        = {8'h0E, TPM_CC_CLEAR};
        command_size        = 32'd8;
        command_length      = 16'd8;

        session0_handle     = {TPM_HT_HMAC_SESSION,24'h000000};
        session0_attributes = 8'b10000000;
        session0_valid      = 1'b1;
	session0_hmac_size = 16'd5;

        session1_handle     = {TPM_HT_HMAC_SESSION,24'h000000};
        session1_attributes = 8'b01000000;
        session1_valid      = 1'b1;
	session1_hmac_size = 16'd5;

        session2_handle     = {TPM_HT_HMAC_SESSION,24'h000000};
	session2_hmac_size = 16'd5;
        session2_attributes = 8'b10000000;
        session2_valid      = 1'b1;
        session_loaded      = 1'b1;
        auth_session        = 1'b1;    
        auth_necessary      = 1'b1;    
        #40;
        command_ready       = 1'b0;

        // ----------------------------------------------------------------------
        // Finish
        // ----------------------------------------------------------------------
        #80;
 
    end

endmodule

