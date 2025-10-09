////////////////////////////////////////////////////////////////////////////////////////
// Filename:      input_output_signal_structure.v
// Author:        Michael
// Version:       1.0
// Description:  General structure for control signals. 13 separate modules.
//	Each module has a combinational always block for setting outputs.
// Each module has a sequential always block for state transistions.
//
//
///////////////////////////////////////



// Block 1: Execution_idle
// waiting for a command.
module execution_idle_fsm (
    input  wire clk,
    input  wire rst,
    input  wire start_signal,
    output reg  command_received
);
    reg [0:0] current_state, next_state;
    localparam IDLE = 1'b0, BUSY = 1'b1;

    //sequential for state transitions
    always @(posedge clk or posedge rst) begin
        if (rst) current_state <= IDLE;
        else     current_state <= next_state;
    end

    // combinational for outputs
    always @(*) begin
        command_received = 1'b0;
        next_state = current_state;

        case(current_state)
            IDLE: if (start_signal) begin
                command_received = 1'b1;
                next_state = BUSY; // Or goes back to idle after one cycle
            end
            BUSY: begin
           
                next_state = IDLE;
            end
        endcase
    end
endmodule


// Block 2: Execution Start

module execution_start_fsm (
    input  wire clk,
    input  wire rst,
    input  wire start_processing,
    input  wire params_loaded,
    output reg  fetch_command_params,
    output reg  start_processing_complete
);
    reg [0:0] current_state, next_state;
    localparam IDLE = 1'b0, FETCHING = 1'b1;

    always @(posedge clk or posedge rst) begin
        if (rst) current_state <= IDLE;
        else     current_state <= next_state;
    end

    always @(*) begin
        fetch_command_params = 1'b0;
        start_processing_complete = 1'b0;
        next_state = current_state;

        case(current_state)
            IDLE: if (start_processing) begin
                fetch_command_params = 1'b1;
                next_state = FETCHING;
            end
            FETCHING: if (params_loaded) begin
                start_processing_complete = 1'b1;
                next_state = IDLE;
            end
        endcase
    end
endmodule


// Block 3: Execution Done
module execution_done_fsm (
    input  wire clk,
    input  wire rst,
    input  wire command_succeeded,
    input  wire control_ack,
    output reg execution_complete_signal
);
    reg [0:0] current_state, next_state;
    localparam IDLE = 1'b0, SIGNALING = 1'b1;

    always @(posedge clk or posedge rst) begin
        if (rst) current_state <= IDLE;
        else     current_state <= next_state;
    end

    always @(*) begin
        execution_complete_signal = 1'b0;
        next_state = current_state;

        case(current_state)
            IDLE: if (command_succeeded) begin
                next_state = SIGNALING;
            end
            SIGNALING: begin
                execution_complete_signal = 1'b1;
                if (control_ack) next_state = IDLE;
            end
        endcase
    end
endmodule


// Block 4: Execution Error
module execution_error_fsm (
    input  wire clk,
    input  wire rst,
    input  wire command_failed,
    input  wire control_ack,
    output reg execution_error_signal
);
    reg [0:0] current_state, next_state;
    localparam IDLE = 1'b0, SIGNALING = 1'b1;

    always @(posedge clk or posedge rst) begin
        if (rst) current_state <= IDLE;
        else     current_state <= next_state;
    end

    always @(*) begin
        execution_error_signal = 1'b0;
        next_state = current_state;

        case(current_state)
            IDLE: if (command_failed) begin
                next_state = SIGNALING;
            end
            SIGNALING: begin
                execution_error_signal = 1'b1;
                if (control_ack) next_state = IDLE;
            end
        endcase
    end
endmodule


