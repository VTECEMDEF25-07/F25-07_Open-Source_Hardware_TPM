// Shared protected arithmetic/services fabric for either RSA controller.
module keygen_rsa_engine (
    input wire clock_i, input wire reset_n_i, output wire ready_o,
    input wire cmd_valid_i, output wire cmd_ready_o,
    input wire [7:0] cmd_op_i,
    input wire [31:0] cmd_arg0_i,cmd_arg1_i,cmd_arg2_i,cmd_arg3_i,
    output wire rsp_valid_o,input wire rsp_ready_i,output wire [7:0] rsp_status_o,
    input wire generation_valid_i,output wire generation_ready_o,
    input wire [31:0] generation_data_i,input wire generation_failed_i,
    input wire mem_read_en_i,input wire [11:0] mem_address_i,
    output wire mem_ready_o,output wire mem_read_valid_o,output wire [31:0] mem_read_data_o
);
    reg [1:0] target_reg;
    wire service_select=(cmd_op_i>=8'h30 && cmd_op_i<=8'h34);
    wire math_cmd_ready,math_rsp_valid,service_cmd_ready,service_rsp_valid;
    wire [7:0] math_rsp_status,service_rsp_status;
    wire private_ready,private_read_valid;
    wire [31:0] private_read_data,service_write_data;
    wire service_write_en,service_read_en;
    wire [11:0] service_address;
    wire pair_start_valid,pair_start_ready,pair_result_valid,pair_result_ready;
    wire [1023:0] pair_p,pair_q;
    wire [2047:0] pair_n;
    wire [3:0] pair_status;
    assign ready_o=reset_n_i && target_reg==0 && math_cmd_ready && service_cmd_ready;
    assign cmd_ready_o=ready_o && (service_select ? private_ready : math_cmd_ready);
    assign rsp_valid_o=reset_n_i && ((target_reg==1 && math_rsp_valid) || (target_reg==2 && service_rsp_valid));
    assign rsp_status_o=(target_reg==1) ? math_rsp_status : service_rsp_status;
    assign mem_ready_o=reset_n_i && target_reg==0 && !cmd_valid_i && private_ready;
    assign mem_read_valid_o=reset_n_i && target_reg==0 && private_read_valid;
    assign mem_read_data_o=mem_read_valid_o ? private_read_data : 32'd0;
    always @(posedge clock_i or negedge reset_n_i) begin
        if(!reset_n_i) target_reg<=0;
        else if(cmd_valid_i && cmd_ready_o) target_reg<=service_select ? 2:1;
        else if(rsp_valid_o && rsp_ready_i) target_reg<=0;
    end
    keygen_math #(.MAX_LIMBS(32)) math (
        .clock_i(clock_i),.reset_n_i(reset_n_i),
        .cmd_valid_i(cmd_valid_i && target_reg==0 && !service_select),.cmd_ready_o(math_cmd_ready),
        .cmd_op_i(cmd_op_i),.cmd_arg0_i(cmd_arg0_i),.cmd_arg1_i(cmd_arg1_i),.cmd_arg2_i(cmd_arg2_i),.cmd_arg3_i(cmd_arg3_i),
        .rsp_valid_o(math_rsp_valid),.rsp_ready_i(rsp_ready_i && target_reg==1),.rsp_status_o(math_rsp_status),
        .mem_write_en_i(service_write_en && target_reg==2),
        .mem_read_en_i((target_reg==2) ? service_read_en : (mem_read_en_i && target_reg==0 && !cmd_valid_i)),
        .mem_address_i((target_reg==2) ? service_address : mem_address_i),
        .mem_write_data_i(service_write_data),.mem_ready_o(private_ready),
        .mem_read_valid_o(private_read_valid),.mem_read_data_o(private_read_data)
    );
    keygen_rsa_services services (
        .clock_i(clock_i),.reset_n_i(reset_n_i),
        .cmd_valid_i(cmd_valid_i && cmd_ready_o && service_select),.cmd_ready_o(service_cmd_ready),
        .cmd_op_i(cmd_op_i),.cmd_arg0_i(cmd_arg0_i),.cmd_arg1_i(cmd_arg1_i),.cmd_arg2_i(cmd_arg2_i),.cmd_arg3_i(cmd_arg3_i),
        .rsp_valid_o(service_rsp_valid),.rsp_ready_i(rsp_ready_i && target_reg==2),.rsp_status_o(service_rsp_status),
        .generation_valid_i(generation_valid_i),.generation_ready_o(generation_ready_o),
        .generation_data_i(generation_data_i),.generation_failed_i(generation_failed_i),
        .mem_write_en_o(service_write_en),.mem_read_en_o(service_read_en),.mem_address_o(service_address),
        .mem_write_data_o(service_write_data),.mem_ready_i(private_ready && target_reg==2),
        .mem_read_valid_i(private_read_valid && target_reg==2),.mem_read_data_i(private_read_data),
        .pair_start_valid_o(pair_start_valid),.pair_start_ready_i(pair_start_ready),.pair_p_o(pair_p),.pair_q_o(pair_q),
        .pair_result_valid_i(pair_result_valid),.pair_result_ready_o(pair_result_ready),.pair_n_i(pair_n),.pair_status_i(pair_status)
    );
    keygen_pair_check pair_check (
        .clock_i(clock_i),.reset_n_i(reset_n_i),.start_valid_i(pair_start_valid),.start_ready_o(pair_start_ready),
        .p_i(pair_p),.q_i(pair_q),.result_valid_o(pair_result_valid),.result_ready_i(pair_result_ready),
        .n_o(pair_n),.status_o(pair_status)
    );
endmodule
