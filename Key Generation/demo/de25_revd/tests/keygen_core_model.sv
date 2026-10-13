// Transport/receiver fixture ONLY. Never compile this model in a board image.
module keygen_core #(parameter RSA_SOFTCORE=0, parameter ROM_FILE="") (
    input clock_i,reset_n_i,peers_ready_i,request_valid_i,output request_ready_o,
    input [1:0] request_profile_i,input [31:0] request_id_i,
    input generation_valid_i,output generation_ready_o,input [31:0] generation_data_i,input generation_failed_i,
    output result_valid_o,input result_ready_i,output [31:0] result_data_o,
    output [2:0] result_component_o,output [6:0] result_index_o,output result_component_last_o,result_last_o,
    output [31:0] result_id_o,input ownership_valid_i,output ownership_ready_o,input ownership_accept_i,
    output result_discard_o,output status_valid_o,input status_ready_i,output [3:0] status_code_o,output [31:0] status_id_o
);
    reg [2:0] state_reg=0;
    reg [1:0] profile_reg;
    reg [31:0] id_reg, data_reg[0:128];
    reg [7:0] index_reg, length_reg;
    reg [3:0] status_reg;
    reg discard_reg;
    assign request_ready_o=state_reg==0 && peers_ready_i;
    assign generation_ready_o=state_reg==1;
    assign result_valid_o=state_reg==2;
    assign result_data_o=result_valid_o ? data_reg[index_reg] : 0;
    assign result_component_o=profile_reg!=2 ? 1 : index_reg<64 ? 2 : index_reg==64 ? 3 : index_reg<97 ? 4 : 5;
    assign result_index_o=profile_reg!=2 || index_reg<64 ? index_reg[6:0] : index_reg==64 ? 0 : index_reg<97 ? index_reg-65 : index_reg-97;
    assign result_component_last_o=profile_reg!=2 ? index_reg==length_reg-1 : index_reg==63 || index_reg==64 || index_reg==96 || index_reg==128;
    assign result_last_o=index_reg==length_reg-1;
    assign result_id_o=id_reg;
    assign ownership_ready_o=state_reg==3;
    assign result_discard_o=discard_reg;
    assign status_valid_o=state_reg==4;
    assign status_code_o=status_reg;
    assign status_id_o=id_reg;
    always @(posedge clock_i or negedge reset_n_i) begin
        if(!reset_n_i) begin state_reg<=0;profile_reg<=0;id_reg<=0;index_reg<=0;length_reg<=0;status_reg<=0;discard_reg<=0;end
        else if(state_reg>=1 && state_reg<=3 && generation_failed_i) begin status_reg<=2;discard_reg<=1;state_reg<=4;end
        else case(state_reg)
            0: if(request_valid_i && request_ready_o) begin
                profile_reg<=request_profile_i;id_reg<=request_id_i;index_reg<=0;discard_reg<=0;status_reg<=0;
                length_reg<=request_profile_i==0 ? 4 : request_profile_i==1 ? 8 : 129;state_reg<=1;
            end
            1: if(generation_valid_i) begin
                data_reg[index_reg]<=profile_reg==2 ? 32'hca000000+index_reg : generation_data_i;
                if(index_reg==length_reg-1) begin index_reg<=0;state_reg<=2;end
                else index_reg<=index_reg+1'b1;
            end
            2: if(result_ready_i) begin
                if(index_reg==length_reg-1) state_reg<=3;
                else index_reg<=index_reg+1'b1;
            end
            3: if(ownership_valid_i) begin status_reg<=ownership_accept_i ? 0 : 5;state_reg<=4;end
            4: if(status_ready_i) begin state_reg<=0;discard_reg<=0;end
        endcase
    end
endmodule