// Block 5: Authorization
module authorization_fsm (
    input  wire clk,
    input  wire rst,
    input  wire start_auth_check,
    input  wire auth_check_passed,
    input  wire auth_check_failed,
    output reg  auth_session_validate,
    output reg  auth_success,
    output reg  auth_fail
);
    reg [0:0] current_state, next_state;
    localparam IDLE = 1'b0, CHECKING = 1'b1;

    always @(posedge clk or posedge rst) begin
        if (rst) current_state <= IDLE;
        else     current_state <= next_state;
    end

    always @(*) begin
        auth_session_validate = 1'b0;
        auth_success = 1'b0;
        auth_fail = 1'b0;
        next_state = current_state;

        case(current_state)
            IDLE: if (start_auth_check) begin
                auth_session_validate = 1'b1;
                next_state = CHECKING;
            end
            CHECKING: begin
                if (auth_check_passed) begin
                    auth_success = 1'b1;
                    next_state = IDLE;
                end else if (auth_check_failed) begin
                    auth_fail = 1'b1;
                    next_state = IDLE;
                end
            end
        endcase
    end
endmodule


// Block 6: NVM
module nonvolatile_fsm (
    input  wire clk,
    input  wire rst,
    input  wire start_nvm_op,
    input  wire nvm_op_complete,
    input  wire nvm_op_failed,
    output reg  nvm_read_enable,
    output reg  nvm_delete_enable,
    output reg  nvm_sync_persistent,
    output reg  nvm_success,
    output reg  nvm_fail
);
    reg [0:0] current_state, next_state;
    localparam IDLE = 1'b0, BUSY = 1'b1;

    always @(posedge clk or posedge rst) begin
        if (rst) current_state <= IDLE;
        else     current_state <= next_state;
    end

    always @(*) begin
        nvm_read_enable = 1'b0;
        nvm_delete_enable = 1'b0;
        nvm_sync_persistent = 1'b0;
        nvm_success = 1'b0;
        nvm_fail = 1'b0;
        next_state = current_state;

        case(current_state)
            IDLE: if (start_nvm_op) begin
                // Specific signals would be asserted based on command
                nvm_read_enable = 1'b1; // Example
                next_state = BUSY;
            end
            BUSY: begin
                if (nvm_op_complete) begin
                    nvm_success = 1'b1;
                    next_state = IDLE;
                end else if (nvm_op_failed) begin
                    nvm_fail = 1'b1;
                    next_state = IDLE;
                end
            end
        endcase
    end
endmodule


// Block 7: VM
module volatile_fsm (
    input  wire clk,
    input  wire rst,
    input  wire start_vm_op,
    input  wire vm_op_complete,
    input  wire vm_op_failed,
    output reg  vm_session_cleanup,
    output reg  vm_flush_hierarchy,
    output reg  vm_update_hierarchy,
    output reg  vm_success,
    output reg  vm_fail
);
    reg [0:0] current_state, next_state;
    localparam IDLE = 1'b0, BUSY = 1'b1;

    always @(posedge clk or posedge rst) begin
        if (rst) current_state <= IDLE;
        else     current_state <= next_state;
    end

    always @(*) begin
        vm_session_cleanup = 1'b0;
        vm_flush_hierarchy = 1'b0;
        vm_update_hierarchy = 1'b0;
        vm_success = 1'b0;
        vm_fail = 1'b0;
        next_state = current_state;

        case(current_state)
            IDLE: if (start_vm_op) begin
                // Specific signals would be asserted based on command
                vm_session_cleanup = 1'b1; // Example
                next_state = BUSY;
            end
            BUSY: begin
                if (vm_op_complete) begin
                    vm_success = 1'b1;
                    next_state = IDLE;
                end else if (vm_op_failed) begin
                    vm_fail = 1'b1;
                    next_state = IDLE;
                end
            end
        endcase
    end
endmodule


// Block 8: RNG
module rng_fsm (
    input  wire clk,
    input  wire rst,
    input  wire start_rng,
    input  wire rng_data_ready,
    output reg  rng_generate_enable,
    output reg  rng_complete
);
    reg [0:0] current_state, next_state;
    localparam IDLE = 1'b0, GENERATING = 1'b1;

    always @(posedge clk or posedge rst) begin
        if (rst) current_state <= IDLE;
        else     current_state <= next_state;
    end

    always @(*) begin
        rng_generate_enable = 1'b0;
        rng_complete = 1'b0;
        next_state = current_state;

        case(current_state)
            IDLE: if (start_rng) begin
                rng_generate_enable = 1'b1;
                next_state = GENERATING;
            end
            GENERATING: if (rng_data_ready) begin
                rng_complete = 1'b1;
                next_state = IDLE;
            end
        endcase
    end
