// Unsigned product: two enabled rising edges; reset invalidates the pipeline.
module keygen_mult32_generic (
    input clock_i,
    input reset_n_i,
    input clock_en_i,
    input valid_i,
    input [31:0] left_i,
    input [31:0] right_i,
    output valid_o,
    output [63:0] product_o
);
    reg [1:0] valid_reg;
    always @(posedge clock_i or negedge reset_n_i) begin
        if (!reset_n_i) valid_reg <= 2'b00;
        else if (clock_en_i) valid_reg <= {valid_reg[0], valid_i};
    end
    assign valid_o = valid_reg[1];
    reg [63:0] first_product_reg;
    reg [63:0] second_product_reg;
    always @(posedge clock_i or negedge reset_n_i) begin
        if (!reset_n_i) begin
            first_product_reg <= 64'b0;
            second_product_reg <= 64'b0;
        end else if (clock_en_i) begin
            first_product_reg <= left_i * right_i;
            second_product_reg <= first_product_reg;
        end
    end
    assign product_o = second_product_reg;
endmodule
