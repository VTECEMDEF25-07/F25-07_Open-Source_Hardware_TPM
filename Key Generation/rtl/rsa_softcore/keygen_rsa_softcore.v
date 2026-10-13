// One RSA firmware job at a time; completion follows local CPU/RAM cleanup.
// Accelerator P/Q/N remain owned by the outer protected-result controller.
module keygen_rsa_softcore #(
    parameter ROM_FILE="rsa_control.hex", parameter WATCHDOG_BITS=20,
    parameter COMMAND_TIMEOUT_CYCLES=50000000, parameter BLOCKING_STATUS=1
)(
    input wire clock_i, input wire reset_n_i,
    input wire work_valid_i, output wire work_ready_o,
    output wire completion_valid_o, input wire completion_ready_i,
    output wire [7:0] completion_status_o,
    output wire command_valid_o, input wire command_ready_i,
    output wire [7:0] command_opcode_o,
    output wire [31:0] command_arg0_o,command_arg1_o,command_arg2_o,command_arg3_o,
    input wire response_valid_i, output wire response_ready_o,
    input wire [7:0] response_status_i
);
    localparam INIT=0, IDLE=1, RUN=2, CLEAR=3, SCRUB=4, DONE=5;
    reg [2:0] state_reg;
    reg [7:0] status_reg;
    reg [1:0] clear_count_reg;
    reg [WATCHDOG_BITS-1:0] watchdog_reg;
    reg [31:0] command_watchdog_reg;
    reg command_pending_reg;
    wire command_stalled=command_valid_o && !command_ready_i;
    wire response_stalled=command_pending_reg && !(response_valid_i && response_ready_o);
    wire command_timeout=(command_stalled || response_stalled) &&
                         command_watchdog_reg>=COMMAND_TIMEOUT_CYCLES-1;
    wire child_ready, child_trap, instruction_progress, service_wait;
    wire instruction_timeout = &watchdog_reg && !instruction_progress && !service_wait;
    wire [31:0] report;
    wire child_reset_n=reset_n_i && state_reg!=CLEAR;
    wire execute_en=state_reg==RUN;
    assign work_ready_o=reset_n_i && state_reg==IDLE && child_ready;
    assign completion_valid_o=reset_n_i && state_reg==DONE;
    assign completion_status_o=completion_valid_o ? status_reg : 8'd0;
    keygen_softcore_control #(.ROM_FILE(ROM_FILE),.BLOCKING_STATUS(BLOCKING_STATUS)) control(
        .clock_i(clock_i),.reset_n_i(child_reset_n),.execute_en_i(execute_en),
        .ready_o(child_ready),.trap_o(child_trap),.instruction_progress_o(instruction_progress),.service_wait_o(service_wait),
        .command_valid_o(command_valid_o),.command_ready_i(command_ready_i),
        .command_opcode_o(command_opcode_o),.command_arg0_o(command_arg0_o),
        .command_arg1_o(command_arg1_o),.command_arg2_o(command_arg2_o),.command_arg3_o(command_arg3_o),
        .response_valid_i(response_valid_i),.response_ready_o(response_ready_o),
        .response_status_i(response_status_i),.report_o(report));
    // Link acceptance is internal and bounded even for DRAW. Once DRAW is
    // accepted, its external generation source may stall without a deadline.
    // Other descriptors must finish even while the CPU keeps polling STATUS.
    always @(posedge clock_i) begin
        if(!reset_n_i || state_reg!=RUN) begin
            command_watchdog_reg<=0;
            command_pending_reg<=0;
        end else begin
            if(command_valid_o && command_ready_i)
                command_pending_reg<=command_opcode_o!=8'h30;
            else if(response_valid_i && response_ready_o)
                command_pending_reg<=0;
            if(command_stalled || response_stalled)
                command_watchdog_reg<=command_watchdog_reg+1'b1;
            else command_watchdog_reg<=0;
        end
    end
    always @(posedge clock_i) begin
        if (!reset_n_i) begin
            state_reg<=INIT; status_reg<=0; clear_count_reg<=0; watchdog_reg<=0;
        end else case(state_reg)
            INIT: if(child_ready) state_reg<=IDLE;
            IDLE: if(work_valid_i && work_ready_o) begin state_reg<=RUN; watchdog_reg<=0; end
            RUN: begin
                if(instruction_progress || service_wait) watchdog_reg<=0;
                else watchdog_reg<=watchdog_reg+1'b1;
                if(child_trap || instruction_timeout || command_timeout || report[31:24]==8'ha5) begin
                    if(child_trap) status_reg<=8'd6;
                    else if(instruction_timeout || command_timeout) status_reg<=8'd7;
                    else status_reg<=report[7:0];
                    state_reg<=CLEAR; clear_count_reg<=0;
                end
            end
            CLEAR: begin
                clear_count_reg<=clear_count_reg+1'b1;
                if(clear_count_reg==2'd2) state_reg<=SCRUB;
            end
            SCRUB: if(child_ready) state_reg<=DONE;
            DONE: if(completion_ready_i) state_reg<=IDLE;
            default: state_reg<=INIT;
        endcase
    end
endmodule