endmodule


// Block 9: Asymmetric Cryptography
module asymmetric_fsm (
    input  wire clk,
    input  wire rst,
    input  wire start_asym_op,
    input  wire asym_op_done,
    output reg  asym_op_enable,
    output reg  asym_op_complete
);
    reg [0:0] current_state, next_state;
    localparam IDLE = 1'b0, BUSY = 1'b1;

    always @(posedge clk or posedge rst) begin
        if (rst) current_state <= IDLE;
        else     current_state <= next_state;
    end

    always @(*) begin
        asym_op_enable = 1'b0;
        asym_op_complete = 1'b0;
        next_state = current_state;

        case(current_state)
            IDLE: if (start_asym_op) begin
                asym_op_enable = 1'b1;
                next_state = BUSY;
            end
            BUSY: if (asym_op_done) begin
                asym_op_complete = 1'b1;
                next_state = IDLE;
            end
        endcase
    end
endmodule


// Block 10: Symmetric Cryptography
module symmetric_fsm (
    input  wire clk,
    input  wire rst,
    input  wire start_sym_op,
    input  wire sym_op_done,
    output reg  sym_op_enable,
    output reg  sym_op_complete
);
    reg [0:0] current_state, next_state;
    localparam IDLE = 1'b0, BUSY = 1'b1;

    always @(posedge clk or posedge rst) begin
        if (rst) current_state <= IDLE;
        else     current_state <= next_state;
    end

    always @(*) begin
        sym_op_enable = 1'b0;
        sym_op_complete = 1'b0;
        next_state = current_state;

        case(current_state)
            IDLE: if (start_sym_op) begin
                sym_op_enable = 1'b1;
                next_state = BUSY;
            end
            BUSY: if (sym_op_done) begin
                sym_op_complete = 1'b1;
                next_state = IDLE;
            end
        endcase
    end
endmodule


// Block 11: Hash
// basic for hashing
module hash_fsm (
    input  wire clk,
    input  wire rst,
    input  wire start_hash_op,
    input  wire hash_op_done,
    output reg  hash_op_enable,
    output reg  hash_op_complete
);
    reg [0:0] current_state, next_state;
    localparam IDLE = 1'b0, BUSY = 1'b1;

    always @(posedge clk or posedge rst) begin
        if (rst) current_state <= IDLE;
        else     current_state <= next_state;
    end

    always @(*) begin
        hash_op_enable = 1'b0;
        hash_op_complete = 1'b0;
        next_state = current_state;

        case(current_state)
            IDLE: if (start_hash_op) begin
                hash_op_enable = 1'b1;
                next_state = BUSY;
            end
            BUSY: if (hash_op_done) begin
                hash_op_complete = 1'b1;
                next_state = IDLE;
            end
        endcase
    end
endmodule


// Block 12: Key Generation
// barebones for crypto
module key_generation_fsm (
    input  wire clk,
    input  wire rst,
    input  wire start_keygen_op,
    input  wire keygen_op_done,
    output reg  keygen_op_enable,
    output reg  keygen_op_complete
);
    reg [0:0] current_state, next_state;
    localparam IDLE = 1'b0, BUSY = 1'b1;

    always @(posedge clk or posedge rst) begin
        if (rst) current_state <= IDLE;
        else     current_state <= next_state;
    end

    always @(*) begin
        keygen_op_enable = 1'b0;
        keygen_op_complete = 1'b0;
        next_state = current_state;

        case(current_state)
            IDLE: if (start_keygen_op) begin
                keygen_op_enable = 1'b1;
                next_state = BUSY;
            end
            BUSY: if (keygen_op_done) begin
                keygen_op_complete = 1'b1;
                next_state = IDLE;
            end
        endcase
    end
endmodule
