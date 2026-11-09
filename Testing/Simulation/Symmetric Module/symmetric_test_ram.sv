// Simulation-only byte RAM: one outstanding transaction, acknowledged writes,
// deterministic variable latency/backpressure and an injectable failed response.
`timescale 1ns/1ps
module symmetric_test_ram #(
    parameter ADDR_WIDTH = 12,
    parameter DEPTH = 1 << ADDR_WIDTH
)(
    input logic clock_i, reset_n_i,
    input logic req_valid_i, req_write_i,
    output wire req_ready_o,
    input logic [ADDR_WIDTH-1:0] req_addr_i,
    input logic [7:0] req_data_i,
    output logic rsp_valid_o,
    input logic rsp_ready_i,
    output logic [7:0] rsp_data_o,
    output logic rsp_error_o
);
    logic [7:0] memory [0:DEPTH-1];
    integer cycle_count = 0, transaction_count = 0;
    integer fail_transaction = -1, latency_max = 5, stall_modulus = 4;
    integer delay_reg;
    bit pending_reg, write_reg;
    logic [ADDR_WIDTH-1:0] address_reg;
    logic [7:0] data_reg;
    assign req_ready_o = reset_n_i && !pending_reg && !rsp_valid_o &&
        (stall_modulus == 0 || cycle_count % stall_modulus == 0);
    always @(posedge clock_i or negedge reset_n_i) begin
        if (!reset_n_i) begin
            pending_reg <= 0;
            rsp_valid_o <= 0;
            rsp_error_o <= 0;
            rsp_data_o <= 0;
            cycle_count <= 0;
            transaction_count <= 0;
            delay_reg <= 0;
            write_reg <= 0;
            address_reg <= 0;
            data_reg <= 0;
        end else begin
            cycle_count <= cycle_count + 1;
            if (req_valid_i && req_ready_o) begin
                if (pending_reg || rsp_valid_o) $fatal(1, "multiple outstanding requests");
                pending_reg <= 1;
                write_reg <= req_write_i;
                address_reg <= req_addr_i;
                data_reg <= req_data_i;
                delay_reg <= latency_max == 0 ? 0 : transaction_count % (latency_max + 1);
                transaction_count <= transaction_count + 1;
            end
            if (pending_reg) begin
                if (delay_reg != 0) delay_reg <= delay_reg - 1;
                else begin
                    pending_reg <= 0;
                    rsp_valid_o <= 1;
                    rsp_error_o <= transaction_count - 1 == fail_transaction;
                    rsp_data_o <= memory[address_reg];
                    // A failed write in this model has no side effect. Real adapters
                    // may have uncertain writes; the caller must discard failed output.
                    if (write_reg && transaction_count - 1 != fail_transaction)
                        memory[address_reg] <= data_reg;
                end
            end
            if (rsp_valid_o && rsp_ready_i) rsp_valid_o <= 0;
        end
    end
endmodule
