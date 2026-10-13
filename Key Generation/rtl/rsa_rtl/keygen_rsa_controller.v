// Dedicated sequencing of RSA-2048-v1-trial251. Operands stay inside services.
module keygen_rsa_controller #(
    parameter [25:0] WATCHDOG_CYCLES=26'd50000000
) (
    input wire clock_i, input wire reset_n_i,
    input wire work_valid_i, output wire work_ready_o,
    output wire completion_valid_o, input wire completion_ready_i,
    output wire [7:0] completion_status_o,
    output wire cmd_valid_o, input wire cmd_ready_i,
    output reg [7:0] cmd_op_o,
    output reg [31:0] cmd_arg0_o, cmd_arg1_o, cmd_arg2_o, cmd_arg3_o,
    input wire rsp_valid_i, output wire rsp_ready_o, input wire [7:0] rsp_status_i
);
    localparam [2:0] IDLE=0,SEND=1,WAIT_RESPONSE=2,REJECT=3,COMPLETE=4;
    localparam [3:0] DRAW=0,PREPARE=1,SETUP=2,WITNESS_DRAW=3,WITNESS_CHECK=4,
        EXPONENTIATE=5,CHECK_ROUND=6,SQUARE=7,COPY_SQUARE=8,COPY_PRIME=9,CHECK_PAIR=10;
    reg [2:0] state_reg;
    reg [3:0] phase_reg;
    reg q_phase_reg, first_check_reg;
    reg [2:0] round_reg;
    reg [14:0] failures_reg;
    reg [25:0] watchdog_reg;
    reg [7:0] completion_status_reg;
    assign work_ready_o=reset_n_i && state_reg==IDLE;
    assign completion_valid_o=reset_n_i && state_reg==COMPLETE;
    assign completion_status_o=completion_valid_o ? completion_status_reg : 8'd0;
    assign cmd_valid_o=reset_n_i && state_reg==SEND;
    assign rsp_ready_o=reset_n_i && state_reg==WAIT_RESPONSE;

    always @* begin
        cmd_op_o=0;cmd_arg0_o=0;cmd_arg1_o=0;cmd_arg2_o=0;cmd_arg3_o=0;
        case(phase_reg)
            DRAW: begin cmd_op_o=8'h30;cmd_arg1_o=32;cmd_arg2_o=1;end
            PREPARE: begin cmd_op_o=8'h31;cmd_arg1_o=32;cmd_arg2_o=64;cmd_arg3_o={31'd0,q_phase_reg};end
            SETUP: begin cmd_op_o=8'h11;cmd_arg1_o=512;cmd_arg2_o=32;end
            WITNESS_DRAW: begin cmd_op_o=8'h30;cmd_arg0_o=96;cmd_arg1_o=32;end
            WITNESS_CHECK: begin cmd_op_o=8'h32;cmd_arg0_o=96;end
            EXPONENTIATE: begin cmd_op_o=8'h13;cmd_arg0_o=128;cmd_arg1_o=96;cmd_arg2_o=64;cmd_arg3_o=32;end
            CHECK_ROUND: begin cmd_op_o=8'h33;cmd_arg0_o={31'd0,first_check_reg};end
            SQUARE: begin cmd_op_o=8'h13;cmd_arg0_o=352;cmd_arg1_o=128;cmd_arg2_o=320;cmd_arg3_o=1;end
            COPY_SQUARE: begin cmd_op_o=8'h01;cmd_arg0_o=128;cmd_arg1_o=352;cmd_arg3_o=32;end
            COPY_PRIME: begin cmd_op_o=8'h01;cmd_arg0_o=q_phase_reg ? 192:160;cmd_arg3_o=32;end
            CHECK_PAIR: begin cmd_op_o=8'h34;end
        endcase
    end

    always @(posedge clock_i or negedge reset_n_i) begin
        if(!reset_n_i) begin
            state_reg<=IDLE;phase_reg<=DRAW;q_phase_reg<=0;first_check_reg<=0;
            round_reg<=0;failures_reg<=0;watchdog_reg<=0;completion_status_reg<=0;
        end else case(state_reg)
            IDLE: if(work_valid_i) begin
                q_phase_reg<=0;failures_reg<=0;round_reg<=0;phase_reg<=DRAW;
                completion_status_reg<=0;watchdog_reg<=0;state_reg<=SEND;
            end
            SEND: begin
                // Admission to the private accelerator is an internal link.
                // Only an accepted DRAW may wait on an external producer.
                if(cmd_ready_i) begin state_reg<=WAIT_RESPONSE;watchdog_reg<=0;end
                else if(watchdog_reg==WATCHDOG_CYCLES-1'b1) begin
                    completion_status_reg<=7;state_reg<=COMPLETE;
                end else watchdog_reg<=watchdog_reg+1'b1;
            end
            WAIT_RESPONSE: begin
                // DRAW may wait indefinitely for an external source. Other
                // commands have no external stalls and must make bounded progress.
                if(phase_reg!=DRAW && phase_reg!=WITNESS_DRAW) watchdog_reg<=watchdog_reg+1'b1;
                if(rsp_valid_i) begin
                    state_reg<=SEND;watchdog_reg<=0;
                    case(phase_reg)
                        DRAW,WITNESS_DRAW: begin
                            if(rsp_status_i!=0) begin completion_status_reg<=2;state_reg<=COMPLETE;end
                            else phase_reg<=(phase_reg==DRAW) ? PREPARE : WITNESS_CHECK;
                        end
                        PREPARE: begin
                            if(rsp_status_i==0) begin phase_reg<=SETUP;round_reg<=0;end
                            else if(rsp_status_i==8'h10 || rsp_status_i==8'h11) phase_reg<=DRAW;
                            else if(rsp_status_i==8'h12) state_reg<=REJECT;
                            else begin completion_status_reg<=4;state_reg<=COMPLETE;end
                        end
                        SETUP: begin
                            if(rsp_status_i==0) phase_reg<=WITNESS_DRAW;
                            else begin completion_status_reg<=4;state_reg<=COMPLETE;end
                        end
                        WITNESS_CHECK: begin
                            if(rsp_status_i==0) phase_reg<=EXPONENTIATE;
                            else if(rsp_status_i==8'h10) phase_reg<=WITNESS_DRAW;
                            else begin completion_status_reg<=4;state_reg<=COMPLETE;end
                        end
                        EXPONENTIATE: begin
                            if(rsp_status_i==0) begin phase_reg<=CHECK_ROUND;first_check_reg<=1;end
                            else begin completion_status_reg<=4;state_reg<=COMPLETE;end
                        end
                        CHECK_ROUND: begin
                            if(rsp_status_i==0) begin
                                if(round_reg==4) phase_reg<=COPY_PRIME;
                                else begin round_reg<=round_reg+1'b1;phase_reg<=WITNESS_DRAW;end
                            end else if(rsp_status_i==8'h10) phase_reg<=SQUARE;
                            else if(rsp_status_i==8'h11) state_reg<=REJECT;
                            else begin completion_status_reg<=4;state_reg<=COMPLETE;end
                        end
                        SQUARE: begin
                            if(rsp_status_i==0) phase_reg<=COPY_SQUARE;
                            else begin completion_status_reg<=4;state_reg<=COMPLETE;end
                        end
                        COPY_SQUARE: begin
                            if(rsp_status_i==0) begin phase_reg<=CHECK_ROUND;first_check_reg<=0;end
                            else begin completion_status_reg<=4;state_reg<=COMPLETE;end
                        end
                        COPY_PRIME: begin
                            if(rsp_status_i!=0) begin completion_status_reg<=4;state_reg<=COMPLETE;end
                            else if(!q_phase_reg) begin q_phase_reg<=1;failures_reg<=0;phase_reg<=DRAW;end
                            else phase_reg<=CHECK_PAIR;
                        end
                        CHECK_PAIR: begin
                            if(rsp_status_i==0) begin completion_status_reg<=0;state_reg<=COMPLETE;end
                            else if(rsp_status_i==8'h10) begin q_phase_reg<=0;failures_reg<=0;round_reg<=0;phase_reg<=DRAW;end
                            else begin completion_status_reg<=4;state_reg<=COMPLETE;end
                        end
                        default: begin completion_status_reg<=4;state_reg<=COMPLETE;end
                    endcase
                end else if(watchdog_reg==WATCHDOG_CYCLES-1'b1) begin completion_status_reg<=7;state_reg<=COMPLETE;end
            end
            REJECT: begin
                if(failures_reg==(q_phase_reg ? 15'd20479 : 15'd10239)) begin completion_status_reg<=3;state_reg<=COMPLETE;end
                else begin failures_reg<=failures_reg+1'b1;phase_reg<=DRAW;state_reg<=SEND;end
            end
            COMPLETE: if(completion_ready_i) state_reg<=IDLE;
            default: begin completion_status_reg<=4;state_reg<=COMPLETE;end
        endcase
    end
endmodule
