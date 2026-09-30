// RNG.v
//
// Top-level module that connects:
// entropy_source -> future Hash.v placeholder -> random_number_generation
//
// Hash.v is intentionally not implemented yet. For now, entropy_output is
// passed directly into random_number_generation through hash_output_placeholder
// so this top-level module compiles.
//
// The random_number_generation module creates a 256-bit internal value. This
// top level outputs that value 8 bits at a time to reduce physical FPGA pins.

module RNG (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        enable,
    output reg  [7:0]  random_output
);

    wire [255:0] entropy_output;
    wire         entropy_valid;

    wire [255:0] hash_output_placeholder;
    wire         hash_valid_placeholder;
    wire [255:0] random_output_internal;
    wire         random_valid_internal;

    reg [255:0] random_output_buffer;
    reg [4:0]   byte_count;
    reg         byte_stream_active;

    entropy_source u_entropy_source (
        .clk           (clk),
        .rst_n         (rst_n),
        .enable        (enable),
        .entropy_output(entropy_output),
        .entropy_valid (entropy_valid)
    );

    // Future Hash.v connection:
    //
    // Hash u_hash (
    //     .clk        (clk),
    //     .rst_n      (rst_n),
    //     .enable     (entropy_valid),
    //     .hash_input (entropy_output),
    //     .hash_output(hash_output_placeholder),
    //     .hash_valid (hash_valid_placeholder)
    // );
    //
    // Placeholder passthrough until Hash.v is implemented.
    assign hash_output_placeholder = entropy_output;
    assign hash_valid_placeholder  = entropy_valid;

    random_number_generation u_random_number_generation (
        .clk          (clk),
        .rst_n        (rst_n),
        .enable       (hash_valid_placeholder),
        .hash_input   (hash_output_placeholder),
        .random_output(random_output_internal),
        .random_valid (random_valid_internal)
    );

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            random_output        <= 8'b0;
            random_output_buffer <= 256'b0;
            byte_count           <= 5'b0;
            byte_stream_active   <= 1'b0;
        end else begin
            if (random_valid_internal) begin
                random_output_buffer <= random_output_internal;
                random_output        <= random_output_internal[7:0];
                byte_count           <= 5'd1;
                byte_stream_active   <= 1'b1;
            end else if (byte_stream_active) begin
                random_output <= random_output_buffer[byte_count * 8 +: 8];

                if (byte_count == 5'd31) begin
                    byte_count         <= 5'b0;
                    byte_stream_active <= 1'b0;
                end else begin
                    byte_count <= byte_count + 5'b1;
                end
            end
        end
    end

endmodule
