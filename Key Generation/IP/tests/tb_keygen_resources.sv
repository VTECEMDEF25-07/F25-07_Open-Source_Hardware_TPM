`timescale 1ns/1ps
module tb_keygen_resources;
    reg clock_reg = 0;
    always #5 clock_reg = ~clock_reg;
    reg reset_n_reg = 0;
    reg clock_en_reg = 0;
    reg valid_reg = 0;
    reg [31:0] left_reg = 0, right_reg = 0;
    wire generic_valid, altera_valid;
    wire [63:0] generic_product, altera_product;
    reg write_en_reg = 0, read_en_reg = 0;
    reg [5:0] write_address_reg = 0, read_address_reg = 0;
    reg [31:0] write_data_reg = 0;
    wire generic_read_valid, altera_read_valid;
    wire [31:0] generic_read_data, altera_read_data;
    keygen_mult32_generic generic_mult (
        .clock_i(clock_reg), .reset_n_i(reset_n_reg), .clock_en_i(clock_en_reg),
        .valid_i(valid_reg), .left_i(left_reg), .right_i(right_reg),
        .valid_o(generic_valid), .product_o(generic_product)
    );
    keygen_ram32_generic #(.ADDRESS_WIDTH(6)) generic_ram (
        .clock_i(clock_reg), .reset_n_i(reset_n_reg), .clock_en_i(clock_en_reg),
        .write_en_i(write_en_reg), .write_address_i(write_address_reg),
        .write_data_i(write_data_reg), .read_en_i(read_en_reg),
        .read_address_i(read_address_reg), .read_valid_o(generic_read_valid),
        .read_data_o(generic_read_data)
    );
    keygen_mult32_altera altera_mult (
        .clock_i(clock_reg), .reset_n_i(reset_n_reg), .clock_en_i(clock_en_reg),
        .valid_i(valid_reg), .left_i(left_reg), .right_i(right_reg),
        .valid_o(altera_valid), .product_o(altera_product)
    );
    keygen_ram32_altera #(.ADDRESS_WIDTH(6)) altera_ram (
        .clock_i(clock_reg), .reset_n_i(reset_n_reg), .clock_en_i(clock_en_reg),
        .write_en_i(write_en_reg), .write_address_i(write_address_reg),
        .write_data_i(write_data_reg), .read_en_i(read_en_reg),
        .read_address_i(read_address_reg), .read_valid_o(altera_read_valid),
        .read_data_o(altera_read_data)
    );
    reg [31:0] reference_memory [0:63];
    reg [63:0] first_product_reg = 0, second_product_reg = 0;
    reg [1:0] expected_valid_reg = 0;
    reg expected_read_valid_reg = 0;
    reg [31:0] expected_read_data_reg;
    integer checked_products = 0, checked_reads = 0, collisions = 0, stalls = 0;
    integer index;
    reg [31:0] random_reg = 32'h7e12a581;
    function [31:0] next_random(input [31:0] value);
        reg [31:0] work_value;
        begin
            work_value = value ^ (value << 13);
            work_value = work_value ^ (work_value >> 17);
            next_random = work_value ^ (work_value << 5);
        end
    endfunction
    always @(posedge clock_reg) begin
        if (!reset_n_reg) begin
            expected_valid_reg = 0;
            expected_read_valid_reg = 0;
        end else if (clock_en_reg) begin
            second_product_reg = first_product_reg;
            first_product_reg = {32'b0, left_reg} * {32'b0, right_reg};
            expected_valid_reg = {expected_valid_reg[0], valid_reg};
            expected_read_valid_reg = read_en_reg;
            if (write_en_reg) reference_memory[write_address_reg] = write_data_reg;
            if (read_en_reg) expected_read_data_reg = reference_memory[read_address_reg];
            if (write_en_reg && read_en_reg && write_address_reg == read_address_reg)
                collisions = collisions + 1;
        end else stalls = stalls + 1;
        #1;
        if (generic_valid !== expected_valid_reg[1] || altera_valid !== expected_valid_reg[1])
            $fatal(1, "Multiplier valid differs");
        if (expected_valid_reg[1]) begin
            if (generic_product !== second_product_reg || altera_product !== second_product_reg)
                $fatal(1, "Product differs expected=%h generic=%h altera=%h", second_product_reg, generic_product, altera_product);
            checked_products = checked_products + 1;
        end
        if (generic_read_valid !== expected_read_valid_reg || altera_read_valid !== expected_read_valid_reg)
            $fatal(1, "RAM valid differs");
        if (expected_read_valid_reg) begin
            if (generic_read_data !== expected_read_data_reg || altera_read_data !== expected_read_data_reg)
                $fatal(1, "RAM differs expected=%h generic=%h altera=%h", expected_read_data_reg, generic_read_data, altera_read_data);
            checked_reads = checked_reads + 1;
        end
    end
    initial begin
        repeat (2) @(negedge clock_reg);
        reset_n_reg = 1; clock_en_reg = 1;
        // Sweep initializes real memories; reset cannot be used as a RAM clear.
        for (index = 0; index < 64; index = index + 1) begin
            write_en_reg = 1; read_en_reg = 1;
            write_address_reg = index; read_address_reg = index;
            write_data_reg = 32'hfedc0000 + index;
            left_reg = 32'hffffffff; right_reg = index; valid_reg = 1;
            @(negedge clock_reg);
        end
        for (index = 0; index < 5000; index = index + 1) begin
            random_reg = next_random(random_reg);
            clock_en_reg = random_reg[0] | random_reg[1];
            valid_reg = random_reg[2]; write_en_reg = random_reg[3]; read_en_reg = random_reg[4];
            write_address_reg = random_reg[10:5];
            read_address_reg = random_reg[11] ? write_address_reg : random_reg[17:12];
            write_data_reg = random_reg;
            left_reg = next_random(random_reg); right_reg = next_random(left_reg);
            if (index % 101 == 0) left_reg = 0;
            if (index % 103 == 0) begin left_reg = 32'hffffffff; right_reg = 32'hffffffff; end
            reset_n_reg = index % 251 != 0;
            @(negedge clock_reg);
        end
        reset_n_reg = 1; clock_en_reg = 1; write_en_reg = 0; valid_reg = 0;
        // Read every location after resets: contents must persist.
        for (index = 0; index < 64; index = index + 1) begin
            read_en_reg = 1; read_address_reg = index;
            @(negedge clock_reg);
        end
        // Exercise the external zeroization mechanism: write every address,
        // then read it back. There is deliberately no RAM reset shortcut.
        for (index = 0; index < 64; index = index + 1) begin
            write_en_reg = 1; write_address_reg = index; write_data_reg = 0;
            read_en_reg = 1; read_address_reg = index;
            @(negedge clock_reg);
        end
        write_en_reg = 0;
        for (index = 0; index < 64; index = index + 1) begin
            read_address_reg = index;
            @(negedge clock_reg);
        end
        if (checked_products < 1000 || checked_reads < 1000 || collisions < 100 || stalls < 100)
            $fatal(1, "Insufficient coverage");
        $display("PASS resources: products=%0d reads=%0d collisions=%0d stalls=%0d", checked_products, checked_reads, collisions, stalls);
        $finish;
    end
    initial begin #1000000; $fatal(1, "Timeout"); end
endmodule
