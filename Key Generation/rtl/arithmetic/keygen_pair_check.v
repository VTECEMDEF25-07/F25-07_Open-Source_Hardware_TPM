// RSA pair validation with 32-bit arithmetic and 2 KiB private RAM.
// Primality is checked by the caller. RAM and multiplier scrub before handoff.
module keygen_pair_check (
    input clock_i, input reset_n_i,
    input start_valid_i, output start_ready_o,
    input [1023:0] p_i, input [1023:0] q_i,
    output result_valid_o, input result_ready_i,
    output [2047:0] n_o, output [3:0] status_o
);
    localparam [7:0] CLEAR=0,CLEAR_READ=1,CLEAR_WAIT=2,IDLE=3,LOAD_INPUT=4,
        BOUND_P=5,BOUND_Q=6,BOUND_ORDER=7,BOUND_DIFFERENCE=8,BOUND_DISTANCE=9,
        PRODUCT_DONE=10,PHI_U=11,PHI_V=12,PHI_PRODUCT=13,GCD_COMPARE=14,
        GCD_DECIDE=15,GCD_BOTH=16,GCD_SHIFT_U=17,GCD_SHIFT_V=18,
        GCD_ALIGN=19,GCD_ALIGN_NEXT=20,DIV_START=21,DIV_SHIFT_R=22,
        DIV_COMPARE=23,DIV_DECIDE=24,DIV_ONE=25,DIV_ADVANCE_ONE=26,
        DIV_CHECK=27,DIV_REMAINDER=28,DIV_LAMBDA=29,FIND_K=30,
        SCALAR_READ=31,SCALAR_WAIT=32,SCALAR_WRITE=33,SCALAR_CARRY=34,
        D_READ=35,D_WAIT=36,D_BITS=37,D_WRITE=38,D_CHECK=39,D_COMPARE=40,
        D_BOUND=41,OUTPUT_READ=42,OUTPUT_WAIT=43,RESULT=44,
        MUL_A_READ=45,MUL_A_WAIT=46,MUL_B_READ=47,MUL_B_WAIT=48,
        MUL_N_READ=49,MUL_N_WAIT=50,MUL_ISSUE=51,MUL_WAIT=52,
        MUL_WRITE=53,MUL_CARRY=54,U_A_READ=60,U_A_WAIT=61,
        U_B_READ=62,U_B_WAIT=63,U_EXEC=64,U_STORE=65;
    localparam [3:0] VALID=0,BAD_PAIR=1,LOW_D=2,ARITHMETIC=3;
    localparam [3:0] COPY=0,ZERO=1,ADD=2,SUB=3,COMPARE=4,SHIFT_LEFT=5,SHIFT_RIGHT=6,OR_WORD=7;
    localparam [2:0] MEMORY=0,CONST_ZERO=1,CONST_ONE=2,CONST_LOWER=3,CONST_SEPARATION=4,CONST_D_BOUND=5;
    localparam [1:0] LESS=0,EQUAL=1,GREATER=2;
    localparam [8:0] P=0,Q=32,U=64,V=96,N=128,LAMBDA=192,REMAINDER=256,D=320;
    localparam [1023:0] LOWER_BOUND=1024'hb504f333f9de6484597d89b3754abe9f1d6f60ba893ba84ced17ac85833399154afc83043ab8a2c3a8b1fe6fdc83db390f74a85e439c7b4a780487363dfa2768d2202e8742af1f4e53059c6011bc337bcab1bc911688458a460abc722f7c4e33c6d5a8a38bb7e9dccb2a634331f3c84df52f120f836e582eeaa4a0899040ca4b;
    reg [7:0] state_reg, return_reg, multiply_return_reg;
    reg [3:0] status_reg, operation_reg;
    reg [2:0] constant_reg;
    reg [8:0] clear_address_reg, destination_reg, source_a_reg, source_b_reg;
    reg [8:0] multiply_a_reg,multiply_b_reg,multiply_n_reg;
    reg [6:0] index_reg,length_reg,b_length_reg;
    reg [4:0] row_reg,column_reg,word_bit_reg;
    reg [10:0] common_shift_reg;
    reg [11:0] division_count_reg;
    reg [1:0] comparison_reg;
    reg carry_bit_reg,low_a_reg,low_b_reg,parity_bad_reg;
    reg clear_result_reg,scalar_reg,d_high_reg;
    reg [31:0] a_reg,b_reg,result_reg,carry_reg,mult_left_reg,mult_right_reg,accumulator_reg;
    reg [16:0] lambda_residue_reg,k_reg,k_residue_reg,d_remainder_reg;
    // Capture both inputs on the handshake, then reuse this register for public n.
    reg [2047:0] n_reg;
    reg ram_read_en,ram_write_en;
    reg [8:0] ram_read_address,ram_write_address;
    reg [31:0] ram_write_data;
    wire [31:0] ram_read_data;
    wire mult_valid;
    wire [63:0] mult_product;
    wire [63:0] product_sum=mult_product+{32'b0,carry_reg}+(scalar_reg?64'd0:{32'b0,accumulator_reg});
    wire [32:0] sum_word={1'b0,a_reg}+{1'b0,b_reg}+{32'b0,carry_bit_reg};
    wire [32:0] difference_word={1'b0,a_reg}-{1'b0,b_reg}-{32'b0,carry_bit_reg};
    wire [17:0] d_trial={d_remainder_reg,a_reg[31]};
    wire d_bit=d_trial>=18'd65537;
    // A registered clear request avoids glitches from binary state decoding.
    reg multiplier_clear_reg;
    wire multiplier_reset_n=reset_n_i && !multiplier_clear_reg;
    wire [8:0] product_address=multiply_n_reg+{4'd0,row_reg}+{4'd0,column_reg};

    function [16:0] reduce_65537;
        input [17:0] value;
        reg [17:0] reduced;
        begin reduced=(value>=18'd65537)?value-18'd65537:value;reduce_65537=reduced[16:0];end
    endfunction
    function [31:0] constant_word;
        input [2:0] kind;
        input [6:0] index;
        begin
            case(kind)
                CONST_ONE: constant_word=(index==0)?32'd1:32'd0;
                CONST_LOWER: constant_word=(index<32)?LOWER_BOUND[index*32 +:32]:32'd0;
                CONST_SEPARATION: constant_word=(index==28)?32'h10000000:32'd0;
                CONST_D_BOUND: constant_word=(index==32)?32'd1:32'd0;
                default: constant_word=0;
            endcase
        end
    endfunction
    task operation;
        input [3:0] op;
        input [8:0] dst,src_a,src_b;
        input [6:0] words,b_words;
        input [2:0] kind;
        input initial_carry;
        input [7:0] next_state;
        begin
            operation_reg<=op;destination_reg<=dst;source_a_reg<=src_a;source_b_reg<=src_b;
            length_reg<=words;b_length_reg<=b_words;constant_reg<=kind;carry_bit_reg<=initial_carry;
            index_reg<=(op==SHIFT_RIGHT)?words-1'b1:7'd0;
            comparison_reg<=EQUAL;return_reg<=next_state;state_reg<=U_A_READ;
        end
    endtask
    task multiply;
        input [8:0] left,right,destination;
        input [7:0] next_state;
        begin
            multiply_a_reg<=left;multiply_b_reg<=right;multiply_n_reg<=destination;
            multiply_return_reg<=next_state;row_reg<=0;column_reg<=0;carry_reg<=0;
            scalar_reg<=0;state_reg<=MUL_A_READ;
        end
    endtask
    task finish;
        input [3:0] status;
        begin
            status_reg<=status;clear_result_reg<=1;clear_address_reg<=0;state_reg<=CLEAR;multiplier_clear_reg<=1;
            if(status!=VALID)n_reg<=0;
        end
    endtask
    task advance_division;
        input quotient_bit;
        begin
            lambda_residue_reg<=reduce_65537({lambda_residue_reg,quotient_bit});
            division_count_reg<=division_count_reg-1'b1;
            if(division_count_reg==1)state_reg<=DIV_CHECK;
            else operation(SHIFT_LEFT,LAMBDA,LAMBDA,0,64,0,CONST_ZERO,0,DIV_SHIFT_R);
        end
    endtask

    assign start_ready_o=reset_n_i && state_reg==IDLE;
    assign result_valid_o=reset_n_i && state_reg==RESULT;
    assign n_o=result_valid_o && status_reg==VALID?n_reg:2048'd0;
    assign status_o=result_valid_o?status_reg:4'd0;
    keygen_ram32 #(.ADDRESS_WIDTH(9)) private_ram(
        .clock_i(clock_i),.reset_n_i(reset_n_i),.clock_en_i(1'b1),
        .write_en_i(ram_write_en),.write_address_i(ram_write_address),.write_data_i(ram_write_data),
        .read_en_i(ram_read_en),.read_address_i(ram_read_address),.read_valid_o(),.read_data_o(ram_read_data)
    );
    keygen_mult32 multiplier(
        .clock_i(clock_i),.reset_n_i(multiplier_reset_n),.clock_en_i(1'b1),
        .valid_i(state_reg==MUL_ISSUE),.left_i(mult_left_reg),.right_i(mult_right_reg),
        .valid_o(mult_valid),.product_o(mult_product)
    );
    always @* begin
        ram_read_en=0;ram_write_en=0;ram_read_address=0;ram_write_address=0;ram_write_data=0;
        case(state_reg)
            CLEAR: begin ram_write_en=1;ram_write_address=clear_address_reg;end
            CLEAR_READ: begin ram_read_en=1;ram_read_address=511;end
            LOAD_INPUT: begin ram_write_en=1;ram_write_address={2'd0,index_reg};ram_write_data=n_reg[index_reg*32 +:32];end
            U_A_READ: begin ram_read_en=1;ram_read_address=source_a_reg+{2'd0,index_reg};end
            U_B_READ: begin ram_read_en=1;ram_read_address=source_b_reg+{2'd0,index_reg};end
            U_STORE: if(operation_reg!=COMPARE)begin ram_write_en=1;ram_write_address=destination_reg+{2'd0,index_reg};ram_write_data=result_reg;end
            MUL_A_READ: begin ram_read_en=1;ram_read_address=multiply_a_reg+{4'd0,row_reg};end
            MUL_B_READ: begin ram_read_en=1;ram_read_address=multiply_b_reg+{4'd0,column_reg};end
            MUL_N_READ: begin ram_read_en=1;ram_read_address=product_address;end
            MUL_WRITE: begin ram_write_en=1;ram_write_address=product_address;ram_write_data=result_reg;end
            MUL_CARRY: begin ram_write_en=1;ram_write_address=multiply_n_reg+{4'd0,row_reg}+9'd32;ram_write_data=carry_reg;end
            SCALAR_READ: begin ram_read_en=1;ram_read_address=LAMBDA+{2'd0,index_reg};end
            SCALAR_WRITE: begin ram_write_en=1;ram_write_address=D+{2'd0,index_reg};ram_write_data=result_reg;end
            SCALAR_CARRY: begin ram_write_en=1;ram_write_address=D+9'd64;ram_write_data=carry_reg;end
            D_READ: begin ram_read_en=1;ram_read_address=D+{2'd0,index_reg};end
            D_WRITE: begin ram_write_en=1;ram_write_address=D+{2'd0,index_reg};ram_write_data=a_reg;end
            OUTPUT_READ: begin ram_read_en=1;ram_read_address=N+{2'd0,index_reg};end
            default: begin end
        endcase
        if(!reset_n_i)begin ram_read_en=0;ram_write_en=0;end
    end
    always @(posedge clock_i or negedge reset_n_i) begin
        if(!reset_n_i)begin
            state_reg<=CLEAR;clear_address_reg<=0;clear_result_reg<=0;n_reg<=0;status_reg<=0;multiplier_clear_reg<=1;
            return_reg<=0;multiply_return_reg<=0;operation_reg<=0;constant_reg<=0;
            destination_reg<=0;source_a_reg<=0;source_b_reg<=0;multiply_a_reg<=0;multiply_b_reg<=0;multiply_n_reg<=0;
            index_reg<=0;length_reg<=0;b_length_reg<=0;row_reg<=0;column_reg<=0;word_bit_reg<=0;
            common_shift_reg<=0;division_count_reg<=0;comparison_reg<=0;carry_bit_reg<=0;low_a_reg<=0;low_b_reg<=0;
            parity_bad_reg<=0;scalar_reg<=0;d_high_reg<=0;
            a_reg<=0;b_reg<=0;result_reg<=0;carry_reg<=0;mult_left_reg<=0;mult_right_reg<=0;accumulator_reg<=0;
            lambda_residue_reg<=0;k_reg<=0;k_residue_reg<=0;d_remainder_reg<=0;
        end else case(state_reg)
            CLEAR: begin
                // RAM contents are swept, never asynchronously reset. The macro
                // output latch is refreshed after the final collision-free read.
                a_reg<=0;b_reg<=0;result_reg<=0;carry_reg<=0;mult_left_reg<=0;mult_right_reg<=0;accumulator_reg<=0;
                lambda_residue_reg<=0;k_reg<=0;k_residue_reg<=0;d_remainder_reg<=0;
                common_shift_reg<=0;division_count_reg<=0;carry_bit_reg<=0;low_a_reg<=0;low_b_reg<=0;
                parity_bad_reg<=0;scalar_reg<=0;d_high_reg<=0;comparison_reg<=0;
                return_reg<=0;multiply_return_reg<=0;operation_reg<=0;constant_reg<=0;
                destination_reg<=0;source_a_reg<=0;source_b_reg<=0;multiply_a_reg<=0;multiply_b_reg<=0;multiply_n_reg<=0;
                index_reg<=0;length_reg<=0;b_length_reg<=0;row_reg<=0;column_reg<=0;word_bit_reg<=0;
                if(clear_address_reg==511)state_reg<=CLEAR_READ;
                else clear_address_reg<=clear_address_reg+1'b1;
            end
            CLEAR_READ: state_reg<=CLEAR_WAIT;
            CLEAR_WAIT: begin clear_address_reg<=0;multiplier_clear_reg<=0;state_reg<=clear_result_reg?RESULT:IDLE;end
            IDLE: if(start_valid_i)begin
                n_reg<={q_i,p_i};parity_bad_reg<=!p_i[0]||!q_i[0];status_reg<=VALID;
                index_reg<=0;state_reg<=LOAD_INPUT;
            end
            LOAD_INPUT: if(index_reg==63)begin
                n_reg<=0;
                if(parity_bad_reg)finish(BAD_PAIR);
                else operation(COMPARE,0,P,0,32,0,CONST_LOWER,0,BOUND_P);
            end else index_reg<=index_reg+1'b1;
            BOUND_P: if(comparison_reg==LESS)finish(BAD_PAIR);
                else operation(COMPARE,0,Q,0,32,0,CONST_LOWER,0,BOUND_Q);
            BOUND_Q: if(comparison_reg==LESS)finish(BAD_PAIR);
                else operation(COMPARE,0,P,Q,32,32,MEMORY,0,BOUND_ORDER);
            BOUND_ORDER: if(comparison_reg==LESS)operation(SUB,U,Q,P,32,32,MEMORY,0,BOUND_DIFFERENCE);
                else operation(SUB,U,P,Q,32,32,MEMORY,0,BOUND_DIFFERENCE);
            BOUND_DIFFERENCE: operation(COMPARE,0,U,0,32,0,CONST_SEPARATION,0,BOUND_DISTANCE);
            BOUND_DISTANCE: if(comparison_reg!=GREATER)finish(BAD_PAIR);else multiply(P,Q,N,PRODUCT_DONE);
            PRODUCT_DONE: if(!carry_reg[31])finish(ARITHMETIC);
                else operation(SUB,U,P,0,32,0,CONST_ONE,0,PHI_U);
            PHI_U: operation(SUB,V,Q,0,32,0,CONST_ONE,0,PHI_V);
            PHI_V: multiply(U,V,LAMBDA,PHI_PRODUCT);
            PHI_PRODUCT: begin common_shift_reg<=0;state_reg<=GCD_COMPARE;end
            GCD_COMPARE: operation(COMPARE,0,U,V,32,32,MEMORY,0,GCD_DECIDE);
            GCD_DECIDE: begin
                if(comparison_reg==EQUAL)state_reg<=GCD_ALIGN;
                else if(!low_a_reg && !low_b_reg)begin
                    common_shift_reg<=common_shift_reg+1'b1;
                    operation(SHIFT_RIGHT,U,U,0,32,0,CONST_ZERO,0,GCD_BOTH);
                end else if(!low_a_reg)state_reg<=GCD_SHIFT_U;
                else if(!low_b_reg)state_reg<=GCD_SHIFT_V;
                else if(comparison_reg==GREATER)operation(SUB,U,U,V,32,32,MEMORY,0,GCD_SHIFT_U);
                else operation(SUB,V,V,U,32,32,MEMORY,0,GCD_SHIFT_V);
            end
            GCD_BOTH: operation(SHIFT_RIGHT,V,V,0,32,0,CONST_ZERO,0,GCD_COMPARE);
            GCD_SHIFT_U: operation(SHIFT_RIGHT,U,U,0,32,0,CONST_ZERO,0,GCD_COMPARE);
            GCD_SHIFT_V: operation(SHIFT_RIGHT,V,V,0,32,0,CONST_ZERO,0,GCD_COMPARE);
            GCD_ALIGN: if(common_shift_reg!=0)operation(SHIFT_LEFT,U,U,0,32,0,CONST_ZERO,0,GCD_ALIGN_NEXT);
                else operation(ZERO,REMAINDER,REMAINDER,0,64,0,CONST_ZERO,0,DIV_START);
            GCD_ALIGN_NEXT: begin common_shift_reg<=common_shift_reg-1'b1;state_reg<=GCD_ALIGN;end
            DIV_START: begin
                division_count_reg<=2048;lambda_residue_reg<=0;
                operation(SHIFT_LEFT,LAMBDA,LAMBDA,0,64,0,CONST_ZERO,0,DIV_SHIFT_R);
            end
            DIV_SHIFT_R: operation(SHIFT_LEFT,REMAINDER,REMAINDER,0,64,0,CONST_ZERO,carry_bit_reg,DIV_COMPARE);
            DIV_COMPARE: operation(COMPARE,0,REMAINDER,U,64,32,MEMORY,0,DIV_DECIDE);
            DIV_DECIDE: if(comparison_reg!=LESS)operation(SUB,REMAINDER,REMAINDER,U,64,32,MEMORY,0,DIV_ONE);
                else advance_division(0);
            DIV_ONE: operation(OR_WORD,LAMBDA,LAMBDA,0,1,0,CONST_ONE,0,DIV_ADVANCE_ONE);
            DIV_ADVANCE_ONE: advance_division(1);
            DIV_CHECK: operation(COMPARE,0,REMAINDER,0,64,0,CONST_ZERO,0,DIV_REMAINDER);
            DIV_REMAINDER: if(comparison_reg!=EQUAL)finish(ARITHMETIC);
                else operation(COMPARE,0,LAMBDA,0,64,0,CONST_ZERO,0,DIV_LAMBDA);
            DIV_LAMBDA: if(comparison_reg==EQUAL)finish(ARITHMETIC);
                else if(lambda_residue_reg==0)finish(BAD_PAIR);
                else begin k_reg<=1;k_residue_reg<=lambda_residue_reg;state_reg<=FIND_K;end
            FIND_K: if(k_residue_reg==65536)begin index_reg<=0;carry_reg<=1;scalar_reg<=1;state_reg<=SCALAR_READ;end
                else if(k_reg==65536)finish(ARITHMETIC);
                else begin k_reg<=k_reg+1'b1;k_residue_reg<=reduce_65537({1'b0,k_residue_reg}+{1'b0,lambda_residue_reg});end
            SCALAR_READ: state_reg<=SCALAR_WAIT;
            SCALAR_WAIT: begin mult_left_reg<=ram_read_data;mult_right_reg<={15'd0,k_reg};state_reg<=MUL_ISSUE;end
            SCALAR_WRITE: if(index_reg==63)state_reg<=SCALAR_CARRY;
                else begin index_reg<=index_reg+1'b1;state_reg<=SCALAR_READ;end
            SCALAR_CARRY: begin index_reg<=64;d_remainder_reg<=0;d_high_reg<=0;state_reg<=D_READ;end
            D_READ: state_reg<=D_WAIT;
            D_WAIT: begin a_reg<=ram_read_data;word_bit_reg<=31;state_reg<=D_BITS;end
            D_BITS: begin
                a_reg<={a_reg[30:0],d_bit};d_remainder_reg<=reduce_65537(d_trial);
                if(word_bit_reg==0)state_reg<=D_WRITE;else word_bit_reg<=word_bit_reg-1'b1;
            end
            D_WRITE: begin
                if(index_reg==64)d_high_reg<=a_reg!=0;
                if(index_reg==0)state_reg<=D_CHECK;
                else begin index_reg<=index_reg-1'b1;state_reg<=D_READ;end
            end
            D_CHECK: if(d_high_reg || d_remainder_reg!=0)finish(ARITHMETIC);
                else operation(COMPARE,0,D,LAMBDA,64,64,MEMORY,0,D_COMPARE);
            D_COMPARE: if(comparison_reg!=LESS)finish(ARITHMETIC);
                else operation(COMPARE,0,D,0,64,0,CONST_D_BOUND,0,D_BOUND);
            D_BOUND: if(comparison_reg!=GREATER)finish(LOW_D);
                else begin index_reg<=0;state_reg<=OUTPUT_READ;end
            OUTPUT_READ: state_reg<=OUTPUT_WAIT;
            OUTPUT_WAIT: begin
                n_reg[index_reg*32 +:32]<=ram_read_data;
                if(index_reg==63)finish(VALID);
                else begin index_reg<=index_reg+1'b1;state_reg<=OUTPUT_READ;end
            end
            MUL_A_READ: state_reg<=MUL_A_WAIT;
            MUL_A_WAIT: begin mult_left_reg<=ram_read_data;state_reg<=MUL_B_READ;end
            MUL_B_READ: state_reg<=MUL_B_WAIT;
            MUL_B_WAIT: begin mult_right_reg<=ram_read_data;state_reg<=MUL_N_READ;end
            MUL_N_READ: state_reg<=MUL_N_WAIT;
            MUL_N_WAIT: begin accumulator_reg<=ram_read_data;state_reg<=MUL_ISSUE;end
            MUL_ISSUE: state_reg<=MUL_WAIT;
            MUL_WAIT: if(mult_valid)begin
                result_reg<=product_sum[31:0];carry_reg<=product_sum[63:32];
                state_reg<=scalar_reg?SCALAR_WRITE:MUL_WRITE;
            end
            MUL_WRITE: if(column_reg==31)state_reg<=MUL_CARRY;
                else begin column_reg<=column_reg+1'b1;state_reg<=MUL_A_READ;end
            MUL_CARRY: if(row_reg==31)state_reg<=multiply_return_reg;
                else begin row_reg<=row_reg+1'b1;column_reg<=0;carry_reg<=0;state_reg<=MUL_A_READ;end
            U_A_READ: state_reg<=U_A_WAIT;
            U_A_WAIT: begin
                a_reg<=ram_read_data;
                if(constant_reg==MEMORY && index_reg<b_length_reg)state_reg<=U_B_READ;
                else begin b_reg<=constant_word(constant_reg,index_reg);state_reg<=U_EXEC;end
            end
            U_B_READ: state_reg<=U_B_WAIT;
            U_B_WAIT: begin b_reg<=ram_read_data;state_reg<=U_EXEC;end
            U_EXEC: begin
                if(index_reg==0)begin low_a_reg<=a_reg[0];low_b_reg<=b_reg[0];end
                case(operation_reg)
                    COPY: result_reg<=a_reg;
                    ZERO: result_reg<=0;
                    ADD: begin result_reg<=sum_word[31:0];carry_bit_reg<=sum_word[32];end
                    SUB: begin result_reg<=difference_word[31:0];carry_bit_reg<=difference_word[32];end
                    COMPARE: begin if(a_reg>b_reg)comparison_reg<=GREATER;else if(a_reg<b_reg)comparison_reg<=LESS;end
                    SHIFT_LEFT: begin result_reg<={a_reg[30:0],carry_bit_reg};carry_bit_reg<=a_reg[31];end
                    SHIFT_RIGHT: begin result_reg<={carry_bit_reg,a_reg[31:1]};carry_bit_reg<=a_reg[0];end
                    OR_WORD: result_reg<=a_reg|b_reg;
                    default: result_reg<=0;
                endcase
                state_reg<=U_STORE;
            end
            U_STORE: if((operation_reg==SHIFT_RIGHT && index_reg==0)||(operation_reg!=SHIFT_RIGHT && index_reg==length_reg-1'b1))state_reg<=return_reg;
                else begin index_reg<=(operation_reg==SHIFT_RIGHT)?index_reg-1'b1:index_reg+1'b1;state_reg<=U_A_READ;end
            RESULT: if(result_ready_i)begin n_reg<=0;status_reg<=0;clear_result_reg<=0;state_reg<=IDLE;end
            default: finish(ARITHMETIC);
        endcase
    end
endmodule
