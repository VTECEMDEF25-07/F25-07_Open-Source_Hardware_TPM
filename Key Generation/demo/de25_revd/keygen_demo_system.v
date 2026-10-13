// Test-only SPI register bank and protected-receiver stand-in. Never a production export interface.
module keygen_demo_system #(
    parameter RSA_SOFTCORE = 0, parameter ROM_FILE = "rsa_control.hex",
    parameter [255:0] BUILD_FINGERPRINT = 256'b0
) (
    input clock_i, input reset_n_i,
    input spi_clock_i, input spi_cs_n_i, input spi_mosi_i,
    output spi_miso_o, output interrupt_n_o,
    input [31:0] temperatures_i, input [31:0] fan_status_i
);
    localparam SCRUB=0, IDLE=1, SOURCE_START=2, CORE_START=3, RUN=4;
    reg [2:0] state_reg;
    reg [1:0] profile_reg, captured_profile_reg;
    reg [31:0] id_reg, captured_id_reg, scratch_reg;
    reg [255:0] seed_reg, captured_seed_reg;
    reg [3:0] test_control_reg;
    reg [7:0] result_address_reg, result_count_reg, scrub_index_reg;
    reg receiver_complete_reg, receiver_owned_reg, receiver_scrub_reg, discard_seen_reg;
    reg status_ack_reg;
    reg [63:0] cycles_reg;
    reg [31:0] receiver_data_reg [0:128];
    reg [11:0] receiver_meta_reg [0:128];
    wire [7:0] read_address, write_address;
    reg [31:0] read_data;
    wire [31:0] write_data;
    wire write_valid;
    wire source_ready, source_valid, source_failed, source_word_ready;
    wire [31:0] source_data;
    wire core_ready, core_generation_ready, core_result_valid, core_result_ready;
    wire [31:0] core_result_data, core_result_id, core_status_id;
    wire [2:0] core_component;
    wire [6:0] core_index;
    wire core_component_last, core_last, core_ownership_ready, core_discard, core_status_valid;
    wire [3:0] core_status;
    wire ownership_valid = receiver_complete_reg && !receiver_owned_reg && !test_control_reg[2];
    wire acknowledge = write_valid && write_address==2 && write_data[1] && core_status_valid;
    reg source_run_reg;
    // A single registered request drives async clear; binary state decode may glitch.
    wire source_reset_n = reset_n_i && source_run_reg;
    wire busy = state_reg==SOURCE_START || state_reg==CORE_START || (state_reg==RUN && !core_status_valid);
`ifdef KEYGEN_ALTERA
    localparam [31:0] CONFIG = 32'd6 + RSA_SOFTCORE;
`else
    localparam [31:0] CONFIG = 32'd4 + RSA_SOFTCORE;
