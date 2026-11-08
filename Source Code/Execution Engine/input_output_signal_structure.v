////////////////////////////////////////////////////////////////////////////////////////
// Filename:      input_output_signal_structure.v
// Author:        Michael
// Version:       1.0
// Description:  General structure for control signals. 13 separate modules.
//	Each module has a combinational always block for setting outputs.
// Each module has a sequential always block for state transistions.
//
//
///////////////////////////////////////////////////////////////////////////


module execution_engine_fsm (
    input wire clock_i,
    input wire rst_n_i,
    
    // Control FSM Interface
    input wire command_start_i,           
    input wire [31:0] command_code_i,    
    output reg execution_complete_signal_o,
    output reg execution_error_signal_o,
    input wire control_ack_i,
    
    // Authorization Module Signals
    output reg auth_session_validate_o,
    output reg [3:0] auth_handle_count_o,
    input wire auth_success_i,
    input wire auth_fail_i,
    input wire policy_valid_i,
    input wire policy_invalid_i,
    
    // Non-Volatile Memory Module Signals
    output reg nvm_read_enable_o,
    output reg nvm_delete_enable_o,
    output reg nvm_policy_delete_o,
    output reg nvm_range_check_o,
    output reg nvm_operation_type_o,
    output reg nvm_disable_access_o,
    output reg nvm_flush_hierarchy_o,
    output reg nvm_sync_persistent_o,
    input wire nvm_index_valid_i,
    input wire nvm_index_invalid_i,
    input wire nvm_attributes_ok_i,
    input wire nvm_attributes_bad_i,
    input wire nvm_auth_match_i,
    input wire nvm_auth_mismatch_i,
    input wire nvm_delete_complete_i,
    input wire nvm_delete_fail_i,
    input wire nvm_success_i,
    input wire nvm_range_valid_i,
    input wire nvm_range_invalid_i,
    input wire nvm_operation_complete_i,
    input wire nvm_operation_fail_i,
    input wire nvm_disable_required_i,
    input wire nvm_disable_not_required_i,
    input wire nvm_disable_complete_i,
    input wire nvm_disable_fail_i,
    input wire nvm_flush_complete_i,
    input wire nvm_sync_complete_i,
    
    // Volatile Memory Module Signals
    output reg vm_object_read_enable_o,
    output reg vm_hierarchy_check_o,
    output reg vm_hierarchy_read_o,
    output reg vm_flush_hierarchy_o,
    output reg vm_session_cleanup_o,
    output reg vm_update_hierarchy_o,
    output reg vm_flush_decision_o,
    output reg vm_hierarchy_update_o,
    output reg vm_eh_enable_o,
    output reg vm_clear_endorsement_auth_o,
    output reg vm_clear_endorsement_policy_o,
    input wire vm_object_valid_i,
    input wire vm_object_invalid_i,
    input wire vm_attributes_ok_i,
    input wire vm_attributes_bad_i,
    input wire vm_hierarchy_ok_i,
    input wire vm_hierarchy_bad_i,
    input wire vm_validation_ok_i,
    input wire vm_validation_fail_i,
    input wire vm_flush_complete_i,
    input wire vm_flush_fail_i,
    input wire vm_cleanup_complete_i,
    input wire vm_cleanup_fail_i,
    input wire vm_update_complete_i,
    input wire vm_update_fail_i,
    input wire flush_required_i,
    input wire flush_not_required_i,
    
    // Asymmetric Engine Signals
    output reg asym_engine_enable_o,
    input wire asym_engine_complete_i,
    input wire asym_engine_fail_i,
    
    // Hash Engine Signals
    output reg hash_engine_enable_o,
    input wire hash_engine_complete_i,
    input wire hash_engine_fail_i,
    
    // Symmetric Engine Signals
    output reg sym_engine_enable_o,
    input wire sym_engine_complete_i,
    input wire sym_engine_fail_i,
    
    // Key Generation Signals
    output reg keygen_enable_o,
    input wire keygen_complete_i,
    input wire keygen_fail_i,
    
    // RNG Signals
    output reg rng_generate_enable_o,
    output reg [15:0] rng_data_size_o,
    input wire rng_generate_complete_i,
    input wire rng_generate_fail_i,
    
    // Power Detection Signals
    output reg power_orderly_check_o,
    output reg power_nv_check_o,
    input wire power_orderly_ok_i,
    input wire power_orderly_fail_i,
    input wire power_nv_available_i,
    input wire power_nv_unavailable_i,
    
    // Clock Tick Module Signals
    output reg clock_tick_enable_o,
    input wire clock_tick_complete_i,
    
    // General Control Signals
    output reg [31:0] response_code_o,
	 output reg execution_startup_done_o

);

    // State Definitions 
    localparam [3:0] EXECUTION_IDLE           = 4'd0,
                     EXECUTION_START          = 4'd1,
                     S_AUTHORIZATION          = 4'd2,
                     S_ASYM_ENGINE            = 4'd3,
                     S_HASH_ENGINE            = 4'd4,
                     S_SYM_ENGINE             = 4'd5,
                     S_NVM                    = 4'd6,
                     S_VM                     = 4'd7,
                     S_KEYGEN                 = 4'd8,
                     S_RNG                    = 4'd9,
                     S_POWER_DETECTION        = 4'd10,
                     S_CLOCK_TICK             = 4'd11,
                     EXECUTION_DONE           = 4'd12,
                     EXECUTION_ERROR          = 4'd13;
    
    // TPM Command Codes
    localparam [31:0] TPM_CC_NV_UndefineSpaceSpecial = 32'h0000011F,
                      TPM_CC_EvictControl             = 32'h00000120,
                      TPM_CC_HierarchyControl         = 32'h00000121,
                      TPM_CC_NV_UndefineSpace         = 32'h00000122,
                      TPM_CC_ChangeEPS                = 32'h00000124;
	localparam [31:0] TPM_CC_Startup = 32'h00000144; // need to change this
    
    // TPM Response Codes
    localparam [31:0] TPM_RC_SUCCESS     = 32'h00000000,
                      TPM_RC_HANDLE      = 32'h0000008B,
                      TPM_RC_ATTRIBUTES  = 32'h00000012,
                      TPM_RC_AUTH_FAIL   = 32'h0000008E,
                      TPM_RC_RANGE       = 32'h00000013,
                      TPM_RC_NV_DEFINED  = 32'h0000014C,
                      TPM_RC_NV_SPACE    = 32'h0000014B,
                      TPM_RC_HIERARCHY   = 32'h00000085,
                      TPM_RC_AUTH_TYPE   = 32'h00000124;
    
    // State Register
    reg [3:0] state, next_state;
    
    // Additional state tracking registers
    reg [3:0] nvm_operation_state;
    reg [3:0] command_phase;
	 
    
    // SEQUENTIAL BLOCK 	
    always @(posedge clock_i or negedge rst_n_i) begin
        if (!rst_n_i) begin
            state <= EXECUTION_IDLE;
        end else begin
            state <= next_state;
        end
    end
	 
	
	
    
    // COMBINATIONAL BLOCK
    always @(*) begin
       
        next_state = state;
        
        // Authorization Module Signals
        auth_session_validate_o = 1'b0;
        auth_handle_count_o = 4'd0;
        
        // NVM Module Signals
        nvm_read_enable_o = 1'b0;
        nvm_delete_enable_o = 1'b0;
        nvm_policy_delete_o = 1'b0;
        nvm_range_check_o = 1'b0;
        nvm_operation_type_o = 1'b0;
        nvm_disable_access_o = 1'b0;
        nvm_flush_hierarchy_o = 1'b0;
        nvm_sync_persistent_o = 1'b0;
        
        // VM Module Signals
        vm_object_read_enable_o = 1'b0;
        vm_hierarchy_check_o = 1'b0;
        vm_hierarchy_read_o = 1'b0;
        vm_flush_hierarchy_o = 1'b0;
        vm_session_cleanup_o = 1'b0;
        vm_update_hierarchy_o = 1'b0;
        vm_flush_decision_o = 1'b0;
        vm_hierarchy_update_o = 1'b0;
        vm_eh_enable_o = 1'b0;
        vm_clear_endorsement_auth_o = 1'b0;
        vm_clear_endorsement_policy_o = 1'b0;
        
        // Engine Signals
        asym_engine_enable_o = 1'b0;
        hash_engine_enable_o = 1'b0;
        sym_engine_enable_o = 1'b0;
        keygen_enable_o = 1'b0;
        
        // RNG Signals
        rng_generate_enable_o = 1'b0;
        rng_data_size_o = 16'd0;
        
        // Power Detection Signals
        power_orderly_check_o = 1'b0;
        power_nv_check_o = 1'b0;
        
        // Clock Tick Signals
        clock_tick_enable_o = 1'b0;
        
        // Control FSM Interface
        execution_complete_signal_o = 1'b0;
        execution_error_signal_o = 1'b0;
        response_code_o = TPM_RC_SUCCESS;
		  execution_startup_done_o = 1'b0;
        
        // FSM State Machine Logic
        case (state)
            
            // EXECUTION_IDLE 
            EXECUTION_IDLE: begin
                if (command_start_i == 1'b1) begin
                    next_state = EXECUTION_START;
                end else begin
                    next_state = EXECUTION_IDLE;
                end
            end
            
            
            // EXECUTION_START
            
            EXECUTION_START: begin
                
                if (command_start_i == 1'b1) begin
                    case (command_code_i)
                        TPM_CC_NV_UndefineSpaceSpecial: begin
                            nvm_read_enable_o = 1'b1;
                            next_state = S_AUTHORIZATION;
                        end
                        
                        TPM_CC_EvictControl: begin
                            vm_object_read_enable_o = 1'b1;
                            next_state = S_AUTHORIZATION;
                        end
                        
                        TPM_CC_HierarchyControl: begin
                            next_state = S_AUTHORIZATION;
                        end
                        
                        TPM_CC_NV_UndefineSpace: begin
                            nvm_read_enable_o = 1'b1;
                            next_state = S_AUTHORIZATION;
                        end
                        
                        TPM_CC_ChangeEPS: begin
                            next_state = S_AUTHORIZATION;
                        end
                        
                        default: begin
                            next_state = EXECUTION_ERROR;
                            response_code_o = TPM_RC_HANDLE;
                        end
                    endcase
                end else begin
                   
                    next_state = EXECUTION_START;
                end
            end
            
            
            // S_AUTHORIZATION 
            
            S_AUTHORIZATION: begin
                auth_session_validate_o = 1'b1;
                
                case (command_code_i)
                    TPM_CC_NV_UndefineSpaceSpecial: begin
                        auth_handle_count_o = 4'd2; // Two authorizations required
                        if (auth_success_i == 1'b1 && policy_valid_i == 1'b1) begin
                            next_state = S_NVM;
                        end else if (auth_fail_i == 1'b1 || policy_invalid_i == 1'b1) begin
                            next_state = EXECUTION_ERROR;
                            response_code_o = TPM_RC_AUTH_FAIL;
                        end else begin
                            next_state = S_AUTHORIZATION;
                        end
                    end
                    
                    TPM_CC_EvictControl: begin
                        auth_handle_count_o = 4'd1;
                        if (auth_success_i == 1'b1) begin
                            next_state = S_VM;
                        end else if (auth_fail_i == 1'b1) begin
                            next_state = EXECUTION_ERROR;
                            response_code_o = TPM_RC_AUTH_FAIL;
                        end else begin
                            next_state = S_AUTHORIZATION;
                        end
                    end
                    
                    TPM_CC_HierarchyControl: begin
                        auth_handle_count_o = 4'd1;
                        if (auth_success_i == 1'b1) begin
                            next_state = S_VM;
                        end else if (auth_fail_i == 1'b1) begin
                            next_state = EXECUTION_ERROR;
                            response_code_o = TPM_RC_AUTH_FAIL;
                        end else begin
                            next_state = S_AUTHORIZATION;
                        end
                    end
                    
                    TPM_CC_NV_UndefineSpace: begin
                        auth_handle_count_o = 4'd1;
                        if (auth_success_i == 1'b1) begin
                            next_state = S_NVM;
                        end else if (auth_fail_i == 1'b1) begin
                            next_state = EXECUTION_ERROR;
                            response_code_o = TPM_RC_AUTH_FAIL;
                        end else begin
                            next_state = S_AUTHORIZATION;
                        end
                    end
                    
                    TPM_CC_ChangeEPS: begin
                        auth_handle_count_o = 4'd1;
                        if (auth_success_i == 1'b1) begin
                            next_state = S_POWER_DETECTION;
                        end else if (auth_fail_i == 1'b1) begin
                            next_state = EXECUTION_ERROR;
                            response_code_o = TPM_RC_AUTH_FAIL;
                        end else begin
                            next_state = S_AUTHORIZATION;
                        end
                    end
                    
                    default: begin
                        next_state = EXECUTION_ERROR;
                        response_code_o = TPM_RC_HANDLE;
                    end
                endcase
            end
            
            
            // S_NVM
            
            S_NVM: begin
                case (command_code_i)
                    TPM_CC_NV_UndefineSpaceSpecial: begin
                        nvm_read_enable_o = 1'b1;
                        if (nvm_index_valid_i == 1'b1 && nvm_attributes_ok_i == 1'b1) begin
                            nvm_delete_enable_o = 1'b1;
                            nvm_policy_delete_o = 1'b1;
                            if (nvm_delete_complete_i == 1'b1 && nvm_success_i == 1'b1) begin
                                next_state = S_VM;
                            end else if (nvm_delete_fail_i == 1'b1) begin
                                next_state = EXECUTION_ERROR;
                                 response_code_o = TPM_RC_HANDLE;
                            end else begin
                                next_state = S_NVM;
                            end
                        end else if (nvm_index_invalid_i == 1'b1 || nvm_attributes_bad_i == 1'b1) begin
                            next_state = EXECUTION_ERROR;
                            response_code_o = TPM_RC_ATTRIBUTES;
                        end else begin
                            next_state = S_NVM;
                        end
                    end
                    
                    TPM_CC_EvictControl: begin
                        nvm_range_check_o = 1'b1;
                        if (nvm_range_valid_i == 1'b1) begin
                            if (nvm_operation_complete_i == 1'b1 && nvm_success_i == 1'b1) begin
                                next_state = EXECUTION_DONE;
                            end else if (nvm_operation_fail_i == 1'b1) begin
                                next_state = EXECUTION_ERROR;
                                response_code_o = TPM_RC_NV_SPACE;
                            end else begin
                                next_state = S_NVM;
                            end
                        end else if (nvm_range_invalid_i == 1'b1) begin
                            next_state = EXECUTION_ERROR;
                            response_code_o = TPM_RC_RANGE;
                        end else begin
                            next_state = S_NVM;
                        end
                    end
                    
                    TPM_CC_NV_UndefineSpace: begin
                        nvm_read_enable_o = 1'b1;
                        if (nvm_index_valid_i == 1'b1 && nvm_attributes_ok_i == 1'b1 && nvm_auth_match_i == 1'b1) begin
                            nvm_delete_enable_o = 1'b1;
                            if (nvm_delete_complete_i == 1'b1 && nvm_success_i == 1'b1) begin
                                next_state = S_VM;
                            end else if (nvm_delete_fail_i == 1'b1) begin
                                next_state = EXECUTION_ERROR;
                                response_code_o = TPM_RC_HANDLE;
                            end else begin
                                next_state = S_NVM;
                            end
                        end else if (nvm_index_invalid_i == 1'b1 || nvm_attributes_bad_i == 1'b1 || nvm_auth_mismatch_i == 1'b1) begin
                            next_state = EXECUTION_ERROR;
                            response_code_o = TPM_RC_AUTH_TYPE;
                        end else begin
                            next_state = S_NVM;
                        end
                    end
                    
                    TPM_CC_ChangeEPS: begin
                        nvm_flush_hierarchy_o = 1'b1;
                        if (nvm_flush_complete_i == 1'b1) begin
                            nvm_sync_persistent_o = 1'b1;
                            if (nvm_sync_complete_i == 1'b1) begin
                                next_state = EXECUTION_DONE;
                            end else begin
                                next_state = S_NVM;
                            end
                        end else begin
                            next_state = S_NVM;
                        end
                    end
                    
                    default: begin
                        next_state = EXECUTION_ERROR;
                    end
                endcase
            end
            
            
            // S_VM
            
            S_VM: begin
                case (command_code_i)
                    TPM_CC_NV_UndefineSpaceSpecial: begin
                        vm_session_cleanup_o = 1'b1;
                        if (vm_cleanup_complete_i == 1'b1) begin
                            next_state = EXECUTION_DONE;
                        end else if (vm_cleanup_fail_i == 1'b1) begin
                            next_state = EXECUTION_ERROR;
                        end else begin
                            next_state = S_VM;
                        end
                    end
                    
                    TPM_CC_EvictControl: begin
                        vm_object_read_enable_o = 1'b1;
                        if (vm_object_valid_i == 1'b1 && vm_attributes_ok_i == 1'b1) begin
                            vm_hierarchy_check_o = 1'b1;
                            if (vm_hierarchy_ok_i == 1'b1) begin
                                next_state = S_NVM;
                            end else if (vm_hierarchy_bad_i == 1'b1) begin
                                next_state = EXECUTION_ERROR;
                                response_code_o = TPM_RC_HIERARCHY;
                            end else begin
                                next_state = S_VM;
                            end
                        end else if (vm_object_invalid_i == 1'b1 || vm_attributes_bad_i == 1'b1) begin
                            next_state = EXECUTION_ERROR;
                            response_code_o = TPM_RC_ATTRIBUTES;
                        end else begin
                            next_state = S_VM;
                        end
                    end
                    
                    TPM_CC_HierarchyControl: begin
                        vm_hierarchy_read_o = 1'b1;
                        if (vm_validation_ok_i == 1'b1) begin
                            next_state = S_POWER_DETECTION;
                        end else if (vm_validation_fail_i == 1'b1) begin
                            next_state = EXECUTION_ERROR;
                            response_code_o = TPM_RC_AUTH_TYPE;
                        end else begin
                            next_state = S_VM;
                        end
                    end
                    
                    TPM_CC_NV_UndefineSpace: begin
                        vm_session_cleanup_o = 1'b1;
                        if (vm_cleanup_complete_i == 1'b1) begin
                            next_state = EXECUTION_DONE;
                        end else if (vm_cleanup_fail_i == 1'b1) begin
                            next_state = EXECUTION_ERROR;
                        end else begin
                            next_state = S_VM;
                        end
                    end
                    
                    TPM_CC_ChangeEPS: begin
                        vm_hierarchy_update_o = 1'b1;
                        vm_eh_enable_o = 1'b1;
                        vm_clear_endorsement_auth_o = 1'b1;
                        vm_clear_endorsement_policy_o = 1'b1;
                        if (vm_update_complete_i == 1'b1) begin
                            vm_flush_hierarchy_o = 1'b1;
                            if (vm_flush_complete_i == 1'b1) begin
                                next_state = S_NVM;
                            end else begin
                                next_state = S_VM;
                            end
                        end else begin
                            next_state = S_VM;
                        end
                    end
                    
                    default: begin
                        next_state = EXECUTION_ERROR;
                    end
                endcase
            end
            
            
            // S_ASYM_ENGINE 
            
            S_ASYM_ENGINE: begin
                asym_engine_enable_o = 1'b1;
                if (asym_engine_complete_i == 1'b1) begin
                    next_state = EXECUTION_DONE;
                end else if (asym_engine_fail_i == 1'b1) begin
                    next_state = EXECUTION_ERROR;
                end else begin
                    next_state = S_ASYM_ENGINE;
                end
            end
            
            
            // S_HASH_ENGINE
            
            S_HASH_ENGINE: begin
                hash_engine_enable_o = 1'b1;
                if (hash_engine_complete_i == 1'b1) begin
                    next_state = EXECUTION_DONE;
                end else if (hash_engine_fail_i == 1'b1) begin
                    next_state = EXECUTION_ERROR;
                end else begin
                    next_state = S_HASH_ENGINE;
                end
            end
            
            
            // S_SYM_ENGINE
            
            S_SYM_ENGINE: begin
                sym_engine_enable_o = 1'b1;
                if (sym_engine_complete_i == 1'b1) begin
                    next_state = EXECUTION_DONE;
                end else if (sym_engine_fail_i == 1'b1) begin
                    next_state = EXECUTION_ERROR;
                end else begin
                    next_state = S_SYM_ENGINE;
                end
            end
            
            
            // S_KEYGEN
            
            S_KEYGEN: begin
                keygen_enable_o = 1'b1;
                if (keygen_complete_i == 1'b1) begin
                    next_state = EXECUTION_DONE;
                end else if (keygen_fail_i == 1'b1) begin
                    next_state = EXECUTION_ERROR;
                end else begin
                    next_state = S_KEYGEN;
                end
            end
            
            
            // S_RNG
            
            S_RNG: begin
                rng_generate_enable_o = 1'b1;
                if (command_code_i == TPM_CC_ChangeEPS) begin
                    rng_data_size_o = 16'd32; // Example: 32 bytes for EPS seed
                    if (rng_generate_complete_i == 1'b1) begin
                        next_state = S_VM;
                    end else if (rng_generate_fail_i == 1'b1) begin
                        next_state = EXECUTION_ERROR;
                    end else begin
                        next_state = S_RNG;
                    end
                end else begin
                    if (rng_generate_complete_i == 1'b1) begin
                        next_state = EXECUTION_DONE;
                    end else if (rng_generate_fail_i == 1'b1) begin
                        next_state = EXECUTION_ERROR;
                    end else begin
                        next_state = S_RNG;
                    end
                end
            end
            
            
            
            // EXECUTION_DONE 
            
            EXECUTION_DONE: begin
                execution_complete_signal_o = 1'b1;
                response_code_o = TPM_RC_SUCCESS;
					 
					 if (command_code_i == TPM_CC_Startup) begin
                    execution_startup_done_o = 1'b1;
                end
					 
                if (control_ack_i == 1'b1) begin
                    next_state = EXECUTION_IDLE;
                end else begin
                    next_state = EXECUTION_DONE;
                end
            end
            
            
            // EXECUTION_ERROR
            
            EXECUTION_ERROR: begin
                execution_error_signal_o = 1'b1;
                // response_code_o set by the state that caused the error
					 
			       if (command_code_i == TPM_CC_Startup) begin
                    execution_startup_done_o = 1'b1;
                end
					 
                if (control_ack_i == 1'b1) begin
                    next_state = EXECUTION_IDLE;
                end else begin
                    next_state = EXECUTION_ERROR;
                end
            end
            
            
            // DEFAULT 
            
            default: begin
                next_state = EXECUTION_IDLE;
            end
        endcase
    end

endmodule