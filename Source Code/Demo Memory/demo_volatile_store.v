// Protected, volatile whole-result receiver. No SPI/public secret-read port.
// Codex-assisted implementation of DE25_DEMO_INTERFACES v0.1 (2026-11-09).
module demo_volatile_store #(parameter PRIVATE_RSA_ENABLE=0) (
    input wire clock_i, reset_n_i,
    input wire reserve_valid_i,
    output wire reserve_ready_o,
    input wire [1:0] reserve_profile_i,
    input wire [31:0] reserve_id_i,
    input wire [1:0] reserve_mode_i,
    input wire reserve_demo_use_i,
    output wire receiver_ready_o,
    output wire receiver_error_o,
    output wire [3:0] receiver_error_code_o,
    output wire receiver_scrub_done_o,
    input wire abort_i,
    input wire result_valid_i,
    output wire result_ready_o,
    input wire [31:0] result_data_i,
    input wire [2:0] result_component_i,
    input wire [6:0] result_index_i,
    input wire result_component_last_i, result_last_i,
    input wire [31:0] result_id_i,
    input wire result_discard_i,
    input wire decision_valid_i,
    output wire decision_ready_o,
    input wire decision_accept_i,
    output wire ownership_valid_o,
    input wire ownership_ready_i,
    output wire ownership_accept_o,
    output wire commit_valid_o,
    input wire commit_ready_i,
    output wire [31:0] commit_handle_o, commit_id_o,
    output wire [1:0] commit_mode_o,
    input wire release_valid_i,
    output wire release_ready_o,
    input wire [31:0] release_handle_i,
    output wire release_rsp_valid_o,
    input wire release_rsp_ready_i,
    output wire [31:0] release_rsp_code_o,
    input wire key_request_i,
    output wire key_request_ready_o,
    input wire [31:0] key_handle_i,
    output wire key_reply_valid_o,
    input wire key_reply_ready_i,
    output wire [255:0] resolved_key_o,
    output wire [31:0] key_reply_code_o,
    input wire use_allowed_i, client_active_i,
    input wire rsa_use_allowed_i,rsa_client_active_i,
    input wire public_request_i,output wire public_request_ready_o,
    input wire [31:0] public_handle_i,input wire public_component_i,input wire [5:0] public_index_i,
    output wire public_reply_valid_o,input wire public_reply_ready_i,
    output wire [31:0] public_data_o,public_reply_code_o,
    input wire private_request_i,output wire private_request_ready_o,
    input wire [31:0] private_handle_i,input wire private_component_i,input wire [5:0] private_index_i,
    output wire private_reply_valid_o,input wire private_reply_ready_i,
    output wire [31:0] private_data_o,private_reply_code_o
);
    localparam [2:0] SCRUB=0, EMPTY=1, STAGE=2, COMPLETE=3, OWNED=4;
    reg [1:0] reset_sync;
    wire active = reset_n_i && reset_sync[1];
    always @(posedge clock_i or negedge reset_n_i)
        if (!reset_n_i) reset_sync <= 0;
        else reset_sync <= {reset_sync[0],1'b1};

    reg [31:0] words [0:128];
    reg [2:0] state;
    reg [7:0] count, scrub_index;
    reg scrubbed, error_latched;
    reg [3:0] error_code;
    reg [1:0] profile, mode;
    reg [31:0] operation_id, handle;
    reg demo_use;
    reg [30:0] incarnation;
    reg exhausted;
    reg commit_valid;
    reg [31:0] commit_handle, commit_id;
    reg [1:0] commit_mode;
    reg release_pending, release_rsp_valid;
    reg [31:0] release_rsp_code;
    reg key_reply_valid;
    reg [255:0] key_reply_data;
    reg [31:0] key_reply_code;
    reg public_reply_valid,private_reply_valid;
    reg [31:0] public_data,public_code,private_data,private_code;
    wire rsa_active=PRIVATE_RSA_ENABLE && rsa_client_active_i;
    wire word_reply_pending=public_reply_valid || private_reply_valid;
    reg [2:0] expected_component;
    reg [6:0] expected_index;
    reg expected_component_last, expected_last;
    integer k;

    always @* begin
        expected_component = 1;
        expected_index = count[6:0];
        expected_last = (profile == 0 && count == 3) || (profile == 1 && count == 7);
        expected_component_last = expected_last;
        if (profile == 2) begin
            expected_last = count == 128;
            if (count < 64) begin
                expected_component = 2; expected_index = count[6:0];
                expected_component_last = count == 63;
            end else if (count == 64) begin
                expected_component = 3; expected_index = 0;
                expected_component_last = 1;
            end else if(PRIVATE_RSA_ENABLE)begin
                expected_component=6;expected_index=count-65;
                expected_component_last=count==128;
            end else if (count < 97) begin
                expected_component = 4; expected_index = count - 65;
                expected_component_last = count == 96;
            end else begin
                expected_component = 5; expected_index = count - 97;
                expected_component_last = count == 128;
            end
        end
    end
    wire malformed = result_id_i != operation_id ||
        result_component_i != expected_component || result_index_i != expected_index ||
        result_component_last_i != expected_component_last || result_last_i != expected_last ||
        (profile == 2 && count == 64 && result_data_i != 32'h00010001);
    wire unowned_abort = (state == STAGE || state == COMPLETE) && (abort_i || result_discard_i);
    assign reserve_ready_o = active && state == EMPTY && !abort_i && !result_discard_i &&
        !commit_valid && !release_rsp_valid && !key_reply_valid && !word_reply_pending && !release_valid_i && !exhausted;
    assign receiver_ready_o = active && (state == STAGE || state == COMPLETE) &&
        !abort_i && !result_discard_i && !error_latched;
    assign receiver_error_o = active && error_latched;
    assign receiver_error_code_o = receiver_error_o ? error_code : 4'd0;
    assign receiver_scrub_done_o = active && scrubbed;
    assign result_ready_o = receiver_ready_o && state == STAGE;
    assign ownership_valid_o = receiver_ready_o && state == COMPLETE && decision_valid_i && !commit_valid;
    assign decision_ready_o = receiver_ready_o && state == COMPLETE && ownership_ready_i && !commit_valid;
    assign ownership_accept_o = ownership_valid_o && decision_accept_i && !exhausted;
    assign commit_valid_o = active && commit_valid;
    assign commit_handle_o = active ? commit_handle : 32'd0;
    assign commit_id_o = active ? commit_id : 32'd0;
    assign commit_mode_o = active ? commit_mode : 2'd0;
    assign release_ready_o = active && (state == EMPTY || state == OWNED) &&
        !client_active_i && !rsa_active && !key_reply_valid && !word_reply_pending && !commit_valid && !release_rsp_valid;
    assign release_rsp_valid_o = active && release_rsp_valid;
    assign release_rsp_code_o = release_rsp_valid_o ? release_rsp_code : 32'd0;
    assign key_request_ready_o = active && (state == EMPTY || state == OWNED) &&
        !key_reply_valid && !word_reply_pending && !commit_valid && !release_rsp_valid && !release_valid_i &&
        !(state == EMPTY && reserve_valid_i);
    assign key_reply_valid_o = active && key_reply_valid;
    assign resolved_key_o = key_reply_valid_o && key_reply_code == 0 ? key_reply_data : 256'd0;
    assign key_reply_code_o = key_reply_valid_o ? key_reply_code : 32'd0;
    assign public_request_ready_o=active && PRIVATE_RSA_ENABLE && (state==EMPTY || state==OWNED) &&
        !rsa_active && !key_reply_valid && !word_reply_pending && !commit_valid && !release_rsp_valid &&
        !release_valid_i && !key_request_i && !(state==EMPTY && reserve_valid_i);
    assign private_request_ready_o=active && PRIVATE_RSA_ENABLE && (state==EMPTY || state==OWNED) &&
        !key_reply_valid && !word_reply_pending && !commit_valid && !release_rsp_valid &&
        !release_valid_i && !key_request_i && !(public_request_i && public_request_ready_o) && !(state==EMPTY && reserve_valid_i);
    assign public_reply_valid_o=active && public_reply_valid;
    assign private_reply_valid_o=active && private_reply_valid;
    assign public_data_o=public_reply_valid_o && public_code==0 ? public_data : 32'd0;
    assign private_data_o=private_reply_valid_o && private_code==0 ? private_data : 32'd0;
    assign public_reply_code_o=public_reply_valid_o ? public_code : 32'd0;
    assign private_reply_code_o=private_reply_valid_o ? private_code : 32'd0;

    always @(posedge clock_i or negedge reset_n_i) begin
        if (!reset_n_i) begin
            state <= SCRUB; scrub_index <= 0; scrubbed <= 0; count <= 0;
            error_latched <= 0; error_code <= 0;
            profile <= 0; mode <= 0; operation_id <= 0; handle <= 0; demo_use <= 0;
            incarnation <= 1; exhausted <= 0;
            commit_valid <= 0; commit_handle <= 0; commit_id <= 0; commit_mode <= 0;
            release_pending <= 0; release_rsp_valid <= 0; release_rsp_code <= 0;
            key_reply_valid <= 0; key_reply_data <= 0; key_reply_code <= 0;
            public_reply_valid<=0;private_reply_valid<=0;public_data<=0;private_data<=0;public_code<=0;private_code<=0;
        end else if (!active) begin
            state <= SCRUB; scrub_index <= 0; scrubbed <= 0; count <= 0;
            error_latched <= 0; error_code <= 0;
            profile <= 0; mode <= 0; operation_id <= 0; handle <= 0; demo_use <= 0;
            incarnation <= 1; exhausted <= 0;
            commit_valid <= 0; commit_handle <= 0; commit_id <= 0; commit_mode <= 0;
            release_pending <= 0; release_rsp_valid <= 0; release_rsp_code <= 0;
            key_reply_valid <= 0; key_reply_data <= 0; key_reply_code <= 0;
            public_reply_valid<=0;private_reply_valid<=0;public_data<=0;private_data<=0;public_code<=0;private_code<=0;
        end else begin
            if (commit_valid && commit_ready_i) commit_valid <= 0;
            if (release_rsp_valid && release_rsp_ready_i) begin
                release_rsp_valid <= 0; release_rsp_code <= 0;
            end
            if (key_reply_valid && key_reply_ready_i) begin
                key_reply_valid <= 0; key_reply_data <= 0; key_reply_code <= 0;
            end
            if(public_reply_valid && public_reply_ready_i)begin public_reply_valid<=0;public_data<=0;public_code<=0;end
            if(private_reply_valid && private_reply_ready_i)begin private_reply_valid<=0;private_data<=0;private_code<=0;end
            if (state == SCRUB) begin
                // Keep this done level asserted even while discard/abort is held.
                if (!scrubbed) begin
                    if (scrub_index < 129) begin
                        words[scrub_index] <= 0;
                        scrub_index <= scrub_index + 1'b1;
                    end else begin
                        key_reply_data <= 0; key_reply_code <= 0;
                        public_data<=0;private_data<=0;public_code<=0;private_code<=0;
                        scrubbed <= 1;
                        if (release_pending) begin
                            release_rsp_valid <= 1; release_rsp_code <= 0;
                            release_pending <= 0;
                        end
                    end
                end else if (!abort_i && !result_discard_i) begin
                    state <= EMPTY; error_latched <= 0; error_code <= 0;
                end
            end else if (unowned_abort) begin
                state <= SCRUB; scrub_index <= 0; scrubbed <= 0; count <= 0;
                profile <= 0; mode <= 0; operation_id <= 0; demo_use <= 0;
            end else if (state == EMPTY && reserve_valid_i && reserve_ready_o) begin
                profile <= reserve_profile_i; mode <= reserve_mode_i;
                operation_id <= reserve_id_i; demo_use <= reserve_demo_use_i;
                count <= 0; scrubbed <= 0;
                if (reserve_profile_i == 3 || reserve_mode_i > 1) begin
                    error_latched <= 1; error_code <= 1;
                    state <= SCRUB; scrub_index <= 0;
                    profile <= 0; mode <= 0; operation_id <= 0; demo_use <= 0;
                end else state <= STAGE;
            end else if (state == STAGE && result_valid_i && result_ready_o) begin
                if (malformed) begin
                    error_latched <= 1; error_code <= 7;
                    state <= SCRUB; scrub_index <= 0; count <= 0;
                    profile <= 0; mode <= 0; operation_id <= 0; demo_use <= 0;
                end else begin
                    words[count] <= result_data_i;
                    count <= count + 1'b1;
                    if (expected_last) state <= COMPLETE;
                end
            end else if (ownership_valid_o && ownership_ready_i) begin
                if (ownership_accept_o) begin
                    state <= OWNED;
                    handle <= {1'b1,incarnation};
                    commit_valid <= 1; commit_handle <= {1'b1,incarnation};
                    commit_id <= operation_id; commit_mode <= mode;
                    if (incarnation == 31'h7fffffff) exhausted <= 1;
                    else incarnation <= incarnation + 1'b1;
                end else begin
                    state <= SCRUB; scrub_index <= 0; scrubbed <= 0; count <= 0;
                    profile <= 0; mode <= 0; operation_id <= 0; demo_use <= 0;
                end
            end else if (release_valid_i && release_ready_o) begin
                if (state != OWNED || release_handle_i != handle) begin
                    release_rsp_valid <= 1; release_rsp_code <= 32'h18b;
                end else begin
                    state <= SCRUB; scrub_index <= 0; scrubbed <= 0;
                    release_pending <= 1; handle <= 0; count <= 0;
                    profile <= 0; mode <= 0; operation_id <= 0; demo_use <= 0;
                    key_reply_data <= 0; key_reply_code <= 0;
                end
            end else if (key_request_i && key_request_ready_o) begin
                key_reply_valid <= 1; key_reply_data <= 0;
                if (state != OWNED || key_handle_i != handle) key_reply_code <= 32'h18b;
                else if (profile != 1 || !demo_use || !use_allowed_i) key_reply_code <= 32'h12f;
                else begin
                    key_reply_code <= 0;
                    for (k=0; k<8; k=k+1) key_reply_data[255-k*32 -: 32] <= words[k];
                end
            end else if(public_request_i && public_request_ready_o)begin
                public_reply_valid<=1;public_data<=0;
                if(state!=OWNED || public_handle_i!=handle)public_code<=32'h18b;
                else if(profile!=2 || !demo_use || !rsa_use_allowed_i)public_code<=32'h12f;
                else if(public_component_i && public_index_i!=0)public_code<=32'h095;
                else begin public_code<=0;public_data<=words[public_component_i ? 7'd64 : {1'b0,public_index_i}];end
            end else if(private_request_i && private_request_ready_o)begin
                private_reply_valid<=1;private_data<=0;
                if(state!=OWNED || private_handle_i!=handle)private_code<=32'h18b;
                else if(profile!=2 || !demo_use || !rsa_use_allowed_i || !rsa_active)private_code<=32'h12f;
                else begin private_code<=0;private_data<=words[private_component_i ? 8'd65+{2'd0,private_index_i} : {2'd0,private_index_i}];end
            end
        end
    end
endmodule
