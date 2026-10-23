// ===========================================================================
// uart.v
//
// Minimal UART, 8 data bits, no parity, 1 stop bit (8N1).
// CLKS_PER_BIT = clock frequency / baud rate, e.g. 100 MHz / 115200 = 868.
//
// Written by Jungyeon Won with the help of generative AI
// ===========================================================================
`timescale 1ns/1ps
 
// ---------------------------------------------------------------------------
// uart_tx: send one byte. Pulse start for one cycle while ready is 1.
// ---------------------------------------------------------------------------
module uart_tx #(
    parameter integer CLKS_PER_BIT = 868
) (
    input  wire       clk,
    input  wire       rst_n,
    input  wire [7:0] data,
    input  wire       start,
    output wire       ready,     // 1 = idle, can take a new byte
    output reg        tx         // serial line, idles high
);
    reg [9:0]  frame;            // {stop, data[7:0], start}, sent LSB first
    reg [3:0]  bits_left;
    reg [31:0] clk_count;
 
    assign ready = (bits_left == 4'd0);
 
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tx        <= 1'b1;
            frame     <= 10'h3FF;
            bits_left <= 4'd0;
            clk_count <= 32'd0;
        end else if (bits_left == 4'd0) begin
            if (start) begin
                frame     <= {1'b1, data, 1'b0};
                bits_left <= 4'd10;
                clk_count <= 32'd0;
                tx        <= 1'b0;             // start bit goes out now
            end
        end else if (clk_count == CLKS_PER_BIT - 1) begin
            clk_count <= 32'd0;
            bits_left <= bits_left - 4'd1;
            frame     <= {1'b1, frame[9:1]};
            tx        <= (bits_left == 4'd1) ? 1'b1 : frame[1];
        end else begin
            clk_count <= clk_count + 32'd1;
        end
    end
endmodule
 
// ---------------------------------------------------------------------------
// uart_rx: receive bytes. valid pulses for one cycle with each byte.
// ---------------------------------------------------------------------------
module uart_rx #(
    parameter integer CLKS_PER_BIT = 868
) (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       rx,        // serial line from the PC (asynchronous)
    output reg  [7:0] data,
    output reg        valid
);
    // Two-flop synchronizer: rx is not related to clk.
    reg [1:0] rx_sync;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) rx_sync <= 2'b11;
        else        rx_sync <= {rx_sync[0], rx};
    end
    wire rx_s = rx_sync[1];
 
    localparam [1:0] R_IDLE = 2'd0, R_START = 2'd1, R_DATA = 2'd2, R_STOP = 2'd3;
    reg [1:0]  state;
    reg [31:0] clk_count;
    reg [2:0]  bit_index;
    reg [7:0]  shift;
 
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state     <= R_IDLE;
            clk_count <= 32'd0;
            bit_index <= 3'd0;
            shift     <= 8'd0;
            data      <= 8'd0;
            valid     <= 1'b0;
        end else begin
            valid <= 1'b0;
            case (state)
                R_IDLE: if (!rx_s) begin              // falling edge = start bit
                    clk_count <= 32'd0;
                    state     <= R_START;
                end
                R_START: if (clk_count == CLKS_PER_BIT/2 - 1) begin
                    // Middle of the start bit: still low means it's real.
                    clk_count <= 32'd0;
                    bit_index <= 3'd0;
                    state     <= rx_s ? R_IDLE : R_DATA;
                end else clk_count <= clk_count + 32'd1;
                R_DATA: if (clk_count == CLKS_PER_BIT - 1) begin
                    clk_count <= 32'd0;
                    shift     <= {rx_s, shift[7:1]};  // LSB arrives first
                    if (bit_index == 3'd7) state <= R_STOP;
                    bit_index <= bit_index + 3'd1;
                end else clk_count <= clk_count + 32'd1;
                R_STOP: if (clk_count == CLKS_PER_BIT - 1) begin
                    clk_count <= 32'd0;
                    state     <= R_IDLE;
                    if (rx_s) begin                   // good stop bit
                        data  <= shift;
                        valid <= 1'b1;
                    end
                end else clk_count <= clk_count + 32'd1;
            endcase
        end
    end
endmodule
 