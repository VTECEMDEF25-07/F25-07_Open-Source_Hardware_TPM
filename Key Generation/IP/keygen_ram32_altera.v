// One enabled-edge read, new data on collision. Reset never clears memory.
module keygen_ram32_altera #(parameter ADDRESS_WIDTH = 8) (
    input clock_i,
    input reset_n_i,
    input clock_en_i,
    input write_en_i,
    input [ADDRESS_WIDTH-1:0] write_address_i,
    input [31:0] write_data_i,
    input read_en_i,
    input [ADDRESS_WIDTH-1:0] read_address_i,
    output read_valid_o,
    output [31:0] read_data_o
);
    reg read_valid_reg;
    always @(posedge clock_i or negedge reset_n_i) begin
        if (!reset_n_i) read_valid_reg <= 1'b0;
        else if (clock_en_i) read_valid_reg <= read_en_i;
    end
    assign read_valid_o = read_valid_reg;
    wire [31:0] memory_data;
    reg forward_reg;
    reg [31:0] forward_data_reg;
    always @(posedge clock_i or negedge reset_n_i) begin
        if (!reset_n_i) begin
            forward_reg <= 1'b0;
            forward_data_reg <= 32'b0;
        end else if (clock_en_i) begin
            forward_reg <= write_en_i && read_en_i &&
                           write_address_i == read_address_i;
            forward_data_reg <= write_data_i;
        end
    end
    assign read_data_o = forward_reg ? forward_data_reg : memory_data;
    // Explicit forwarding defines collisions independently of vendor RAM mode.
    altsyncram #(
        .operation_mode("DUAL_PORT"), .intended_device_family("Agilex 5"),
        .width_a(32), .width_b(32),
        .widthad_a(ADDRESS_WIDTH), .widthad_b(ADDRESS_WIDTH),
        .numwords_a(1 << ADDRESS_WIDTH), .numwords_b(1 << ADDRESS_WIDTH),
        .address_reg_b("CLOCK0"), .rdcontrol_reg_b("CLOCK0"),
        .outdata_reg_b("UNREGISTERED"),
        .clock_enable_input_a("NORMAL"), .clock_enable_input_b("NORMAL"),
        .read_during_write_mode_mixed_ports("DONT_CARE"),
        .ram_block_type("M20K"), .power_up_uninitialized("TRUE")
    ) memory (
        .clock0(clock_i), .clock1(),
        .clocken0(clock_en_i && reset_n_i), .clocken1(1'b1),
        .clocken2(1'b1), .clocken3(1'b1), .aclr0(1'b0), .aclr1(1'b0),
        .wren_a(write_en_i && reset_n_i), .wren_b(1'b0),
        .rden_a(1'b0), .rden_b(read_en_i),
        .address_a(write_address_i), .address_b(read_address_i),
        .addressstall_a(1'b0), .addressstall_b(1'b0),
        .data_a(write_data_i), .data_b(32'b0),
        .byteena_a(1'b1), .byteena_b(1'b1),
        .q_a(), .q_b(memory_data), .eccstatus()
    );
endmodule
