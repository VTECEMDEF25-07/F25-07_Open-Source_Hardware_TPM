// Exclusive operation reservations over the existing persistent Hash_DRBG.
// Codex assisted implementation. No reseed/entropy-strength claim is added.
module rng_word_service #(parameter integer WAIT_LIMIT=1000000)(
    input wire clock_i, reset_n_i,
    input wire [255:0] random_i, input wire random_valid_i, fault_i,
    output wire random_request_o, output wire timeout_o,
    input wire key_open_i, output wire key_grant_o,
    input wire key_close_i, output wire key_closed_o,
    output wire [31:0] word_o, output wire word_valid_o,
    input wire word_ready_i, output wire key_fault_o,
    input wire host_request_i, host_commit_i, host_timeout_i,
    output wire host_wait_o, output wire [255:0] host_random_o,
    output wire host_valid_o, host_fault_o
);
    localparam NONE=0, KEY=1, HOST=2;
    reg [1:0] owner;
    reg prefer_host, pending, filled, failed, timed_out;
    reg [255:0] block_reg;
    reg [2:0] offset;
    reg [31:0] wait_count;
    wire expired = pending && wait_count >= WAIT_LIMIT-1;
    wire bad = fault_i || failed || expired || host_timeout_i;
    assign timeout_o = timed_out || expired || host_timeout_i;
    assign key_fault_o = bad;
    assign host_fault_o = bad;
    assign key_grant_o = reset_n_i && owner==KEY && !bad;
    assign key_closed_o = reset_n_i && owner!=KEY;
    assign host_wait_o = reset_n_i && host_request_i && owner!=HOST && !bad;
    // Level request survives source startup/reseed. Suppress on the response
    // edge so the DRBG cannot accept a second Generate before we drop pending.
    assign random_request_o = reset_n_i && pending && !random_valid_i && !bad;
    assign word_valid_o = key_grant_o && filled && !key_close_i;
    assign word_o = word_valid_o ? block_reg[255:224] : 32'd0;
    assign host_valid_o = reset_n_i && owner==HOST && random_valid_i && pending && !bad;
    assign host_random_o = host_valid_o ? random_i : 256'd0;
    always @(posedge clock_i or negedge reset_n_i) begin
        if(!reset_n_i) begin
            owner<=NONE; prefer_host<=0; pending<=0; filled<=0;
            failed<=0; timed_out<=0; block_reg<=0; offset<=0; wait_count<=0;
        end else begin
            if(expired || host_timeout_i) timed_out<=1;
            if(bad) begin
                failed<=1; filled<=0; block_reg<=0; offset<=0;
                // Sticky quarantine until shared reset. Do not reset SHA or
                // release a failed in-flight message to another RNG client.
                pending<=0;
                if(owner==KEY && key_close_i) owner<=NONE;
                if(owner==HOST && host_commit_i) owner<=NONE;
            end else begin
                if(pending) wait_count<=wait_count+1'b1;
                else wait_count<=0;
                if(owner==NONE) begin
                    if(host_request_i && (!key_open_i || prefer_host)) begin
                        owner<=HOST; pending<=1; prefer_host<=0;
                    end else if(key_open_i) begin owner<=KEY; prefer_host<=1; end
                end
                if(owner==KEY) begin
                    if(key_close_i) begin
                        filled<=0; block_reg<=0; offset<=0;
                        // Drain any already-issued block before releasing.
                        if(!pending || random_valid_i) begin owner<=NONE; pending<=0; end
                    end else if(!filled && !pending && word_ready_i) pending<=1;
                    if(random_valid_i && pending) begin
                        pending<=0;
                        if(!key_close_i) begin block_reg<=random_i; offset<=0; filled<=1; end
                    end
                    if(word_valid_o && word_ready_i) begin
                        block_reg<={block_reg[223:0],32'd0};
                        if(offset==7) begin filled<=0; offset<=0; end
                        else offset<=offset+1'b1;
                    end
                end
                if(owner==HOST) begin
                    if(random_valid_i && pending) pending<=0;
                    // The worker commits only after its complete response has
                    // passed the health check, before host transmission.
                    if(host_commit_i && !pending) owner<=NONE;
                end
            end
        end
    end
endmodule
