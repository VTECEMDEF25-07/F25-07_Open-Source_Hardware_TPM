// Actual-hardware status snapshot for the RevD HPS LCD service/mailbox.
// No keys, plaintext, SPI pins, invented progress or host-message write port.
// Codex assisted, overnight demo status contract, 2026-11-10.
`timescale 1ns/1ps
module demo_lcd_status (
    input wire clock_i, reset_n_i,
    input wire status_valid_i,
    input wire [3:0] status_code_i,
    input wire [7:0] status_detail_i,
    input wire [31:0] operation_id_i,
    input wire [1:0] provider_mode_i,
    output wire [31:0] status_word_o,
    output wire [31:0] operation_id_o,
    output wire [31:0] sequence_o
);
    reg [1:0] reset_release;
    reg captured;
    reg [3:0] code;
    reg [7:0] detail;
    reg [31:0] operation_id, sequence_number;
    reg [1:0] provider_mode;
    always @(posedge clock_i or negedge reset_n_i)
        if (!reset_n_i) reset_release <= 0;
        else reset_release <= {reset_release[0],1'b1};
    wire running = reset_n_i && reset_release[1];
    wire changed = !captured || code != status_code_i || detail != status_detail_i ||
        operation_id != operation_id_i || provider_mode != provider_mode_i;
    assign status_word_o = {8'h01,detail,8'd0,captured,(code >= 9),provider_mode,code};
    assign operation_id_o = operation_id;
    assign sequence_o = sequence_number;
    always @(posedge clock_i or negedge reset_n_i) begin
        if (!reset_n_i) begin
            captured <= 0; code <= 0; detail <= 0;
            operation_id <= 0; sequence_number <= 0; provider_mode <= 2;
        end else if (running && status_valid_i && changed) begin
            captured <= 1; code <= status_code_i; detail <= status_detail_i;
            operation_id <= operation_id_i; provider_mode <= provider_mode_i;
            sequence_number <= sequence_number + 1'b1;
        end
    end
endmodule
