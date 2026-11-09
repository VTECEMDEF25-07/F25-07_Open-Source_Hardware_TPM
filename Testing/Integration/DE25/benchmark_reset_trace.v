// Test-only reset observation. Never drives a functional reset or fan setting.
module benchmark_event_count (
    input clock_i, configuration_reset_i, event_n_i,
    output reg [31:0] gray_o
);
    reg pending_reg, clear_reg;
    reg [31:0] count_reg;
    // An asynchronous set retains even a pulse shorter than the raw-clock period.
    // The raw domain acknowledges the event before rearming the capture flop.
    always @(posedge clock_i or negedge event_n_i) begin
        if (!event_n_i) pending_reg <= 1'b1;
        else if (configuration_reset_i || clear_reg) pending_reg <= 1'b0;
    end
    always @(posedge clock_i or posedge configuration_reset_i) begin
        if (configuration_reset_i) begin
            count_reg <= 0; clear_reg <= 0; gray_o <= 0;
        end else begin
            gray_o <= count_reg ^ (count_reg >> 1);
            if (pending_reg && !clear_reg) begin
                count_reg <= count_reg + 1'b1;
                clear_reg <= 1'b1;
            end else if (!pending_reg) clear_reg <= 1'b0;
        end
    end
endmodule

module benchmark_reset_trace (
    input clock_i, configuration_reset_i,
    input pll_locked_i, spi_reset_n_i, board_reset_n_i, core_reset_n_i,
    output [159:0] gray_o
);
    benchmark_event_count pll_events(clock_i,configuration_reset_i,pll_locked_i,gray_o[31:0]);
    benchmark_event_count spi_events(clock_i,configuration_reset_i,spi_reset_n_i,gray_o[63:32]);
    benchmark_event_count board_events(clock_i,configuration_reset_i,board_reset_n_i,gray_o[95:64]);
    benchmark_event_count core_events(clock_i,configuration_reset_i,core_reset_n_i,gray_o[127:96]);
    reg [15:0] divider_reg;
    reg [31:0] milliseconds_reg, milliseconds_gray_reg;
    assign gray_o[159:128] = milliseconds_gray_reg;
    // Retained across SPI, PLL-lock and board-button resets; configuration only.
    always @(posedge clock_i or posedge configuration_reset_i) begin
        if (configuration_reset_i) begin
            divider_reg <= 0; milliseconds_reg <= 0; milliseconds_gray_reg <= 0;
        end else begin
            if (divider_reg == 49999) begin
                divider_reg <= 0; milliseconds_reg <= milliseconds_reg + 1'b1;
            end else divider_reg <= divider_reg + 1'b1;
            milliseconds_gray_reg <= milliseconds_reg ^ (milliseconds_reg >> 1);
        end
    end
endmodule
