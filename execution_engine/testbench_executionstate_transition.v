///////////////////////////////////////////
//
// Filename:      tb_execution_engine_fsm.v
// Description:   Testbench for the execution_engine_fsm module.
//
//                This testbench is designed to verify the state transitions of the FSM
//                by providing different groups of stimulus inputs. 
/////////////////////////////////////////////////

`timescale 1ns/1ps

module tb_execution_engine_fsm();

    // Clock generator signals
    reg  clk_enable;
    wire clk_out;

    reg         rst_n;
    reg         command_start;
    reg [31:0]  command_code;
    reg         control_ack;
    
    // Authorization Module Signals
    reg         auth_success;
    reg         auth_fail;
    reg         policy_valid;
    reg         policy_invalid;
    
    // Non-Volatile Memory (NVM) Module Signals
    reg         nvm_index_valid;
    reg         nvm_index_invalid;
    reg         nvm_attributes_ok;
    reg         nvm_attributes_bad;
    reg         nvm_auth_match;
    reg         nvm_auth_mismatch;
    reg         nvm_delete_complete;
    reg         nvm_delete_fail;
    reg         nvm_success;
    reg         nvm_range_valid;
    reg         nvm_range_invalid;
    reg         nvm_operation_complete;
    reg         nvm_operation_fail;
    reg         nvm_disable_required;
    reg         nvm_disable_not_required;
    reg         nvm_disable_complete;
    reg         nvm_disable_fail;
    reg         nvm_flush_complete;
    reg         nvm_sync_complete;
    
    // Volatile Memory (VM) Module Signals
    reg         vm_object_valid;
    reg         vm_object_invalid;
    reg         vm_attributes_ok;
    reg         vm_attributes_bad;
    reg         vm_hierarchy_ok;
    reg         vm_hierarchy_bad;
    reg         vm_validation_ok;
    reg         vm_validation_fail;
    reg         vm_flush_complete;
    reg         vm_flush_fail;
    reg         vm_cleanup_complete;
    reg         vm_cleanup_fail;
    reg         vm_update_complete;
    reg         vm_update_fail;
    reg         flush_required;
    reg         flush_not_required;
    
    // Asymmetric Engine Signals
    reg         asym_engine_complete;
    reg         asym_engine_fail;
    
    // Hash Engine Signals
    reg         hash_engine_complete;
    reg         hash_engine_fail;
    
    // Symmetric Engine Signals
    reg         sym_engine_complete;
    reg         sym_engine_fail;
    
    // Key Generation Signals
    reg         keygen_complete;
    reg         keygen_fail;
    
    // RNG Signals
    reg         rng_generate_complete;
    reg         rng_generate_fail;
    
    // Power Detection Signals
    reg         power_orderly_ok;
    reg         power_orderly_fail;
    reg         power_nv_available;
    reg         power_nv_unavailable;
    
    // Clock Tick Module Signals
    reg         clock_tick_complete;

    // DUT Outputs (monitored by tb)
    wire        execution_complete_signal;
    wire        execution_error_signal;
    
    wire        auth_session_validate;
    wire [3:0]  auth_handle_count;
    
    wire        nvm_read_enable;
    wire        nvm_delete_enable;
    wire        nvm_policy_delete;
    wire        nvm_range_check;
    wire        nvm_operation_type;
    wire        nvm_disable_access;
    wire        nvm_flush_hierarchy;
    wire        nvm_sync_persistent;
    
    wire        vm_object_read_enable;
    wire        vm_hierarchy_check;
    wire        vm_hierarchy_read;
    wire        vm_flush_hierarchy;
    wire        vm_session_cleanup;
    wire        vm_update_hierarchy;
    wire        vm_flush_decision;
    wire        vm_hierarchy_update;
    wire        vm_eh_enable;
    wire        vm_clear_endorsement_auth;
    wire        vm_clear_endorsement_policy;
    
    wire        asym_engine_enable;
    wire        hash_engine_enable;
    wire        sym_engine_enable;
    wire        keygen_enable;
    
    wire        rng_generate_enable;
    wire [15:0] rng_data_size;
    
    wire        power_orderly_check;
    wire        power_nv_check;
    
    wire        clock_tick_enable;
    
    wire [31:0] response_code;
    
    // TPM Command Codes
    localparam [31:0] TPM_CC_NV_UndefineSpaceSpecial = 32'h0000011F,
                      TPM_CC_EvictControl            = 32'h00000120,
                      TPM_CC_HierarchyControl        = 32'h00000121,
                      TPM_CC_NV_UndefineSpace        = 32'h00000122,
                      TPM_CC_ChangeEPS               = 32'h00000124;

    // clock
     clk CLK1(clk_enable, clk_out);

    // Instantiate
    execution_engine_fsm DUT (
        .clock(clk_out),
        .rst_n(rst_n),
        
        // Control FSM Interface
        .command_start(command_start),
        .command_code(command_code),
        .execution_complete_signal(execution_complete_signal),
        .execution_error_signal(execution_error_signal),
        .control_ack(control_ack),
        
        // Authorization Module Signals
        .auth_session_validate(auth_session_validate),
        .auth_handle_count(auth_handle_count),
        .auth_success(auth_success),
        .auth_fail(auth_fail),
        .policy_valid(policy_valid),
        .policy_invalid(policy_invalid),
        
        // Non-Volatile Memory (NVM) Module Signals
        .nvm_read_enable(nvm_read_enable),
        .nvm_delete_enable(nvm_delete_enable),
        .nvm_policy_delete(nvm_policy_delete),
        .nvm_range_check(nvm_range_check),
        .nvm_operation_type(nvm_operation_type),
        .nvm_disable_access(nvm_disable_access),
        .nvm_flush_hierarchy(nvm_flush_hierarchy),
        .nvm_sync_persistent(nvm_sync_persistent),
        .nvm_index_valid(nvm_index_valid),
        .nvm_index_invalid(nvm_index_invalid),
        .nvm_attributes_ok(nvm_attributes_ok),
        .nvm_attributes_bad(nvm_attributes_bad),
        .nvm_auth_match(nvm_auth_match),
        .nvm_auth_mismatch(nvm_auth_mismatch),
        .nvm_delete_complete(nvm_delete_complete),
        .nvm_delete_fail(nvm_delete_fail),
        .nvm_success(nvm_success),
        .nvm_range_valid(nvm_range_valid),
        .nvm_range_invalid(nvm_range_invalid),
        .nvm_operation_complete(nvm_operation_complete),
        .nvm_operation_fail(nvm_operation_fail),
        .nvm_disable_required(nvm_disable_required),
        .nvm_disable_not_required(nvm_disable_not_required),
        .nvm_disable_complete(nvm_disable_complete),
        .nvm_disable_fail(nvm_disable_fail),
        .nvm_flush_complete(nvm_flush_complete),
        .nvm_sync_complete(nvm_sync_complete),
        
        // Volatile Memory (VM) Module Signals
        .vm_object_read_enable(vm_object_read_enable),
        .vm_hierarchy_check(vm_hierarchy_check),
        .vm_hierarchy_read(vm_hierarchy_read),
        .vm_flush_hierarchy(vm_flush_hierarchy),
        .vm_session_cleanup(vm_session_cleanup),
        .vm_update_hierarchy(vm_update_hierarchy),
        .vm_flush_decision(vm_flush_decision),
        .vm_hierarchy_update(vm_hierarchy_update),
        .vm_eh_enable(vm_eh_enable),
        .vm_clear_endorsement_auth(vm_clear_endorsement_auth),
        .vm_clear_endorsement_policy(vm_clear_endorsement_policy),
        .vm_object_valid(vm_object_valid),
        .vm_object_invalid(vm_object_invalid),
        .vm_attributes_ok(vm_attributes_ok),
        .vm_attributes_bad(vm_attributes_bad),
        .vm_hierarchy_ok(vm_hierarchy_ok),
        .vm_hierarchy_bad(vm_hierarchy_bad),
        .vm_validation_ok(vm_validation_ok),
        .vm_validation_fail(vm_validation_fail),
        .vm_flush_complete(vm_flush_complete),
        .vm_flush_fail(vm_flush_fail),
        .vm_cleanup_complete(vm_cleanup_complete),
        .vm_cleanup_fail(vm_cleanup_fail),
        .vm_update_complete(vm_update_complete),
        .vm_update_fail(vm_update_fail),
        .flush_required(flush_required),
        .flush_not_required(flush_not_required),
        
        // Asymmetric Engine Signals
        .asym_engine_enable(asym_engine_enable),
        .asym_engine_complete(asym_engine_complete),
        .asym_engine_fail(asym_engine_fail),
        
        // Hash Engine Signals
        .hash_engine_enable(hash_engine_enable),
        .hash_engine_complete(hash_engine_complete),
        .hash_engine_fail(hash_engine_fail),
        
        // Symmetric Engine Signals
        .sym_engine_enable(sym_engine_enable),
        .sym_engine_complete(sym_engine_complete),
        .sym_engine_fail(sym_engine_fail),
        
        // Key Generation Signals
        .keygen_enable(keygen_enable),
        .keygen_complete(keygen_complete),
        .keygen_fail(keygen_fail),
        
        // RNG Signals
        .rng_generate_enable(rng_generate_enable),
        .rng_data_size(rng_data_size),
        .rng_generate_complete(rng_generate_complete),
        .rng_generate_fail(rng_generate_fail),
        
        // Power Detection Signals
        .power_orderly_check(power_orderly_check),
        .power_nv_check(power_nv_check),
        .power_orderly_ok(power_orderly_ok),
        .power_orderly_fail(power_orderly_fail),
        .power_nv_available(power_nv_available),
        .power_nv_unavailable(power_nv_unavailable),
        
        // Clock Tick Module Signals
        .clock_tick_enable(clock_tick_enable),
        .clock_tick_complete(clock_tick_complete),
        
        // General Control Signals
        .response_code(response_code)
    );

    // initialize
    task initialize_inputs;
    begin
        command_start = 1'b0;
        command_code = 32'd0;
        control_ack = 1'b0;
        
        auth_success = 1'b0;
        auth_fail = 1'b0;
        policy_valid = 1'b0;
        policy_invalid = 1'b0;
        
        nvm_index_valid = 1'b0;
        nvm_index_invalid = 1'b0;
        nvm_attributes_ok = 1'b0;
        nvm_attributes_bad = 1'b0;
        nvm_auth_match = 1'b0;
        nvm_auth_mismatch = 1'b0;
        nvm_delete_complete = 1'b0;
        nvm_delete_fail = 1'b0;
        nvm_success = 1'b0;
        nvm_range_valid = 1'b0;
        nvm_range_invalid = 1'b0;
        nvm_operation_complete = 1'b0;
        nvm_operation_fail = 1'b0;
        nvm_disable_required = 1'b0;
        nvm_disable_not_required = 1'b0;
        nvm_disable_complete = 1'b0;
        nvm_disable_fail = 1'b0;
        nvm_flush_complete = 1'b0;
        nvm_sync_complete = 1'b0;
        
        vm_object_valid = 1'b0;
        vm_object_invalid = 1'b0;
        vm_attributes_ok = 1'b0;
        vm_attributes_bad = 1'b0;
        vm_hierarchy_ok = 1'b0;
        vm_hierarchy_bad = 1'b0;
        vm_validation_ok = 1'b0;
        vm_validation_fail = 1'b0;
        vm_flush_complete = 1'b0;
        vm_flush_fail = 1'b0;
        vm_cleanup_complete = 1'b0;
        vm_cleanup_fail = 1'b0;
        vm_update_complete = 1'b0;
        vm_update_fail = 1'b0;
        flush_required = 1'b0;
        flush_not_required = 1'b0;
        
        asym_engine_complete = 1'b0;
        asym_engine_fail = 1'b0;
        hash_engine_complete = 1'b0;
        hash_engine_fail = 1'b0;
        sym_engine_complete = 1'b0;
        sym_engine_fail = 1'b0;
        keygen_complete = 1'b0;
        keygen_fail = 1'b0;
        rng_generate_complete = 1'b0;
        rng_generate_fail = 1'b0;
        power_orderly_ok = 1'b0;
        power_orderly_fail = 1'b0;
        power_nv_available = 1'b0;
        power_nv_unavailable = 1'b0;
        clock_tick_complete = 1'b0;
    end
    endtask


    // Stimulus logic
    initial begin
        // 1. Enable clock
        clk_enable = 1'b1;
        #20;

        // 2. Initialize all inputs to 0
        initialize_inputs();
        
        // 3. Apply reset
        rst_n = 1'b0;
        #40;
        rst_n = 1'b1;
        #20;
        // DUT is now in EXECUTION_IDLE

        
        
        // TEST GROUP 1: TPM_CC_NV_UndefineSpace (Success)
        // This test verifies the successful path:
        // IDLE -> START -> S_AUTHORIZATION -> S_NVM -> S_VM -> EXECUTION_DONE -> IDLE
        
        
       
        // Set up inputs for S_AUTHORIZATION and subsequent states
        command_code = TPM_CC_NV_UndefineSpace;
        auth_success = 1'b1;        // For S_AUTHORIZATION -> S_NVM
        
        nvm_index_valid = 1'b1;     // For S_NVM -> S_VM
        nvm_attributes_ok = 1'b1;
        nvm_auth_match = 1'b1;
        nvm_delete_complete = 1'b1; // (will be pulsed later)
        nvm_success = 1'b1;
        
        vm_cleanup_complete = 1'b1; // For S_VM -> EXECUTION_DONE (will be pulsed later)

        // 1. Trigger command
        #20;
        command_start = 1'b1;
        #100; // Wait for FSM to move from IDLE -> START -> S_AUTHORIZATION
        command_start = 1'b0;
        
        // FSM is in S_AUTHORIZATION move to S_NVM
        
        // 2. Pulse nvm_delete_complete
        #100; // Wait for FSM to reach S_NVM
        nvm_delete_complete = 1'b1;
        #100;
        nvm_delete_complete = 1'b0;
        
        // FSM sees nvm_delete_complete, moves to S_VM
        // In S_VM, it waits for vm_cleanup_complete
        
        // 3. Pulse vm_cleanup_complete
        #100; // Wait for FSM to reach S_VM
        vm_cleanup_complete = 1'b1;
        #100;
        vm_cleanup_complete = 1'b0;

		  
        // FSM sees vm_cleanup_complete, moves to EXECUTION_DONE
        
        // 4. Acknowledge completion
        #100; // Wait for FSM to reach EXECUTION_DONE
        control_ack = 1'b1;
        #100;
        control_ack = 1'b0;
        
        // FSM sees control_ack, moves to EXECUTION_IDLE
        #200;
        initialize_inputs(); // Clean up for next test
        
        // End of Test Group 1

        /*
        
        // TEST GROUP 2: TPM_CC_NV_UndefineSpace (Auth Fail)
        // This test verifies the failure path:
        // IDLE -> START -> S_AUTHORIZATION -> EXECUTION_ERROR -> IDLE
        
              
        // Set up inputs for S_AUTHORIZATION failure
        command_code = TPM_CC_NV_UndefineSpace;
        auth_fail = 1'b1;           // Pre-set for S_AUTHORIZATION
        
        // 1. Trigger command
        #20;
        command_start = 1'b1;
        #100; // Wait for FSM to move from IDLE -> START -> S_AUTHORIZATION
        command_start = 1'b0;
        
        // FSM is in S_AUTHORIZATION, sees auth_fail, moves to EXECUTION_ERROR
        
        // 2. Acknowledge error
        #100; // Wait for FSM to reach EXECUTION_ERROR
        control_ack = 1'b1;
        #100;
        control_ack = 1'b0;
        
        // FSM sees control_ack, moves to EXECUTION_IDLE
        #200;
        initialize_inputs(); // Clean up for next test

        // End of Test Group 2
        */


        /*
        
        // TEST GROUP 3: TPM_CC_NV_UndefineSpace (NVM Fail)
        // This test verifies the failure path:
        // IDLE -> START -> S_AUTHORIZATION -> S_NVM -> EXECUTION_ERROR -> IDLE
        
        
        
        // Set up inputs
        command_code = TPM_CC_NV_UndefineSpace;
        auth_success = 1'b1;        // For S_AUTHORIZATION -> S_NVM
        
        nvm_index_invalid = 1'b1;   // For S_NVM -> EXECUTION_ERROR
        
        // 1. Trigger command
        #20;
        command_start = 1'b1;
        #100; // Wait for FSM to move from IDLE -> START -> S_AUTHORIZATION
        command_start = 1'b0;
        
        // FSM is in S_AUTHORIZATION, sees auth_success, moves to S_NVM
        // In S_NVM, it sees nvm_index_invalid, moves to EXECUTION_ERROR
        
        // 2. Acknowledge error
        #100; // Wait for FSM to reach EXECUTION_ERROR
        control_ack = 1'b1;
        #100;
        control_ack = 1'b0;
        
        // FSM sees control_ack, moves to EXECUTION_IDLE
        #200;
        initialize_inputs(); // Clean up for next test

        // End of Test Group 3
        */


        /*
        
        // TEST GROUP 4: TPM_CC_EvictControl (Success)
        // This test verifies the successful path:
        // IDLE -> START -> S_AUTHORIZATION -> S_VM -> S_NVM -> EXECUTION_DONE -> IDLE
        
        
        
        // Set up inputs
        command_code = TPM_CC_EvictControl;
        auth_success = 1'b1;        // For S_AUTHORIZATION -> S_VM
        
        vm_object_valid = 1'b1;     // For S_VM -> S_NVM
        vm_attributes_ok = 1'b1;
        vm_hierarchy_ok = 1'b1;
        
        nvm_range_valid = 1'b1;     // For S_NVM -> EXECUTION_DONE
        nvm_operation_complete = 1'b1; // (will be pulsed later)
        nvm_success = 1'b1;
        
        // 1. Trigger command
        #20;
        command_start = 1'b1;
        #100; // Wait for FSM to move from IDLE -> START -> S_AUTHORIZATION
        command_start = 1'b0;
        
        // FSM is in S_AUTHORIZATION, sees auth_success, moves to S_VM
        // In S_VM, it sees object/attr/hierarchy ok, moves to S_NVM

        // 2. Pulse nvm_operation_complete
        #100; // Wait for FSM to reach S_NVM
        nvm_operation_complete = 1'b1;
        #100;
        nvm_operation_complete = 1'b0;
        
        // FSM sees nvm_operation_complete, moves to EXECUTION_DONE
        
        // 3. Acknowledge completion
        #100; // Wait for FSM to reach EXECUTION_DONE
        control_ack = 1'b1;
        #100;
        control_ack = 1'b0;
        
        // FSM sees control_ack, moves to EXECUTION_IDLE
        #200;
        initialize_inputs(); // Clean up for next test

        // End of Test Group 4
        */

        
        /*
        
        // TEST GROUP 5: TPM_CC_EvictControl (VM Fail)
        // This test verifies the failure path:
        // IDLE -> START -> S_AUTHORIZATION -> S_VM -> EXECUTION_ERROR -> IDLE
        
        
        
        // Set up inputs
        command_code = TPM_CC_EvictControl;
        auth_success = 1'b1;        // For S_AUTHORIZATION -> S_VM
        
        vm_object_invalid = 1'b1;   // For S_VM -> EXECUTION_ERROR
        
        // 1. Trigger command
        #20;
        command_start = 1'b1;
        #100; // Wait for FSM to move from IDLE -> START -> S_AUTHORIZATION
        command_start = 1'b0;
        
        // FSM is in S_AUTHORIZATION, sees auth_success, moves to S_VM
        // In S_VM, it sees vm_object_invalid, moves to EXECUTION_ERROR
        
        // 2. Acknowledge error
        #100; // Wait for FSM to reach EXECUTION_ERROR
        control_ack = 1'b1;
        #100;
        control_ack = 1'b0;
        
        // FSM sees control_ack, moves to EXECUTION_IDLE
        #200;
        initialize_inputs(); // Clean up for next test

        // End of Test 5
        */


        // End simulation
        #1000;
    end

endmodule // tb_execution_engine_fsm


