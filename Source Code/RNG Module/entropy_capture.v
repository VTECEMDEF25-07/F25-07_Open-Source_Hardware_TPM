// ===========================================================================
// entropy_capture.v
//
// Collects raw noise-source samples for NIST SP 800-90B testing and sends
// them to a PC over UART.
//
// The noise source makes one sample per clock, far faster than a UART can
// carry, and 800-90B needs CONSECUTIVE samples. So samples are first stored
// in on-chip RAM at full speed, then sent to the PC slowly.
//
// Commands from the PC (one ASCII byte each):
//   'P'  ping. Replies 'K'. Use it to check the serial link.
//   'S'  sequential test. Records SEQ_BYTES*8 consecutive samples
//        (default 1,048,576), then sends SEQ_BYTES bytes.
//   'R'  restart test. RESTARTS times (default 1000): stop the rings for
//        OFF_CYCLES clocks, start them again, record the first
//        RESTART_SAMPLES samples (default 1000). Then sends
//        RESTARTS*RESTART_SAMPLES/8 bytes (default 125,000), restart 1 first.
//
// Each byte holds 8 samples, the earliest in the most significant bit.
// The PC script unpacks them into the one-sample-per-byte format the NIST
// tool reads.
//
// Written by Jungyeon Won with the help of generative AI
// ===========================================================================
`timescale 1ns/1ps
 
module entropy_capture #(
    parameter integer CLKS_PER_BIT    = 868,     // clock Hz / baud
    parameter integer SEQ_BYTES       = 131072,  // 1,048,576 samples
    parameter integer RESTARTS        = 1000,
    parameter integer RESTART_SAMPLES = 1000,    // must be a multiple of 8
    parameter integer OFF_CYCLES      = 4096,    // clocks the rings stay off
    parameter integer ADDR_W          = 17       // RAM holds 2^ADDR_W bytes
) (
    input  wire clk,
    input  wire rst_n,
 
    input  wire uart_rx,
    output wire uart_tx,
 
    // To/from entropy_source
    output reg  source_enable,
    input  wire raw_sample,
    input  wire raw_sample_valid,
 
    output wire busy             // 1 while capturing or sending (for an LED)
);
 
    localparam integer RESTART_BYTES = RESTART_SAMPLES / 8;
    localparam integer RESTART_TOTAL = RESTARTS * RESTART_BYTES;
 
    // Compile-time checks: fail the build with a readable name if a
    // parameter is unusable.
    generate
        if ((RESTART_SAMPLES % 8) != 0) begin : bad_restart_samples
            ERROR_RESTART_SAMPLES_must_be_multiple_of_8 u_err();
        end
        if (SEQ_BYTES > (1 << ADDR_W) || RESTART_TOTAL > (1 << ADDR_W)) begin : bad_ram
            ERROR_capture_RAM_too_small_increase_ADDR_W u_err();
        end
    endgenerate
 
    // -----------------------------------------------------------------------
    // UART
    // -----------------------------------------------------------------------
    wire [7:0] rx_data;
    wire       rx_valid;
    reg  [7:0] tx_data;
    reg        tx_start;
    wire       tx_ready;
 
    uart_rx #(.CLKS_PER_BIT(CLKS_PER_BIT)) u_rx (
        .clk(clk), .rst_n(rst_n), .rx(uart_rx), .data(rx_data), .valid(rx_valid)
    );
    uart_tx #(.CLKS_PER_BIT(CLKS_PER_BIT)) u_tx (
        .clk(clk), .rst_n(rst_n), .data(tx_data), .start(tx_start),
        .ready(tx_ready), .tx(uart_tx)
    );
 
    // -----------------------------------------------------------------------
    // Capture RAM: one write port, one read port. Quartus infers block RAM
    // (M20K on Agilex) from this pattern.
    // -----------------------------------------------------------------------
    reg [7:0]        mem [0:(1 << ADDR_W) - 1];
    reg              mem_we;
    reg [ADDR_W-1:0] mem_waddr;
    reg [7:0]        mem_wdata;
    reg [ADDR_W-1:0] mem_raddr;
    reg [7:0]        mem_rdata;
 
    always @(posedge clk) begin
        if (mem_we) mem[mem_waddr] <= mem_wdata;
        mem_rdata <= mem[mem_raddr];
    end
 
    // -----------------------------------------------------------------------
    // Control FSM
    // -----------------------------------------------------------------------
    localparam [2:0] S_IDLE    = 3'd0;
    localparam [2:0] S_CAPTURE = 3'd1;  // record samples into RAM
    localparam [2:0] S_OFF     = 3'd2;  // restart test: rings stopped
    localparam [2:0] S_RD      = 3'd3;  // dump: RAM read in flight
    localparam [2:0] S_SEND    = 3'd4;  // dump: hand byte to UART
    localparam [2:0] S_WAITTX  = 3'd5;  // dump: wait for UART to finish
    localparam [2:0] S_PONG    = 3'd6;  // reply to ping
 
    reg [2:0]  state;
    reg        restart_mode;
    reg [6:0]  shift;            // first 7 samples of the current byte
    reg [2:0]  bit_count;
    reg [31:0] row_bytes;        // bytes captured since this restart
    reg [31:0] restart_count;    // restarts completed
    reg [31:0] off_count;
    reg [31:0] total_bytes;      // bytes to capture / send this run
    reg [31:0] bytes_done;
 
    assign busy = (state != S_IDLE);
 
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state         <= S_IDLE;
            source_enable <= 1'b1;        // rings run while idle
            restart_mode  <= 1'b0;
            shift         <= 7'd0;
            bit_count     <= 3'd0;
            row_bytes     <= 32'd0;
            restart_count <= 32'd0;
            off_count     <= 32'd0;
            total_bytes   <= 32'd0;
            bytes_done    <= 32'd0;
            mem_we        <= 1'b0;
            mem_waddr     <= {ADDR_W{1'b0}};
            mem_wdata     <= 8'd0;
            mem_raddr     <= {ADDR_W{1'b0}};
            tx_data       <= 8'd0;
            tx_start      <= 1'b0;
        end else begin
            mem_we   <= 1'b0;
            tx_start <= 1'b0;
 
            case (state)
                // -----------------------------------------------------------
                S_IDLE: begin
                    source_enable <= 1'b1;
                    if (rx_valid) begin
                        bit_count     <= 3'd0;
                        bytes_done    <= 32'd0;
                        row_bytes     <= 32'd0;
                        restart_count <= 32'd0;
                        mem_waddr     <= {ADDR_W{1'b0}};
                        case (rx_data)
                            "P": state <= S_PONG;
                            "S": begin
                                restart_mode <= 1'b0;
                                total_bytes  <= SEQ_BYTES;
                                state        <= S_CAPTURE;
                            end
                            "R": begin
                                restart_mode  <= 1'b1;
                                total_bytes   <= RESTART_TOTAL;
                                source_enable <= 1'b0;   // first restart
                                off_count     <= 32'd0;
                                state         <= S_OFF;
                            end
                            default: ;                   // ignore anything else
                        endcase
                    end
                end
 
                // -----------------------------------------------------------
                S_PONG: if (tx_ready) begin
                    tx_data  <= "K";
                    tx_start <= 1'b1;
                    state    <= S_IDLE;
                end
 
                // -----------------------------------------------------------
                // raw_sample_valid is low until the source has warmed up, so
                // only samples the real design would use are recorded.
                S_CAPTURE: if (raw_sample_valid) begin
                    if (bit_count == 3'd7) begin
                        mem_wdata  <= {shift, raw_sample};   // earliest = MSB
                        mem_we     <= 1'b1;
                        mem_waddr  <= bytes_done[ADDR_W-1:0];
                        bytes_done <= bytes_done + 32'd1;
                        row_bytes  <= row_bytes + 32'd1;
 
                        if (bytes_done + 32'd1 == total_bytes) begin
                            // All data captured: start sending.
                            bytes_done    <= 32'd0;
                            mem_raddr     <= {ADDR_W{1'b0}};
                            source_enable <= 1'b1;
                            state         <= S_RD;
                        end else if (restart_mode &&
                                     row_bytes + 32'd1 == RESTART_BYTES) begin
                            // This restart's samples are done: stop the rings.
                            row_bytes     <= 32'd0;
                            restart_count <= restart_count + 32'd1;
                            source_enable <= 1'b0;
                            off_count     <= 32'd0;
                            state         <= S_OFF;
                        end
                    end else begin
                        shift <= {shift[5:0], raw_sample};
                    end
                    bit_count <= bit_count + 3'd1;
                end
 
                // -----------------------------------------------------------
                S_OFF: begin
                    if (off_count == OFF_CYCLES - 1) begin
                        source_enable <= 1'b1;       // restart the rings
                        bit_count     <= 3'd0;
                        state         <= S_CAPTURE;
                    end else
                        off_count <= off_count + 32'd1;
                end
 
                // -----------------------------------------------------------
                // Dump RAM over UART. mem_rdata is valid one clock after
                // mem_raddr is set.
                S_RD:   state <= S_SEND;
 
                S_SEND: if (tx_ready) begin
                    tx_data  <= mem_rdata;
                    tx_start <= 1'b1;
                    state    <= S_WAITTX;
                end
 
                S_WAITTX: if (!tx_start && tx_ready) begin
                    if (bytes_done + 32'd1 == total_bytes) begin
                        state <= S_IDLE;
                    end else begin
                        bytes_done <= bytes_done + 32'd1;
                        mem_raddr  <= mem_raddr + 1'b1;
                        state      <= S_RD;
                    end
                end
 
                default: state <= S_IDLE;
            endcase
        end
    end
 
endmodule