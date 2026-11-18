// SHA-256-only, 24-PCR profile. Phase One owns admission and completion.
// PCR bytes come from the shared bank; this module only snapshots a reply.
`default_nettype none
module execution_engine_pcr (
    input wire clock_i, reset_n_i, start_i, operational_i,
    input wire [15:0] command_tag_i,
    input wire [31:0] command_code_i, command_size_i,
    output reg [11:0] command_addr_o,
    input wire [7:0] command_byte_i,
    output reg response_valid_o,
    output reg [31:0] response_code_o,
    output reg [11:0] response_length_o,
    input wire [11:0] response_addr_i,
    output reg [7:0] response_byte_o,
    output reg [4:0] pcr_read_index_o,
    input wire [255:0] pcr_read_data_i,
    input wire pcr_read_valid_i,
    input wire [31:0] pcr_update_counter_i
);
    localparam IDLE=0, WAIT_BYTE=1, READ_BYTE=2, VALIDATE=3, SCAN=4, RESPOND=5;
    reg [2:0] state;
    reg [7:0] payload [0:11];
    reg [3:0] offset;
    reg capability, has_selection, cap_empty;
    reg [23:0] requested, returned;
    reg [3:0] digest_count;
    reg [255:0] digests [0:7];
    reg [31:0] counter;
    wire [31:0] field0 = {payload[0],payload[1],payload[2],payload[3]};
    wire [31:0] field1 = {payload[4],payload[5],payload[6],payload[7]};
    wire [31:0] field2 = {payload[8],payload[9],payload[10],payload[11]};
    integer i, digest_offset, digest_number, digest_byte;

    always @* begin
        response_byte_o = 0;
        digest_offset = has_selection ? 18 : 12;
        digest_number = 0;
        digest_byte = 0;
        if (response_code_o == 0) begin
            if (capability) begin
                // moreData, capability=TPM_CAP_PCRS, TPML_PCR_SELECTION.
                case (response_addr_i)
                    0: response_byte_o = cap_empty ? 1 : 0;
                    4: response_byte_o = 5;
                    8: response_byte_o = cap_empty ? 0 : 1;
                    10: response_byte_o = 8'h0b;
                    11: response_byte_o = 3;
                    12,13,14: response_byte_o = 8'hff;
                    default: response_byte_o = 0;
                endcase
            end else if (response_addr_i < 4)
                response_byte_o = counter[31-response_addr_i*8 -:8];
            else if (response_addr_i == 7)
                response_byte_o = has_selection ? 1 : 0;
            else if (has_selection && response_addr_i >= 8 && response_addr_i < 14) begin
                case (response_addr_i)
                    9: response_byte_o = 8'h0b;
                    10: response_byte_o = 3;
                    11: response_byte_o = returned[7:0];
                    12: response_byte_o = returned[15:8];
                    13: response_byte_o = returned[23:16];
                    default: response_byte_o = 0;
                endcase
            end else if (response_addr_i == digest_offset-1)
                response_byte_o = {4'd0,digest_count};
            else if (response_addr_i >= digest_offset &&
                     response_addr_i < digest_offset + digest_count*34) begin
                digest_number = (response_addr_i-digest_offset)/34;
                digest_byte = (response_addr_i-digest_offset)%34;
                if (digest_byte == 1) response_byte_o = 32;
                else if (digest_byte >= 2)
                    response_byte_o = digests[digest_number][255-(digest_byte-2)*8 -:8];
            end
        end
    end

    always @(posedge clock_i or negedge reset_n_i) begin
        if (!reset_n_i) begin
            state <= IDLE; command_addr_o <= 0; offset <= 0;
            response_valid_o <= 0; response_code_o <= 0; response_length_o <= 10;
            capability <= 0; has_selection <= 0; cap_empty <= 0;
            requested <= 0; returned <= 0; digest_count <= 0; counter <= 0;
            pcr_read_index_o <= 0;
            for (i=0;i<12;i=i+1) payload[i] <= 0;
            for (i=0;i<8;i=i+1) digests[i] <= 0;
        end else begin
            response_valid_o <= 0;
            case (state)
                IDLE: if (start_i) begin
                    response_code_o <= 0; response_length_o <= 10;
                    capability <= command_code_i == 32'h17a;
                    has_selection <= 0; cap_empty <= 0; requested <= 0;
                    returned <= 0; digest_count <= 0; counter <= 0;
                    for (i=0;i<12;i=i+1) payload[i] <= 0;
                    for (i=0;i<8;i=i+1) digests[i] <= 0;
                    if (command_tag_i != 16'h8001 && command_tag_i != 16'h8002) begin
                        response_code_o <= 32'h1e; state <= RESPOND;
                    end else if (!operational_i) begin
                        response_code_o <= 32'h100; state <= RESPOND;
                    end else if (command_tag_i != 16'h8001) begin
                        // These no-handle read commands accept no authorization sessions.
                        response_code_o <= 32'h145; state <= RESPOND;
                    end else if ((command_code_i == 32'h17a && command_size_i != 22) ||
                        (command_code_i == 32'h17e && (command_size_i < 14 || command_size_i > 20))) begin
                        response_code_o <= 32'h142; state <= RESPOND;
                    end else begin
                        command_addr_o <= 10; offset <= 0; state <= WAIT_BYTE;
                    end
                end
                WAIT_BYTE: state <= READ_BYTE;
                READ_BYTE: begin
                    payload[offset] <= command_byte_i;
                    if (command_addr_o == command_size_i-1) state <= VALIDATE;
                    else begin
                        offset <= offset+1'b1;
                        command_addr_o <= command_addr_o+1'b1;
                        state <= WAIT_BYTE;
                    end
                end
                VALIDATE: begin
                    state <= RESPOND;
                    if (capability) begin
                        if (field0 != 5) response_code_o <= 32'h1c4;
                        else if (field1 != 0) response_code_o <= 32'h2c4;
                        else begin
                            cap_empty <= field2 == 0;
                            response_length_o <= field2 == 0 ? 19 : 25;
                        end
                    end else if (field0 > 1) response_code_o <= 32'h1d5;
                    else if ((field0 == 0 && command_size_i != 14) ||
                             (field0 == 1 && command_size_i != 20)) response_code_o <= 32'h142;
                    else if (field0 == 1 && {payload[4],payload[5]} != 16'h000b)
                        response_code_o <= 32'h1c3;
                    else if (field0 == 1 && payload[6] != 3) response_code_o <= 32'h1d5;
                    else begin
                        has_selection <= field0 == 1;
                        requested <= field0 == 1 ? {payload[9],payload[8],payload[7]} : 24'd0;
                        counter <= pcr_update_counter_i;
                        pcr_read_index_o <= 0;
                        state <= SCAN;
                    end
                end
                SCAN: begin
                    // Retry if a backend write overlaps the snapshot. The returned
                    // counter and all digests therefore describe one bank generation.
                    if (counter != pcr_update_counter_i) begin
                        counter <= pcr_update_counter_i;
                        returned <= 0; digest_count <= 0; pcr_read_index_o <= 0;
                    end else if (requested[pcr_read_index_o] && digest_count < 8 && !pcr_read_valid_i) begin
                        response_code_o <= 32'h101; state <= RESPOND;
                    end else begin
                        if (requested[pcr_read_index_o] && digest_count < 8) begin
                            returned[pcr_read_index_o] <= 1;
                            digests[digest_count] <= pcr_read_data_i;
                            digest_count <= digest_count+1'b1;
                        end
                        if (pcr_read_index_o == 23) begin
                            state <= RESPOND;
                            response_length_o <= (has_selection ? 28 : 22) +
                                (digest_count + ((requested[23] && digest_count < 8) ? 1 : 0))*34;
                        end else pcr_read_index_o <= pcr_read_index_o+1'b1;
                    end
                end
                RESPOND: begin response_valid_o <= 1; state <= IDLE; end
                default: state <= IDLE;
            endcase
        end
    end
endmodule
`default_nettype wire
