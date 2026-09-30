// random_number_generation.v
//
// Random number generation submodule.
//
// This module receives a 256-bit input from a future Hash.v module, stores it
// in a 256-bit DRBG data state register, and uses a small FSM to control the
// placeholder Hash_DRBG processing flow. Hash.v and the real Hash_DRBG
// algorithm are intentionally not implemented yet.

module random_number_generation (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        enable,
    input  wire [255:0] hash_input,
    output reg  [255:0] random_output,
    output reg         random_valid
);

    localparam [1:0] FSM_IDLE   = 2'd0;
    localparam [1:0] FSM_LOAD   = 2'd1;
    localparam [1:0] FSM_DRBG   = 2'd2;
    localparam [1:0] FSM_OUTPUT = 2'd3;

    reg [1:0] current_state;
    reg [1:0] next_state;

    reg [255:0] state_register;
    reg [255:0] next_state_register;
    reg [255:0] drbg_result;

    function [255:0] Hash_DRBG;
        input [255:0] state_data;
        begin
            // Placeholder only. Replace with the real Hash_DRBG algorithm.
            Hash_DRBG = state_data;
        end
    endfunction

    always @(*) begin
        next_state = current_state;

        case (current_state)
            FSM_IDLE: begin
                if (enable) begin
                    next_state = FSM_LOAD;
                end
            end

            FSM_LOAD: begin
                next_state = FSM_DRBG;
            end

            FSM_DRBG: begin
                next_state = FSM_OUTPUT;
            end

            FSM_OUTPUT: begin
                next_state = FSM_IDLE;
            end

            default: begin
                next_state = FSM_IDLE;
            end
        endcase
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state      <= FSM_IDLE;
            state_register     <= 256'b0;
            next_state_register <= 256'b0;
            drbg_result        <= 256'b0;
            random_output      <= 256'b0;
            random_valid       <= 1'b0;
        end else begin
            current_state <= next_state;
            random_valid  <= 1'b0;

            case (current_state)
                FSM_IDLE: begin
                    if (enable) begin
                        next_state_register <= hash_input;
                    end
                end

                FSM_LOAD: begin
                    state_register <= next_state_register;
                end

                FSM_DRBG: begin
                    drbg_result <= Hash_DRBG(state_register);
                end

                FSM_OUTPUT: begin
                    random_output <= drbg_result;
                    random_valid  <= 1'b1;
                end

                default: begin
                    random_valid <= 1'b0;
                end
            endcase
        end
    end

endmodule
   