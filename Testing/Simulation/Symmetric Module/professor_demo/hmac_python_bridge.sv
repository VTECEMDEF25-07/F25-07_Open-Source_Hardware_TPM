// Filename: hmac_python_bridge.sv
// Author: Codex, for Makeda Solomon
// Date: October 14, 2026
// Description: SIMULATION ONLY. Same interface/name as the practice placeholder,
// but calls Python hmac on the actual accepted key/message. This file replaces
// the placeholder ONLY in the demo's isolated simulation library. Not in QSF.
// Wall-clock Python execution is not a model of hardware HMAC latency.
`timescale 1ns/1ps
`default_nettype none
module hmac_sha256_placeholder (
    input wire clk_i, reset_n_i, req_valid_i,
    output wire req_ready_o,
    input wire [255:0] key_i,
    input wire [607:0] message_i,
    output reg [255:0] digest_o,
    output reg rsp_valid_o,
    input wire rsp_ready_i,
    output reg error_o
);
    string python_exe, service_script, command;
    integer fd, status, scanned;
    reg [255:0] returned_digest;

    initial begin
        if (!$value$plusargs("PYTHON=%s", python_exe) ||
            !$value$plusargs("HMAC_SERVICE=%s", service_script))
            $fatal(1, "Python HMAC service configuration missing");
    end

    assign req_ready_o = reset_n_i && !rsp_valid_o;

    always @(posedge clk_i or negedge reset_n_i) begin
        if (!reset_n_i) begin
            digest_o <= 0;
            rsp_valid_o <= 0;
            error_o <= 0;
        end else if (req_valid_i && req_ready_o) begin
            // Write captured request bytes; do not reconstruct them in Python.
            fd = $fopen("hmac_request.txt", "w");
            if (!fd) $fatal(1, "Cannot write HMAC request");
            $fdisplay(fd, "%064h", key_i);
            $fdisplay(fd, "%0152h", message_i);
            $fclose(fd);
            command = $sformatf("%s %s hmac_request.txt hmac_response.txt", python_exe, service_script);
            status = $system(command);
            if (status != 0) $fatal(1, "Python HMAC service failed: %0d", status);
            fd = $fopen("hmac_response.txt", "r");
            if (!fd) $fatal(1, "Cannot read HMAC response");
            scanned = $fscanf(fd, "%h", returned_digest);
            $fclose(fd);
            if (scanned != 1 || ^returned_digest === 1'bx)
                $fatal(1, "Malformed HMAC digest");
            $display("HMAC|%064h|%0152h|%064h", key_i, message_i, returned_digest);
            digest_o <= returned_digest;
            rsp_valid_o <= 1;
            error_o <= 0;
        end else if (rsp_valid_o && rsp_ready_i) begin
            rsp_valid_o <= 0;
            digest_o <= 0;
        end
    end
endmodule
`default_nettype wire
