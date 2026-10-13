// Fixed-profile RSA services; CPU receives predicates, never private operands.
// Scratch addresses are 32-bit words. All operand accesses use the private port.
module keygen_rsa_services (
    input wire clock_i, input wire reset_n_i,
    input wire cmd_valid_i, output wire cmd_ready_o,
    input wire [7:0] cmd_op_i,
    input wire [31:0] cmd_arg0_i, cmd_arg1_i, cmd_arg2_i, cmd_arg3_i,
    output wire rsp_valid_o, input wire rsp_ready_i, output wire [7:0] rsp_status_o,
    input wire generation_valid_i, output wire generation_ready_o,
    input wire [31:0] generation_data_i, input wire generation_failed_i,
    output wire mem_write_en_o, output wire mem_read_en_o,
    output wire [11:0] mem_address_o, output wire [31:0] mem_write_data_o,
    input wire mem_ready_i, input wire mem_read_valid_i, input wire [31:0] mem_read_data_i,
    output wire pair_start_valid_o, input wire pair_start_ready_i,
    output wire [1023:0] pair_p_o, pair_q_o,
    input wire pair_result_valid_i, output wire pair_result_ready_o,
    input wire [2047:0] pair_n_i, input wire [3:0] pair_status_i
);
    localparam [4:0] IDLE=0,DRAW=1,READ_REQ=2,READ_WAIT=3,CHECK=4,
        MOD_BITS=5,FACTOR=6,WRITE_PREP=7,RESPONSE=8,PAIR_START=9,PAIR_WAIT=10,PAIR_WRITE=11;
    localparam [1023:0] LOWER_BOUND=1024'hb504f333f9de6484597d89b3754abe9f1d6f60ba893ba84ced17ac85833399154afc83043ab8a2c3a8b1fe6fdc83db390f74a85e439c7b4a780487363dfa2768d2202e8742af1f4e53059c6011bc337bcab1bc911688458a460abc722f7c4e33c6d5a8a38bb7e9dccb2a634331f3c84df52f120f836e582eeaa4a0899040ca4b;
    reg [4:0] state_reg;
    reg [7:0] op_reg, status_reg;
    reg [31:0] arg0_reg, arg1_reg, arg2_reg, arg3_reg;
    reg [6:0] index_reg;
    reg [11:0] read_base_reg;
    reg read_peer_reg;
    reg [1023:0] value_reg, peer_reg, candidate_reg, minus_one_reg, odd_part_reg;
    reg [10:0] twos_reg, square_remaining_reg;
    reg [9:0] bit_index_reg;
    reg [17:0] remainder_reg, divisor_reg;
    reg exponent_filter_reg;
    reg [5:0] prime_index_reg;
    reg [1:0] write_component_reg;
    wire [17:0] shifted_remainder;
    wire [17:0] reduced_remainder;
    wire [1023:0] difference;
    reg [31:0] write_word;
    reg [11:0] write_address;
    function [17:0] trial_prime;
        input [5:0] number;
        begin
            case(number)
            6'd0: trial_prime = 18'd3;
            6'd1: trial_prime = 18'd5;
            6'd2: trial_prime = 18'd7;
            6'd3: trial_prime = 18'd11;
            6'd4: trial_prime = 18'd13;
            6'd5: trial_prime = 18'd17;
            6'd6: trial_prime = 18'd19;
            6'd7: trial_prime = 18'd23;
            6'd8: trial_prime = 18'd29;
            6'd9: trial_prime = 18'd31;
            6'd10: trial_prime = 18'd37;
            6'd11: trial_prime = 18'd41;
            6'd12: trial_prime = 18'd43;
            6'd13: trial_prime = 18'd47;
            6'd14: trial_prime = 18'd53;
            6'd15: trial_prime = 18'd59;
            6'd16: trial_prime = 18'd61;
            6'd17: trial_prime = 18'd67;
            6'd18: trial_prime = 18'd71;
            6'd19: trial_prime = 18'd73;
            6'd20: trial_prime = 18'd79;
            6'd21: trial_prime = 18'd83;
            6'd22: trial_prime = 18'd89;
            6'd23: trial_prime = 18'd97;
            6'd24: trial_prime = 18'd101;
            6'd25: trial_prime = 18'd103;
            6'd26: trial_prime = 18'd107;
            6'd27: trial_prime = 18'd109;
            6'd28: trial_prime = 18'd113;
            6'd29: trial_prime = 18'd127;
            6'd30: trial_prime = 18'd131;
            6'd31: trial_prime = 18'd137;
            6'd32: trial_prime = 18'd139;
            6'd33: trial_prime = 18'd149;
            6'd34: trial_prime = 18'd151;
            6'd35: trial_prime = 18'd157;
            6'd36: trial_prime = 18'd163;
            6'd37: trial_prime = 18'd167;
            6'd38: trial_prime = 18'd173;
            6'd39: trial_prime = 18'd179;
            6'd40: trial_prime = 18'd181;
            6'd41: trial_prime = 18'd191;
            6'd42: trial_prime = 18'd193;
            6'd43: trial_prime = 18'd197;
            6'd44: trial_prime = 18'd199;
            6'd45: trial_prime = 18'd211;
            6'd46: trial_prime = 18'd223;
            6'd47: trial_prime = 18'd227;
            6'd48: trial_prime = 18'd229;
            6'd49: trial_prime = 18'd233;
            6'd50: trial_prime = 18'd239;
            6'd51: trial_prime = 18'd241;
            6'd52: trial_prime = 18'd251;
            default: trial_prime = 18'd251;
            endcase
        end
    endfunction
    assign cmd_ready_o = reset_n_i && (state_reg==IDLE);
    assign rsp_valid_o = reset_n_i && (state_reg==RESPONSE);
    assign rsp_status_o = rsp_valid_o ? status_reg : 8'd0;
    assign generation_ready_o = reset_n_i && (state_reg==DRAW) && mem_ready_i && !generation_failed_i;
    assign mem_read_en_o = reset_n_i && (state_reg==READ_REQ);
    assign mem_write_en_o = reset_n_i && (((state_reg==DRAW) && generation_valid_i && !generation_failed_i) ||
        state_reg==WRITE_PREP || state_reg==PAIR_WRITE);
    assign mem_address_o = (state_reg==READ_REQ) ? read_base_reg+{5'd0,index_reg} : write_address;
    assign mem_write_data_o = mem_write_en_o ? write_word : 32'd0;
    assign pair_start_valid_o = reset_n_i && state_reg==PAIR_START;
    assign pair_p_o = peer_reg;
    assign pair_q_o = value_reg;
    assign pair_result_ready_o = reset_n_i && ((state_reg==PAIR_WAIT && pair_result_valid_i && pair_status_i!=0) ||
        (state_reg==PAIR_WRITE && mem_ready_i && index_reg==63));
    assign difference = (value_reg>=peer_reg) ? value_reg-peer_reg : peer_reg-value_reg;
    assign shifted_remainder = {remainder_reg[16:0],
        (exponent_filter_reg ? minus_one_reg[bit_index_reg] : candidate_reg[bit_index_reg])};
    assign reduced_remainder = (shifted_remainder>=divisor_reg) ? shifted_remainder-divisor_reg : shifted_remainder;

    always @* begin
        write_address = 12'd0;
        write_word = 32'd0;
        if(state_reg==DRAW) begin
            write_address=arg0_reg[11:0]+12'd31-{5'd0,index_reg};
            write_word=generation_data_i | ((arg2_reg[0] && index_reg==31) ? 32'd1 : 32'd0);
        end else if(state_reg==WRITE_PREP) begin
            case(write_component_reg)
                0: begin write_address=arg1_reg[11:0]+{5'd0,index_reg}; write_word=minus_one_reg[index_reg*32 +: 32]; end
                1: begin write_address=arg2_reg[11:0]+{5'd0,index_reg}; write_word=odd_part_reg[index_reg*32 +: 32]; end
                2: begin write_address=12'd288+{5'd0,index_reg}; write_word=(index_reg==0) ? 32'd1 : 32'd0; end
                3: begin write_address=12'd320+{5'd0,index_reg}; write_word=(index_reg==0) ? 32'd2 : 32'd0; end
            endcase
        end else if(state_reg==PAIR_WRITE) begin
            write_address=12'd224+{5'd0,index_reg};
            write_word=pair_n_i[index_reg*32 +: 32];
        end
    end

    always @(posedge clock_i or negedge reset_n_i) begin
        if(!reset_n_i) begin
            state_reg<=IDLE;op_reg<=0;status_reg<=0;
            arg0_reg<=0;arg1_reg<=0;arg2_reg<=0;arg3_reg<=0;
            index_reg<=0;read_base_reg<=0;read_peer_reg<=0;
            value_reg<=0;peer_reg<=0;candidate_reg<=0;minus_one_reg<=0;odd_part_reg<=0;
            twos_reg<=0;square_remaining_reg<=0;bit_index_reg<=0;
            remainder_reg<=0;divisor_reg<=0;exponent_filter_reg<=0;prime_index_reg<=0;write_component_reg<=0;
        end else begin
            // Source failure is a service error. Outer job controller aborts and scrubs.
            if(state_reg==DRAW && generation_failed_i) begin status_reg<=8'h02;state_reg<=RESPONSE;end
            else case(state_reg)
                IDLE: if(cmd_valid_i) begin
                    op_reg<=cmd_op_i;arg0_reg<=cmd_arg0_i;arg1_reg<=cmd_arg1_i;
                    arg2_reg<=cmd_arg2_i;arg3_reg<=cmd_arg3_i;
                    index_reg<=0;status_reg<=0;read_peer_reg<=0;
                    if(cmd_op_i==8'h30) begin
                        if(cmd_arg0_i>4064 || cmd_arg1_i!=32 || cmd_arg2_i>1 || cmd_arg3_i!=0) begin
                            status_reg<=1;state_reg<=RESPONSE;
                        end else state_reg<=DRAW;
                    end else if(cmd_op_i==8'h31) begin
                        if(cmd_arg0_i!=0 || cmd_arg1_i!=32 || cmd_arg2_i!=64 || cmd_arg3_i>1) begin
                            status_reg<=1;state_reg<=RESPONSE;
                        end else begin read_base_reg<=0;state_reg<=READ_REQ;end
                    end else if(cmd_op_i==8'h32) begin
                        if(cmd_arg0_i!=96 || cmd_arg1_i!=0 || cmd_arg2_i!=0 || cmd_arg3_i!=0) begin
                            status_reg<=1;state_reg<=RESPONSE;
                        end else begin read_base_reg<=96;state_reg<=READ_REQ;end
                    end else if(cmd_op_i==8'h33) begin
                        if(cmd_arg0_i>1 || cmd_arg1_i!=0 || cmd_arg2_i!=0 || cmd_arg3_i!=0) begin
                            status_reg<=1;state_reg<=RESPONSE;
                        end else begin read_base_reg<=128;state_reg<=READ_REQ;end
                    end else if(cmd_op_i==8'h34) begin
                        if(cmd_arg0_i!=0 || cmd_arg1_i!=0 || cmd_arg2_i!=0 || cmd_arg3_i!=0) begin
                            status_reg<=1;state_reg<=RESPONSE;
                        end else begin read_base_reg<=160;read_peer_reg<=1;state_reg<=READ_REQ;end
                    end
                    else begin status_reg<=1;state_reg<=RESPONSE;end
                end
                DRAW: if(generation_valid_i && generation_ready_o) begin
                    if(index_reg==31) state_reg<=RESPONSE;
                    else index_reg<=index_reg+1'b1;
                end
                READ_REQ: if(mem_ready_i) state_reg<=READ_WAIT;
                READ_WAIT: if(mem_read_valid_i) begin
                    if(read_peer_reg) peer_reg[index_reg*32 +: 32]<=mem_read_data_i;
                    else value_reg[index_reg*32 +: 32]<=mem_read_data_i;
                    if(index_reg==31) begin
                        index_reg<=0;
                        if(op_reg==8'h34 && read_peer_reg) begin
                            read_base_reg<=192;read_peer_reg<=0;state_reg<=READ_REQ;
                        end else if(op_reg==8'h31 && arg3_reg[0] && !read_peer_reg) begin
                            read_base_reg<=160;read_peer_reg<=1;state_reg<=READ_REQ;
                        end else state_reg<=(op_reg==8'h34) ? PAIR_START : CHECK;
                    end else begin index_reg<=index_reg+1'b1;state_reg<=READ_REQ;end
                end
                CHECK: begin
                    state_reg<=RESPONSE;
                    if(op_reg==8'h31) begin
                        if(value_reg<LOWER_BOUND || !value_reg[0]) status_reg<=8'h10;
                        else if(arg3_reg[0] && difference <= (1024'd1<<924)) status_reg<=8'h11;
                        else begin
                            candidate_reg<=value_reg;minus_one_reg<=value_reg-1'b1;
                            odd_part_reg<=value_reg-1'b1;twos_reg<=0;square_remaining_reg<=0;
                            divisor_reg<=18'd65537;remainder_reg<=0;bit_index_reg<=1023;
                            exponent_filter_reg<=1;prime_index_reg<=0;state_reg<=MOD_BITS;
                        end
                    end else if(op_reg==8'h32) begin
                        if(value_reg<2 || value_reg>minus_one_reg-1'b1) status_reg<=8'h10;
                    end else if(op_reg==8'h33) begin
                        if(value_reg==minus_one_reg || (arg0_reg[0] && value_reg==1)) status_reg<=0;
                        else if(!arg0_reg[0] && value_reg==1) status_reg<=8'h11;
                        else if(arg0_reg[0]) begin
                            square_remaining_reg<=twos_reg-1'b1;
                            status_reg<=(twos_reg<=1) ? 8'h11 : 8'h10;
                        end else if(square_remaining_reg<=1) status_reg<=8'h11;
                        else begin square_remaining_reg<=square_remaining_reg-1'b1;status_reg<=8'h10;end
                    end
                end
                MOD_BITS: begin
                    remainder_reg<=reduced_remainder;
                    if(bit_index_reg==0) begin
                        if(reduced_remainder==0) begin status_reg<=8'h12;state_reg<=RESPONSE;end
                        else if(!exponent_filter_reg && prime_index_reg==52) state_reg<=FACTOR;
                        else begin
                            remainder_reg<=0;bit_index_reg<=1023;exponent_filter_reg<=0;
                            if(exponent_filter_reg) begin divisor_reg<=trial_prime(0);prime_index_reg<=0;end
                            else begin divisor_reg<=trial_prime(prime_index_reg+1'b1);prime_index_reg<=prime_index_reg+1'b1;end
                        end
                    end else bit_index_reg<=bit_index_reg-1'b1;
                end
                FACTOR: begin
                    if(!odd_part_reg[0]) begin odd_part_reg<=odd_part_reg>>1;twos_reg<=twos_reg+1'b1;end
                    else begin index_reg<=0;write_component_reg<=0;state_reg<=WRITE_PREP;end
                end
                WRITE_PREP: if(mem_ready_i) begin
                    if(index_reg==31) begin
                        index_reg<=0;
                        if(write_component_reg==3) state_reg<=RESPONSE;
                        else write_component_reg<=write_component_reg+1'b1;
                    end else index_reg<=index_reg+1'b1;
                end
                PAIR_START: if(pair_start_ready_i) state_reg<=PAIR_WAIT;
                PAIR_WAIT: if(pair_result_valid_i) begin
                    if(pair_status_i!=0) begin
                        status_reg<=(pair_status_i==2) ? 8'h10 : 8'h04;state_reg<=RESPONSE;
                    end else begin index_reg<=0;state_reg<=PAIR_WRITE;end
                end
                PAIR_WRITE: if(mem_ready_i) begin
                    if(index_reg==63) state_reg<=RESPONSE;
                    else index_reg<=index_reg+1'b1;
                end
                RESPONSE: if(rsp_ready_i) begin
                    state_reg<=IDLE;value_reg<=0;peer_reg<=0;index_reg<=0;
                end
                default: begin state_reg<=RESPONSE;status_reg<=8'h04;end
            endcase
        end
    end
endmodule

