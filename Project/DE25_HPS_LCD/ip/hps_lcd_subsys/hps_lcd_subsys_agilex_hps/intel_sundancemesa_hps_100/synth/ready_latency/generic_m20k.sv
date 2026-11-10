// (C) 2001-2026 Altera Corporation. All rights reserved.
// Your use of Altera Corporation's design tools, logic functions and other 
// software and tools, and its AMPP partner logic functions, and any output 
// files from any of the foregoing (including device programming or simulation 
// files), and any associated documentation or information are expressly subject 
// to the terms and conditions of the Altera Program License Subscription 
// Agreement, Altera IP License Agreement, or other applicable 
// license agreement, including, without limitation, that your use is for the 
// sole purpose of programming logic devices manufactured by Altera and sold by 
// Altera or its authorized distributors.  Please refer to the applicable 
// agreement for further details.


// // Copyright 2021 Intel Corporation. 
// //
// // This reference design file is subject licensed to you by the terms and 
// // conditions of the applicable License Terms and Conditions for Hardware 
// // Reference Designs and/or Design Examples (either as signed by you or 
// // found at https://www.altera.com/common/legal/leg-license_agreement.html ).  
// //
// // As stated in the license, you agree to only use this reference design 
// // solely in conjunction with Intel FPGAs or Intel CPLDs.  
// //
// // THE REFERENCE DESIGN IS PROVIDED "AS IS" WITHOUT ANY EXPRESS OR IMPLIED
// // WARRANTY OF ANY KIND INCLUDING WARRANTIES OF MERCHANTABILITY, 
// // NONINFRINGEMENT, OR FITNESS FOR A PARTICULAR PURPOSE. Intel does not 
// // warrant or assume responsibility for the accuracy or completeness of any
// // information, links or other items within the Reference Design and any 
// // accompanying materials.
// //
// // In the event that you do not agree with such terms and conditions, do not
// // use the reference design file.
// /////////////////////////////////////////////////////////////////////////////

(* altera_attribute = "-name SYNCHRONIZER_IDENTIFICATION OFF" *)
module  generic_m20k   #(
    parameter WIDTH = 8,
    parameter ADDR_WIDTH = 5
)(
    input clk,
    input [WIDTH-1:0] din,
    input [ADDR_WIDTH-1:0] waddr,
    input we,
    input re,
    input [ADDR_WIDTH-1:0] raddr,
    output [WIDTH-1:0] dout,
    input sclr
    );

    localparam DEPTH = 1 << ADDR_WIDTH;
    altera_syncram  altera_syncram_component (
                .address_a (waddr),
                .address_b (raddr),
                .clock0 (clk),
                .data_a (din),
                .wren_a (we),
                .rden_b (re),
                .q_b (dout),
                .aclr0 (1'b0),
                .aclr1 (1'b0),
                .address2_a (1'b1),
                .address2_b (1'b1),
                .addressstall_a (1'b0),
                .addressstall_b (1'b0),
                .byteena_a (1'b1),
                .byteena_b (1'b1),
                .clock1 (1'b1),
                .clocken0 (1'b1),
                .clocken1 (1'b1),
                .clocken2 (1'b1),
                .clocken3 (1'b1),
                .data_b ({WIDTH{1'b1}}),
                .eccencbypass (1'b0),
                .eccencparity (8'b0),
                .eccstatus (),
                .q_a (),
                .rden_a (1'b1),
                .sclr (sclr),
                .wren_b (1'b0));
    defparam
        altera_syncram_component.address_aclr_b  = "NONE",
        altera_syncram_component.address_reg_b  = "CLOCK0",
        altera_syncram_component.clock_enable_input_a  = "BYPASS",
        altera_syncram_component.clock_enable_input_b  = "BYPASS",
        altera_syncram_component.clock_enable_output_b  = "BYPASS",
        altera_syncram_component.enable_ecc  = "FALSE",
        altera_syncram_component.enable_force_to_zero  = "FALSE",
        altera_syncram_component.optimization_option  = "HIGH_SPEED",
        altera_syncram_component.intended_device_family  = "Agilex 5",
        altera_syncram_component.lpm_type  = "altera_syncram",
        altera_syncram_component.numwords_a  = DEPTH,
        altera_syncram_component.numwords_b  = DEPTH,
        altera_syncram_component.operation_mode  = "DUAL_PORT",
        altera_syncram_component.outdata_aclr_b  = "NONE",
        altera_syncram_component.outdata_sclr_b  = "SCLEAR",
        altera_syncram_component.outdata_reg_b  = "CLOCK0",
        altera_syncram_component.power_up_uninitialized  = "FALSE",
        altera_syncram_component.ram_block_type  = "M20K",
        altera_syncram_component.read_during_write_mode_mixed_ports  = "DONT_CARE",
        altera_syncram_component.widthad_a  = ADDR_WIDTH,
        altera_syncram_component.widthad_b  = ADDR_WIDTH,
        altera_syncram_component.width_a  = WIDTH,
        altera_syncram_component.width_b  = WIDTH,
        altera_syncram_component.width_byteena_a  = 1;


endmodule
`ifdef QUESTA_INTEL_OEM
`pragma questa_oem_00 "HKE1A/xPv2xENkX8yp9xoqkNge46lbMcPP7BkxII5uVAESNhbSQ48MxyKbstHt+Z73pjaLnv4JZL7VIg1Zl08sUjb+a/DJUEwISomi4A5vL/9xMR86jPaYlbfbvTGJyK0dtsE3CZllK6Orkctae64nBtq574elgMyKlt1SuCin3Dz1hwF/fuGJz1pzcKZ2XKUwAVd2517c5HdE1spdswJCP157Z27/3eHr0YYHHsZ+CQAVa6wmu2L462qI+4DLAxUoQU/CTMFODpiF7t2KJrDm0kNpO4w+uyqrqYUAu/xS9XnLfavpuU+f8s3yzvXSbbQ4P/uyl+39ciOdXdED3idz1i4iozt3obrJjSYpqW7eqwkRu9mZ/LH07uRMT/g46MjJ5//X7A1JmcZCj+vVYkMOSuIg0gbaDPB04xNQ8o5m1QNHgxFiE3zIHq+PvWz5EItig99BIO+UGVXMSaBDn3BCVHS0XX6n9ZRT7KY7zqQqHWem/djS300RY55Y2eRjXLuMqhFq1bXkMdtfjtQkVYxPLEbjuTA6CMGvzYRkgY6k11Vq8Zbn2YHVLrg8r3DmSSvdhSq7cZNT/G0nYBJsRi7p2YiRQ6lwMe2PL3ZcKwe3T2tyyGXEjcYRlzpWsTd5SEDqbBnGOaVkliEkIFUJ28zXb8tTE8Lr8IyrzGYLr0XLkfkLARTvLXKihK+us3zya1818dGWPnEvUU7avhGdKRblkJ25ik+pcrXdd1ab2KdYlQdsVeeoCn0gFpdW1JXjBpP+EDjd8tYs3uDgsCw5dOUBHzSKh/WOBM8NFFlJRBKobxJplA93pinHwhgz0uwaipnCUqbGr6ee69SYpGE/Ba58Om/PHuYe3l6qA3acnQUAfDQK01OXHQdb9BQAXotHvMImZe14C30CQn4COhhw0KfSdJ1yiM0Hw0Ts62UxnWMuDAiyokSqe4ISeAftZpwcLGJ0RcFgTp9Ophz48JSLJu8ygxIHyMFpq59KoOPHqweemvyKA8g8L6NnO5Tkfs6Nch"
`endif