`endif
    assign source_word_ready = core_generation_ready && !test_control_reg[0];
    assign core_result_ready = !receiver_scrub_reg && !receiver_complete_reg &&
        !test_control_reg[1] && result_count_reg < 129;
    assign interrupt_n_o = !(reset_n_i && core_status_valid);
    keygen_demo_spi transport (
        .clock_i(clock_i),.reset_n_i(reset_n_i),.spi_clock_i(spi_clock_i),.spi_cs_n_i(spi_cs_n_i),
        .spi_mosi_i(spi_mosi_i),.spi_miso_o(spi_miso_o),.read_address_o(read_address),.read_data_i(read_data),
        .write_valid_o(write_valid),.write_address_o(write_address),.write_data_o(write_data)
    );
    keygen_test_source source (
        .clock_i(clock_i),.reset_n_i(source_reset_n),.start_valid_i(state_reg==SOURCE_START),
        .start_ready_o(source_ready),.seed_i(captured_seed_reg),.word_valid_o(source_valid),
        .word_ready_i(source_word_ready),.data_o(source_data),.failed_o(source_failed)
    );
    keygen_core #(.RSA_SOFTCORE(RSA_SOFTCORE),.ROM_FILE(ROM_FILE)) core (
        .clock_i(clock_i),.reset_n_i(reset_n_i),.peers_ready_i(!receiver_scrub_reg),
        .request_valid_i(state_reg==CORE_START),.request_ready_o(core_ready),
        .request_profile_i(captured_profile_reg),.request_id_i(captured_id_reg),
        .generation_valid_i(source_valid && !test_control_reg[0]),.generation_ready_o(core_generation_ready),
        .generation_data_i(source_data),.generation_failed_i(source_failed || test_control_reg[3]),
        .result_valid_o(core_result_valid),.result_ready_i(core_result_ready),.result_data_o(core_result_data),
        .result_component_o(core_component),.result_index_o(core_index),
        .result_component_last_o(core_component_last),.result_last_o(core_last),.result_id_o(core_result_id),
        .ownership_valid_i(ownership_valid),.ownership_ready_o(core_ownership_ready),.ownership_accept_i(1'b1),
        .result_discard_o(core_discard),.status_valid_o(core_status_valid),.status_ready_i(status_ack_reg),
        .status_code_o(core_status),.status_id_o(core_status_id)
    );
    always @* begin
        read_data = 0;
        case (read_address)
            0: read_data = 32'h4b473031;
            1: read_data = CONFIG;
            3: read_data = {20'b0,core_status,4'b0,core_status_valid,receiver_complete_reg,busy,
                           (state_reg==IDLE && core_ready && !receiver_scrub_reg)};
            4: read_data = {30'b0,profile_reg};
            5: read_data = id_reg;
            6: read_data = cycles_reg[31:0];
            7: read_data = cycles_reg[63:32];
            8: read_data = {24'b0,result_address_reg};
            9: if (receiver_complete_reg && result_address_reg < result_count_reg)
                read_data = receiver_data_reg[result_address_reg];
            10: if (receiver_complete_reg && result_address_reg < result_count_reg)
                read_data = {1'b1,19'b0,receiver_meta_reg[result_address_reg]};
            11: read_data = {28'b0,test_control_reg};
            12: read_data = {25'b0,receiver_scrub_reg,receiver_owned_reg,core_ownership_ready,core_result_valid,state_reg};
            13: read_data = temperatures_i;
            14: read_data = {16'b0,fan_status_i[15:0]};
            15: read_data = {16'b0,fan_status_i[31:16]};
            16,17,18,19,20,21,22,23: read_data = seed_reg[255-(read_address-16)*32 -: 32];
            24,25,26,27,28,29,30,31: read_data = BUILD_FINGERPRINT[255-(read_address-24)*32 -: 32];
            63: read_data = scratch_reg;
            default: read_data = 0;
        endcase
    end
    always @(posedge clock_i or negedge reset_n_i) begin
        if (!reset_n_i) begin
            state_reg<=SCRUB; profile_reg<=0;captured_profile_reg<=0;id_reg<=0;captured_id_reg<=0;
            seed_reg<=0;captured_seed_reg<=0;scratch_reg<=0;test_control_reg<=0;result_address_reg<=0;
            result_count_reg<=0;scrub_index_reg<=0;receiver_complete_reg<=0;receiver_owned_reg<=0;
            receiver_scrub_reg<=1;discard_seen_reg<=0;status_ack_reg<=0;cycles_reg<=0;
            source_run_reg<=0;
        end else begin
            status_ack_reg<=0;
            if (write_valid) begin
                case (write_address)
                    4: profile_reg <= write_data<=3 ? write_data[1:0] : 2'd3;
                    5: id_reg<=write_data;
                    8: if (write_data<129) result_address_reg<=write_data[7:0];
                    11: test_control_reg<=write_data[3:0];
                    16,17,18,19,20,21,22,23: seed_reg[255-(write_address-16)*32 -: 32]<=write_data;
                    63: scratch_reg<=write_data;
                    default: begin end
                endcase
            end
            if (acknowledge || (core_discard && !discard_seen_reg)) begin
                receiver_scrub_reg<=1;scrub_index_reg<=0;receiver_complete_reg<=0;receiver_owned_reg<=0;
                result_count_reg<=0;discard_seen_reg<=1;
            end else if (receiver_scrub_reg) begin
                receiver_data_reg[scrub_index_reg]<=0;receiver_meta_reg[scrub_index_reg]<=0;
                if (scrub_index_reg==128) begin receiver_scrub_reg<=0;scrub_index_reg<=0;end
                else scrub_index_reg<=scrub_index_reg+1'b1;
            end else if (core_result_valid && core_result_ready) begin
                receiver_data_reg[result_count_reg]<=core_result_data;
                receiver_meta_reg[result_count_reg]<={core_last,core_component_last,core_index,core_component};
                result_count_reg<=result_count_reg+1'b1;
                if (core_last) receiver_complete_reg<=1;
            end
            if (ownership_valid && core_ownership_ready) receiver_owned_reg<=1;
            if (acknowledge) begin
                source_run_reg<=0;
                status_ack_reg<=1;state_reg<=SCRUB;captured_seed_reg<=0;captured_id_reg<=0;captured_profile_reg<=0;
            end else case (state_reg)
                SCRUB: begin source_run_reg<=0;if (!receiver_scrub_reg) state_reg<=IDLE;end
                IDLE: if (write_valid && write_address==2 && write_data[0] && core_ready && !receiver_scrub_reg) begin
                    captured_seed_reg<=seed_reg;captured_id_reg<=id_reg;captured_profile_reg<=profile_reg;
                    receiver_complete_reg<=0;receiver_owned_reg<=0;discard_seen_reg<=0;result_count_reg<=0;
                    cycles_reg<=0;state_reg<=SOURCE_START;source_run_reg<=1;
                end
                SOURCE_START: if (source_ready) state_reg<=CORE_START;
                CORE_START: if (core_ready) begin cycles_reg<=0;state_reg<=RUN;end
                RUN: if (!core_status_valid) cycles_reg<=cycles_reg+1'b1;
                default: begin state_reg<=SCRUB;source_run_reg<=0;end
            endcase
        end
    end
endmodule
