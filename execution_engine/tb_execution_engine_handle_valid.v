`timescale 1ns/1ps

module tb_execution_engine_handle_valid();

    localparam TPM_CC_NV_UNDEFINE_SPACE_SPECIAL = 16'h011F,
               TPM_CC_EVICT_CONTROL            = 16'h0120,
               TPM_CC_HIERARCHY_CONTROL        = 16'h0121,
               TPM_CC_NV_UNDEFINE_SPACE        = 16'h0122,
               TPM_CC_CHANGE_EPS               = 16'h0124,
               TPM_CC_CHANGE_PPS               = 16'h0125,
               TPM_CC_CLEAR                    = 16'h0126,  // TPM2_Clear
               TPM_CC_CLEAR_CONTROL            = 16'h0127,
               TPM_CC_CLOCK_SET                = 16'h0128,
               TPM_CC_HIERARCHY_CHANGE_AUTH    = 16'h0129,
               TPM_CC_NV_DEFINE_SPACE          = 16'h012A,
               TPM_CC_PCR_ALLOCATE             = 16'h012B,
               TPM_CC_PCR_SET_AUTH_POLICY      = 16'h012C,
               TPM_CC_PP_COMMANDS              = 16'h012D,
               TPM_CC_SET_PRIMARY_POLICY       = 16'h012E,
               // FieldUpgradeStart (0x0000012F) and FieldUpgradeData (0x00000141) are *not* supported in this implementation
               TPM_CC_CLOCK_RATE_ADJUST        = 16'h0130,
               TPM_CC_CREATE_PRIMARY           = 16'h0131,
               TPM_CC_NV_GLOBAL_WRITE_LOCK     = 16'h0132,
               TPM_CC_GET_COMMAND_AUDIT_DIGEST = 16'h0133,
               TPM_CC_NV_INCREMENT             = 16'h0134,
               TPM_CC_NV_SET_BITS              = 16'h0135,
               TPM_CC_NV_EXTEND                = 16'h0136,
               TPM_CC_NV_WRITE                 = 16'h0137,
               TPM_CC_NV_WRITE_LOCK            = 16'h0138,
               TPM_CC_DICTIONARY_ATTACK_LOCK_RESET = 16'h0139,
               TPM_CC_DICTIONARY_ATTACK_PARAMETERS = 16'h013A,
               TPM_CC_NV_CHANGE_AUTH           = 16'h013B,
               TPM_CC_PCR_EVENT                = 16'h013C,
               TPM_CC_PCR_RESET                = 16'h013D,
               TPM_CC_SEQUENCE_COMPLETE        = 16'h013E,
               TPM_CC_SET_ALGORITHM_SET        = 16'h013F,
               TPM_CC_SET_COMMAND_CODE_AUDIT_STATUS = 16'h0140,
               TPM_CC_INCREMENTAL_SELF_TEST    = 16'h0142,
               TPM_CC_SELF_TEST                = 16'h0143,
               TPM_CC_STARTUP                  = 16'h0144,  // TPM2_Startup
               TPM_CC_SHUTDOWN                 = 16'h0145,
               TPM_CC_STIR_RANDOM              = 16'h0146,
               TPM_CC_ACTIVATE_CREDENTIAL      = 16'h0147,
               TPM_CC_CERTIFY                  = 16'h0148,
               TPM_CC_POLICY_NV                = 16'h0149,
               TPM_CC_CERTIFY_CREATION         = 16'h014A,
               TPM_CC_DUPLICATE                = 16'h014B,
               TPM_CC_GET_TIME                 = 16'h014C,
               TPM_CC_GET_SESSION_AUDIT_DIGEST = 16'h014D,
               TPM_CC_NV_READ                  = 16'h014E,
               TPM_CC_NV_READ_LOCK             = 16'h014F,
               TPM_CC_OBJECT_CHANGE_AUTH       = 16'h0150,
               TPM_CC_POLICY_SECRET            = 16'h0151,
               TPM_CC_REWRAP                   = 16'h0152,
               TPM_CC_CREATE                   = 16'h0153,
               TPM_CC_ECDH_ZGEN                = 16'h0154,
               TPM_CC_HMAC                     = 16'h0155,
               TPM_CC_IMPORT                   = 16'h0156,
               TPM_CC_LOAD                     = 16'h0157,
               TPM_CC_QUOTE                    = 16'h0158,
               TPM_CC_RSA_DECRYPT              = 16'h0159,
               TPM_CC_HMAC_START               = 16'h015B,
               TPM_CC_SEQUENCE_UPDATE          = 16'h015C,
               TPM_CC_SIGN                     = 16'h015D,
               TPM_CC_UNSEAL                   = 16'h015E,
               TPM_CC_POLICY_SIGNED            = 16'h0160,
               TPM_CC_CONTEXT_LOAD             = 16'h0161,
               TPM_CC_CONTEXT_SAVE             = 16'h0162,
               TPM_CC_ECDH_KEY_GEN             = 16'h0163,
               TPM_CC_ENCRYPT_DECRYPT          = 16'h0164,
               TPM_CC_FLUSH_CONTEXT            = 16'h0165,
               TPM_CC_LOAD_EXTERNAL            = 16'h0167,
               TPM_CC_MAKE_CREDENTIAL          = 16'h0168,
               TPM_CC_NV_READ_PUBLIC           = 16'h0169,
               TPM_CC_POLICY_AUTHORIZE         = 16'h016A,
               TPM_CC_POLICY_AUTH_VALUE        = 16'h016B,
               TPM_CC_POLICY_COMMAND_CODE      = 16'h016C,
               TPM_CC_POLICY_COUNTER_TIMER     = 16'h016D,
               TPM_CC_POLICY_CP_HASH           = 16'h016E,
               TPM_CC_POLICY_LOCALITY          = 16'h016F,
               TPM_CC_POLICY_NAME_HASH         = 16'h0170,
               TPM_CC_POLICY_OR                = 16'h0171,
               TPM_CC_POLICY_TICKET            = 16'h0172,
               TPM_CC_READ_PUBLIC              = 16'h0173,
               TPM_CC_RSA_ENCRYPT              = 16'h0174,
               TPM_CC_START_AUTH_SESSION       = 16'h0176,
               TPM_CC_VERIFY_SIGNATURE         = 16'h0177,
               TPM_CC_ECC_PARAMETERS           = 16'h0178,
               TPM_CC_FIRMWARE_READ            = 16'h0179,
               TPM_CC_GET_CAPABILITY           = 16'h017A,
               TPM_CC_GET_RANDOM               = 16'h017B,
               TPM_CC_GET_TEST_RESULT          = 16'h017C,  // TPM2_GetTestResult
               TPM_CC_HASH                     = 16'h017D,
               TPM_CC_PCR_READ                 = 16'h017E,
               TPM_CC_POLICY_PCR               = 16'h017F,
               TPM_CC_POLICY_RESTART           = 16'h0180,
               TPM_CC_READ_CLOCK               = 16'h0181,
               TPM_CC_PCR_EXTEND               = 16'h0182,
               TPM_CC_PCR_SET_AUTH_VALUE       = 16'h0183,
               TPM_CC_NV_CERTIFY               = 16'h0184,
               TPM_CC_EVENT_SEQUENCE_COMPLETE  = 16'h0185,
               TPM_CC_HASH_SEQUENCE_START      = 16'h0186,
               TPM_CC_POLICY_PHYSICAL_PRESENCE = 16'h0187,
               TPM_CC_POLICY_DUPLICATION_SELECT= 16'h0188,
               TPM_CC_POLICY_GET_DIGEST        = 16'h0189,
               TPM_CC_TEST_PARMS               = 16'h018A,
               TPM_CC_COMMIT                   = 16'h018B,
               TPM_CC_POLICY_PASSWORD          = 16'h018C,
               TPM_CC_ZGEN_2PHASE              = 16'h018D,
               TPM_CC_EC_EPHEMERAL             = 16'h018E,
               TPM_CC_POLICY_NV_WRITTEN        = 16'h018F,
               TPM_CC_POLICY_TEMPLATE          = 16'h0190,
               TPM_CC_CREATE_LOADED            = 16'h0191,
               TPM_CC_POLICY_AUTHORIZE_NV      = 16'h0192,
               TPM_CC_ENCRYPT_DECRYPT_2        = 16'h0193,
               TPM_CC_AC_GET_CAPABILITY        = 16'h0194,
               TPM_CC_AC_SEND                  = 16'h0195,
               TPM_CC_POLICY_AC_SEND_SELECT    = 16'h0196;
	// ============================================================================
	// COMMAND TAGS AND CODES
	// ============================================================================
    localparam TPM_ST_NO_SESSIONS = 16'h8001,	// Command has no sessions
	       TPM_ST_SESSIONS    = 16'h8002;	// Command has sessions
	// ============================================================================
	// PERMANENT HANDLES
	// ============================================================================
    localparam TPM_RH_PLATFORM  = 32'h4000000C,	// Handle references the Platform Primary Seed (PPS), platformAuth, and platformPolicy
	       TPM_RH_OWNER    	 = 32'h40000001,	// Handle references the Storage Primary Seed (SPS), the ownerAuth, and the ownerPolicy
	       TPM_RH_ENDORSEMENT = 32'h4000000B,	// Handle references the Endorsement Primary Seed (EPS), endorsementAuth, and endorsementPolicy
	       TPM_RH_NULL		  	 = 32'h40000007,	// A handle associated with the null hierarchy, and Empty Auth authValue, and an Empty Policy authPolicy
               TPM_RS_PW			 = 32'h40000009;  // authorization value used to indicate a password authorization session

// =========================
// Clock / reset scaffolding
// =========================
reg  clk;                // Locally-created clock
reg  reset_n;            // Locally-created active-low reset
localparam CLK_PERIOD = 20; // 20 ns -> 50 MHz

// Clock generator
always #(CLK_PERIOD/2) clk = ~clk;

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
    .clock                (clk),
    .reset_n              (reset_n),
    .command_ready        (command_ready),
    .command_tag          (command_tag),
    .command_size         (command_size),
    .command_code         (command_code),
    .command_length       (command_length),
    // command buffer inputs
    .handle_0             (handle_0),
    .handle_1             (handle_1),
    .handle_2             (handle_2),
    .session0_handle      (session0_handle),
    .session1_handle      (session1_handle),
    .session2_handle      (session2_handle),
    .session0_attributes  (session0_attributes),
    .session1_attributes  (session1_attributes),
    .session2_attributes  (session2_attributes),
    .session0_hmac_size   (session0_hmac_size),
    .session1_hmac_size   (session1_hmac_size),
    .session2_hmac_size   (session2_hmac_size),
    .session0_valid       (session0_valid),
    .session1_valid       (session1_valid),
    .session2_valid       (session2_valid),
    .authorization_size   (authorization_size),
    .session_loaded       (session_loaded),
    .max_session_amount   (max_session_amount),
    .auth_session         (auth_session),
    .auth_necessary       (auth_necessary),
    .authHandle           (authHandle),
    .pcrSelect            (pcrSelect),
    // Authorization submodule inputs
    .auth_success         (auth_success),
    .auth_done            (auth_done),
    .auth_response_code   (auth_response_code),
    // param decrypt / unmarshall submodule inputs
    .param_decrypt_success(param_decrypt_success),
    .param_decrypt_fail   (param_decrypt_fail),
    .param_unmarshall_success(param_unmarshall_success),
    .param_unmarshall_fail(param_unmarshall_fail),

    .execution_startup_done(execution_startup_done),
    .execution_response_code(execution_response_code),
    // NV memory submodule inputs
    .nv_phEnableNV_in     (nv_phEnableNV_in),
    .nv_shEnable_in       (nv_shEnable_in),
    .nv_ehEnable_in       (nv_ehEnable_in),
    .tpm_nv_index         (tpm_nv_index),
    .nv_index_attributes  (nv_index_attributes),
    .nv_object_present    (nv_object_present),
    .nv_index_present     (nv_index_present),
    .entity_hierarchy     (entity_hierarchy),
    // Memory submodule inputs
    .mem_orderly          (mem_orderly),
    .ram_available        (ram_available),
    .loaded_object_present(loaded_object_present),
    .object_attributes    (object_attributes),
    // Self-test submodule inputs
    .st_testsRun          (st_testsRun),
    .st_testsPassed       (st_testsPassed),
    .st_untested          (st_untested),
    // Management module inputs
    .op_state             (op_state),
    .startup_type         (startup_type),
    .phEnable             (phEnable),
    .phEnableNV           (phEnableNV),
    .shEnable             (shEnable),
    .ehEnable             (ehEnable),
    .shutdownSave         (shutdownSave),
    .command_done         (command_done),
    // management outputs
    .testsPassed          (testsPassed),
    .untested             (untested),
    .nv_phEnableNV        (nv_phEnableNV),
    .nv_shEnable          (nv_shEnable),
    .nv_ehEnable          (nv_ehEnable),
    .orderlyInput         (orderlyInput),
    .initialized          (initialized),
    .testsRun             (testsRun),
    .authHierarchy        (authHierarchy),
    // Response outputs
    .response_valid       (response_valid),
    .response_code        (response_code),
    .response_length      (response_length),
    .current_state        (current_state),
    .command_start        (command_start)
);

// ==========================
// Default initialization only
// ==========================
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
    #20
    reset_n = 1'b1;
    /////////////////////////////////////////////////
    /// Test for TPM_RC_VALUE in STATE_HANDLE_VALID
    //////////////////////////////////////////////////
    #100;
    reset_n = 1'b1;
    command_code = TPM_CC_STARTUP | 32'h0E000000; 
    command_ready = 1'b1;
    command_tag = TPM_ST_NO_SESSIONS;
    command_size = 16'd2;
    command_length = 16'd2;
    /////////////////////////////////////////////////
    /// Test for TPM_RC_REFRENCE_H0 in STATE_HANDLE_VALID
    //////////////////////////////////////////////////
    #40;
    command_ready = 1'b0;
    #100
    command_code = TPM_CC_HIERARCHY_CONTROL; 
    command_ready = 1'b1;
    command_tag = TPM_ST_NO_SESSIONS;
    command_size = 16'd2;
    command_length = 16'd2;
    handle_0 = 32'h80000000;
    loaded_object_present = 1'b0;
    ////////////////////////////////////////////////////////////////////////////////////////
    /// Test for TPM_RC_HANDLE in STATE_HANDLE_VALID  WITH handle_type = TPM_HT_PERSISNTENT
    ////////////////////////////////////////////////////////////////////////////////////////
    #40;
    command_ready = 1'b0;
    #100
    command_code = TPM_CC_HIERARCHY_CONTROL; 
    command_ready = 1'b1;
    command_tag = TPM_ST_NO_SESSIONS;
    command_size = 16'd2;
    command_length = 16'd2;
    handle_0 = 32'h81000000;
    loaded_object_present = 1'b0;
    phEnable = 1'b0;
    nv_object_present     = 1'b1;
    entity_hierarchy = TPM_RH_PLATFORM;
    /////////////////////////////////////////////////////////////
    /// Test for TPM_RC_OBJECT_MEMORY in STATE_HANDLE_VALID
    /////////////////////////////////////////////////////////////
    #40;
    command_ready = 1'b0;
    #100
    command_code = TPM_CC_HIERARCHY_CONTROL; 
    command_ready = 1'b1;
    command_tag = TPM_ST_NO_SESSIONS;
    command_size = 16'd2;
    command_length = 16'd2;
    handle_0 = 32'h81000000;
    loaded_object_present = 1'b0;
    phEnable = 1'b1;
    nv_object_present     = 1'b1;
    entity_hierarchy = TPM_RH_PLATFORM;
    ram_available = 1'b0;
    ////////////////////////////////////////////////////////////////////////////////////
    /// Test for TPM_RC_HANDLE in STATE_HANDLE_VALID WITH handle_type = TPM_HT_NV_INDEX
    ////////////////////////////////////////////////////////////////////////////////////
    #40;
    command_ready = 1'b0;
    #100
    command_code = TPM_CC_HIERARCHY_CONTROL; 
    command_ready = 1'b1;
    command_tag = TPM_ST_NO_SESSIONS;
    command_size = 16'd2;
    command_length = 16'd2;
    handle_0 = 32'h01000000;
    loaded_object_present = 1'b0;
    phEnable = 1'b0;
    entity_hierarchy = TPM_RH_PLATFORM;

    #40;
    command_ready = 1'b0;
end

endmodule
