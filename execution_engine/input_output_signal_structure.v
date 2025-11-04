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
    input wire clock,
    input wire rst_n,
    
    // Control FSM Interface
    input wire command_start,           
    input wire [31:0] command_code,    
    output reg execution_complete_signal,
    output reg execution_error_signal,
    input wire control_ack,
    
    // Authorization Module Signals
    output reg auth_session_validate,
    output reg [3:0] auth_handle_count,
    input wire auth_success,
    input wire auth_fail,
    input wire policy_valid,
    input wire policy_invalid,
    
    // Non-Volatile Memory Module Signals
    output reg nvm_read_enable,
    output reg nvm_delete_enable,
    output reg nvm_policy_delete,
    output reg nvm_range_check,
    output reg nvm_operation_type,
    output reg nvm_disable_access,
    output reg nvm_flush_hierarchy,
    output reg nvm_sync_persistent,
    input wire nvm_index_valid,
    input wire nvm_index_invalid,
    input wire nvm_attributes_ok,
    input wire nvm_attributes_bad,
    input wire nvm_auth_match,
    input wire nvm_auth_mismatch,
    input wire nvm_delete_complete,
    input wire nvm_delete_fail,
    input wire nvm_success,
    input wire nvm_range_valid,
    input wire nvm_range_invalid,
    input wire nvm_operation_complete,
    input wire nvm_operation_fail,
    input wire nvm_disable_required,
    input wire nvm_disable_not_required,
    input wire nvm_disable_complete,
    input wire nvm_disable_fail,
    input wire nvm_flush_complete,
    input wire nvm_sync_complete,
    
    // Volatile Memory Module Signals
    output reg vm_object_read_enable,
    output reg vm_hierarchy_check,
    output reg vm_hierarchy_read,
    output reg vm_flush_hierarchy,
    output reg vm_session_cleanup,
    output reg vm_update_hierarchy,
    output reg vm_flush_decision,
    output reg vm_hierarchy_update,
    output reg vm_eh_enable,
    output reg vm_clear_endorsement_auth,
    output reg vm_clear_endorsement_policy,
    input wire vm_object_valid,
    input wire vm_object_invalid,
    input wire vm_attributes_ok,
    input wire vm_attributes_bad,
    input wire vm_hierarchy_ok,
    input wire vm_hierarchy_bad,
    input wire vm_validation_ok,
    input wire vm_validation_fail,
    input wire vm_flush_complete,
    input wire vm_flush_fail,
    input wire vm_cleanup_complete,
    input wire vm_cleanup_fail,
    input wire vm_update_complete,
    input wire vm_update_fail,
    input wire flush_required,
    input wire flush_not_required,
    
    // Asymmetric Engine Signals
    output reg asym_engine_enable,
    input wire asym_engine_complete,
    input wire asym_engine_fail,
    
    // Hash Engine Signals
    output reg hash_engine_enable,
    input wire hash_engine_complete,
    input wire hash_engine_fail,
    
    // Symmetric Engine Signals
    output reg sym_engine_enable,
    input wire sym_engine_complete,
    input wire sym_engine_fail,
    
    // Key Generation Signals
    output reg keygen_enable,
    input wire keygen_complete,
    input wire keygen_fail,
    
    // RNG Signals
    output reg rng_generate_enable,
    output reg [15:0] rng_data_size,
    input wire rng_generate_complete,
    input wire rng_generate_fail,
    
    // Power Detection Signals
    output reg power_orderly_check,
    output reg power_nv_check,
    input wire power_orderly_ok,
    input wire power_orderly_fail,
    input wire power_nv_available,
    input wire power_nv_unavailable,
    
    // Clock Tick Module Signals
    output reg clock_tick_enable,
    input wire clock_tick_complete,
    
    // General Control Signals
    output reg [31:0] response_code,
	 output reg execution_startup_done

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
    always @(posedge clock or negedge rst_n) begin
        if (!rst_n) begin
            state <= EXECUTION_IDLE;
        end else begin
            state <= next_state;
        end
    end
	 
	
	
    
    // COMBINATIONAL BLOCK
    always @(*) begin
       
        next_state = state;
        
        // Authorization Module Signals
        auth_session_validate = 1'b0;
        auth_handle_count = 4'd0;
        
        // NVM Module Signals
        nvm_read_enable = 1'b0;
        nvm_delete_enable = 1'b0;
        nvm_policy_delete = 1'b0;
        nvm_range_check = 1'b0;
        nvm_operation_type = 1'b0;
        nvm_disable_access = 1'b0;
        nvm_flush_hierarchy = 1'b0;
        nvm_sync_persistent = 1'b0;
        
        // VM Module Signals
        vm_object_read_enable = 1'b0;
        vm_hierarchy_check = 1'b0;
        vm_hierarchy_read = 1'b0;
        vm_flush_hierarchy = 1'b0;
        vm_session_cleanup = 1'b0;
        vm_update_hierarchy = 1'b0;
        vm_flush_decision = 1'b0;
        vm_hierarchy_update = 1'b0;
        vm_eh_enable = 1'b0;
        vm_clear_endorsement_auth = 1'b0;
        vm_clear_endorsement_policy = 1'b0;
        
        // Engine Signals
        asym_engine_enable = 1'b0;
        hash_engine_enable = 1'b0;
        sym_engine_enable = 1'b0;
        keygen_enable = 1'b0;
        
        // RNG Signals
        rng_generate_enable = 1'b0;
        rng_data_size = 16'd0;
        
        // Power Detection Signals
        power_orderly_check = 1'b0;
        power_nv_check = 1'b0;
        
        // Clock Tick Signals
        clock_tick_enable = 1'b0;
        
        // Control FSM Interface
        execution_complete_signal = 1'b0;
        execution_error_signal = 1'b0;
        response_code = TPM_RC_SUCCESS;
		  execution_startup_done = 1'b0;
        
        // FSM State Machine Logic
        case (state)
            
            // EXECUTION_IDLE 
            EXECUTION_IDLE: begin
                if (command_start == 1'b1) begin
                    next_state = EXECUTION_START;
                end else begin
                    next_state = EXECUTION_IDLE;
                end
            end
            
            
            // EXECUTION_START
            
            EXECUTION_START: begin
                
                if (command_start == 1'b1) begin
                    case (command_code)
                        TPM_CC_NV_UndefineSpaceSpecial: begin
                            nvm_read_enable = 1'b1;
                            next_state = S_AUTHORIZATION;
                        end
                        
                        TPM_CC_EvictControl: begin
                            vm_object_read_enable = 1'b1;
                            next_state = S_AUTHORIZATION;
                        end
                        
                        TPM_CC_HierarchyControl: begin
                            next_state = S_AUTHORIZATION;
                        end
                        
                        TPM_CC_NV_UndefineSpace: begin
                            nvm_read_enable = 1'b1;
                            next_state = S_AUTHORIZATION;
                        end
                        
                        TPM_CC_ChangeEPS: begin
                            next_state = S_AUTHORIZATION;
                        end
                        
                        default: begin
                            next_state = EXECUTION_ERROR;
                            response_code = TPM_RC_HANDLE;
                        end
                    endcase
                end else begin
                   
                    next_state = EXECUTION_START;
                end
            end
            
            
            // S_AUTHORIZATION 
            
            S_AUTHORIZATION: begin
                auth_session_validate = 1'b1;
                
                case (command_code)
                    TPM_CC_NV_UndefineSpaceSpecial: begin
                        auth_handle_count = 4'd2; // Two authorizations required
                        if (auth_success == 1'b1 && policy_valid == 1'b1) begin
                            next_state = S_NVM;
                        end else if (auth_fail == 1'b1 || policy_invalid == 1'b1) begin
                            next_state = EXECUTION_ERROR;
                            response_code = TPM_RC_AUTH_FAIL;
                        end else begin
                            next_state = S_AUTHORIZATION;
                        end
                    end
                    
                    TPM_CC_EvictControl: begin
                        auth_handle_count = 4'd1;
                        if (auth_success == 1'b1) begin
                            next_state = S_VM;
                        end else if (auth_fail == 1'b1) begin
                            next_state = EXECUTION_ERROR;
                            response_code = TPM_RC_AUTH_FAIL;
                        end else begin
                            next_state = S_AUTHORIZATION;
                        end
                    end
                    
                    TPM_CC_HierarchyControl: begin
                        auth_handle_count = 4'd1;
                        if (auth_success == 1'b1) begin
                            next_state = S_VM;
                        end else if (auth_fail == 1'b1) begin
                            next_state = EXECUTION_ERROR;
                            response_code = TPM_RC_AUTH_FAIL;
                        end else begin
                            next_state = S_AUTHORIZATION;
                        end
                    end
                    
                    TPM_CC_NV_UndefineSpace: begin
                        auth_handle_count = 4'd1;
                        if (auth_success == 1'b1) begin
                            next_state = S_NVM;
                        end else if (auth_fail == 1'b1) begin
                            next_state = EXECUTION_ERROR;
                            response_code = TPM_RC_AUTH_FAIL;
                        end else begin
                            next_state = S_AUTHORIZATION;
                        end
                    end
                    
                    TPM_CC_ChangeEPS: begin
                        auth_handle_count = 4'd1;
                        if (auth_success == 1'b1) begin
                            next_state = S_POWER_DETECTION;
                        end else if (auth_fail == 1'b1) begin
                            next_state = EXECUTION_ERROR;
                            response_code = TPM_RC_AUTH_FAIL;
                        end else begin
                            next_state = S_AUTHORIZATION;
                        end
                    end
                    
                    default: begin
                        next_state = EXECUTION_ERROR;
                        response_code = TPM_RC_HANDLE;
                    end
                endcase
            end
            
            
            // S_NVM
            
            S_NVM: begin
                case (command_code)
                    TPM_CC_NV_UndefineSpaceSpecial: begin
                        nvm_read_enable = 1'b1;
                        if (nvm_index_valid == 1'b1 && nvm_attributes_ok == 1'b1) begin
                            nvm_delete_enable = 1'b1;
                            nvm_policy_delete = 1'b1;
                            if (nvm_delete_complete == 1'b1 && nvm_success == 1'b1) begin
                                next_state = S_VM;
                            end else if (nvm_delete_fail == 1'b1) begin
                                next_state = EXECUTION_ERROR;
                                 response_code = TPM_RC_HANDLE;
                            end else begin
                                next_state = S_NVM;
                            end
                        end else if (nvm_index_invalid == 1'b1 || nvm_attributes_bad == 1'b1) begin
                            next_state = EXECUTION_ERROR;
                            response_code = TPM_RC_ATTRIBUTES;
                        end else begin
                            next_state = S_NVM;
                        end
                    end
                    
                    TPM_CC_EvictControl: begin
                        nvm_range_check = 1'b1;
                        if (nvm_range_valid == 1'b1) begin
                            if (nvm_operation_complete == 1'b1 && nvm_success == 1'b1) begin
                                next_state = EXECUTION_DONE;
                            end else if (nvm_operation_fail == 1'b1) begin
                                next_state = EXECUTION_ERROR;
                                response_code = TPM_RC_NV_SPACE;
                            end else begin
                                next_state = S_NVM;
                            end
                        end else if (nvm_range_invalid == 1'b1) begin
                            next_state = EXECUTION_ERROR;
                            response_code = TPM_RC_RANGE;
                        end else begin
                            next_state = S_NVM;
                        end
                    end
                    
                    TPM_CC_NV_UndefineSpace: begin
                        nvm_read_enable = 1'b1;
                        if (nvm_index_valid == 1'b1 && nvm_attributes_ok == 1'b1 && nvm_auth_match == 1'b1) begin
                            nvm_delete_enable = 1'b1;
                            if (nvm_delete_complete == 1'b1 && nvm_success == 1'b1) begin
                                next_state = S_VM;
                            end else if (nvm_delete_fail == 1'b1) begin
                                next_state = EXECUTION_ERROR;
                                response_code = TPM_RC_HANDLE;
                            end else begin
                                next_state = S_NVM;
                            end
                        end else if (nvm_index_invalid == 1'b1 || nvm_attributes_bad == 1'b1 || nvm_auth_mismatch == 1'b1) begin
                            next_state = EXECUTION_ERROR;
                            response_code = TPM_RC_AUTH_TYPE;
                        end else begin
                            next_state = S_NVM;
                        end
                    end
                    
                    TPM_CC_ChangeEPS: begin
                        nvm_flush_hierarchy = 1'b1;
                        if (nvm_flush_complete == 1'b1) begin
                            nvm_sync_persistent = 1'b1;
                            if (nvm_sync_complete == 1'b1) begin
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
                case (command_code)
                    TPM_CC_NV_UndefineSpaceSpecial: begin
                        vm_session_cleanup = 1'b1;
                        if (vm_cleanup_complete == 1'b1) begin
                            next_state = EXECUTION_DONE;
                        end else if (vm_cleanup_fail == 1'b1) begin
                            next_state = EXECUTION_ERROR;
                        end else begin
                            next_state = S_VM;
                        end
                    end
                    
                    TPM_CC_EvictControl: begin
                        vm_object_read_enable = 1'b1;
                        if (vm_object_valid == 1'b1 && vm_attributes_ok == 1'b1) begin
                            vm_hierarchy_check = 1'b1;
                            if (vm_hierarchy_ok == 1'b1) begin
                                next_state = S_NVM;
                            end else if (vm_hierarchy_bad == 1'b1) begin
                                next_state = EXECUTION_ERROR;
                                response_code = TPM_RC_HIERARCHY;
                            end else begin
                                next_state = S_VM;
                            end
                        end else if (vm_object_invalid == 1'b1 || vm_attributes_bad == 1'b1) begin
                            next_state = EXECUTION_ERROR;
                            response_code = TPM_RC_ATTRIBUTES;
                        end else begin
                            next_state = S_VM;
                        end
                    end
                    
                    TPM_CC_HierarchyControl: begin
                        vm_hierarchy_read = 1'b1;
                        if (vm_validation_ok == 1'b1) begin
                            next_state = S_POWER_DETECTION;
                        end else if (vm_validation_fail == 1'b1) begin
                            next_state = EXECUTION_ERROR;
                            response_code = TPM_RC_AUTH_TYPE;
                        end else begin
                            next_state = S_VM;
                        end
                    end
                    
                    TPM_CC_NV_UndefineSpace: begin
                        vm_session_cleanup = 1'b1;
                        if (vm_cleanup_complete == 1'b1) begin
                            next_state = EXECUTION_DONE;
                        end else if (vm_cleanup_fail == 1'b1) begin
                            next_state = EXECUTION_ERROR;
                        end else begin
                            next_state = S_VM;
                        end
                    end
                    
                    TPM_CC_ChangeEPS: begin
                        vm_hierarchy_update = 1'b1;
                        vm_eh_enable = 1'b1;
                        vm_clear_endorsement_auth = 1'b1;
                        vm_clear_endorsement_policy = 1'b1;
                        if (vm_update_complete == 1'b1) begin
                            vm_flush_hierarchy = 1'b1;
                            if (vm_flush_complete == 1'b1) begin
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
                asym_engine_enable = 1'b1;
                if (asym_engine_complete == 1'b1) begin
                    next_state = EXECUTION_DONE;
                end else if (asym_engine_fail == 1'b1) begin
                    next_state = EXECUTION_ERROR;
                end else begin
                    next_state = S_ASYM_ENGINE;
                end
            end
            
            
            // S_HASH_ENGINE
            
            S_HASH_ENGINE: begin
                hash_engine_enable = 1'b1;
                if (hash_engine_complete == 1'b1) begin
                    next_state = EXECUTION_DONE;
                end else if (hash_engine_fail == 1'b1) begin
                    next_state = EXECUTION_ERROR;
                end else begin
                    next_state = S_HASH_ENGINE;
                end
            end
            
            
            // S_SYM_ENGINE
            
            S_SYM_ENGINE: begin
                sym_engine_enable = 1'b1;
                if (sym_engine_complete == 1'b1) begin
                    next_state = EXECUTION_DONE;
                end else if (sym_engine_fail == 1'b1) begin
                    next_state = EXECUTION_ERROR;
                end else begin
                    next_state = S_SYM_ENGINE;
                end
            end
            
            
            // S_KEYGEN
            
            S_KEYGEN: begin
                keygen_enable = 1'b1;
                if (keygen_complete == 1'b1) begin
                    next_state = EXECUTION_DONE;
                end else if (keygen_fail == 1'b1) begin
                    next_state = EXECUTION_ERROR;
                end else begin
                    next_state = S_KEYGEN;
                end
            end
            
            
            // S_RNG
            
            S_RNG: begin
                rng_generate_enable = 1'b1;
                if (command_code == TPM_CC_ChangeEPS) begin
                    rng_data_size = 16'd32; // Example: 32 bytes for EPS seed
                    if (rng_generate_complete == 1'b1) begin
                        next_state = S_VM;
                    end else if (rng_generate_fail == 1'b1) begin
                        next_state = EXECUTION_ERROR;
                    end else begin
                        next_state = S_RNG;
                    end
                end else begin
                    if (rng_generate_complete == 1'b1) begin
                        next_state = EXECUTION_DONE;
                    end else if (rng_generate_fail == 1'b1) begin
                        next_state = EXECUTION_ERROR;
                    end else begin
                        next_state = S_RNG;
                    end
                end
            end
            
            
            
            // EXECUTION_DONE 
            
            EXECUTION_DONE: begin
                execution_complete_signal = 1'b1;
                response_code = TPM_RC_SUCCESS;
					 
					 if (command_code == TPM_CC_Startup) begin
                    execution_startup_done = 1'b1;
                end
					 
                if (control_ack == 1'b1) begin
                    next_state = EXECUTION_IDLE;
                end else begin
                    next_state = EXECUTION_DONE;
                end
            end
            
            
            // EXECUTION_ERROR
            
            EXECUTION_ERROR: begin
                execution_error_signal = 1'b1;
                // response_code set by the state that caused the error
					 
			       if (command_code == TPM_CC_Startup) begin
                    execution_startup_done = 1'b1;
                end
					 
                if (control_ack == 1'b1) begin
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