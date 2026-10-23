// ===========================================================================
// tb_tpm2_get_random.v
//
// Testbench for TPM2_GetRandom.
//   Part A drives the full RNG top level (ring oscillators -> DRBG -> command).
//   Part B drives tpm2_get_random alone with a known DRBG block, so the
//   exact payload bytes, TPM_RC_INITIALIZE and TPM_RC_FAILURE can be checked.
//
// Run (Icarus):
//   iverilog -g2005 -DSIMULATION -s tb_tpm2_get_random -o sim \
//       tb_tpm2_get_random.v RNG.v tpm2_get_random.v \
//       random_number_generation.v entropy_source.v ring_osc.v
//   vvp sim
//
// Written by Jungyeon Won with the help of generative AI
// ===========================================================================
`timescale 1ns/1ps
 
module tb_tpm2_get_random;
 
    reg clk = 1'b0;
    always #5 clk = ~clk;                 // 100 MHz
    reg rst_n = 1'b0;
 
    integer errors = 0;
    integer seed   = 7;
 
    // ---------------- Part A: full top level ----------------
    reg  [7:0] a_cmd_data  = 8'h00;
    reg        a_cmd_valid = 1'b0;
    reg        a_cmd_last  = 1'b0;
    wire       a_cmd_ready;
    wire [7:0] a_rsp_data;
    wire       a_rsp_valid, a_rsp_last;
    reg        a_rsp_ready = 1'b0;
 
    RNG dut_top (
        .clk(clk), .rst_n(rst_n), .enable(1'b1),
        .cmd_data(a_cmd_data), .cmd_valid(a_cmd_valid),
        .cmd_last(a_cmd_last), .cmd_ready(a_cmd_ready),
        .rsp_data(a_rsp_data), .rsp_valid(a_rsp_valid),
        .rsp_last(a_rsp_last), .rsp_ready(a_rsp_ready)
    );
 
    // ---------------- Part B: command module alone ----------------
    reg  [7:0]   b_cmd_data  = 8'h00;
    reg          b_cmd_valid = 1'b0;
    reg          b_cmd_last  = 1'b0;
    wire         b_cmd_ready;
    wire [7:0]   b_rsp_data;
    wire         b_rsp_valid, b_rsp_last;
    reg          b_rsp_ready = 1'b0;
    reg  [255:0] b_rng_data  = 256'b0;
    reg          b_rng_valid = 1'b0;
    reg          b_init      = 1'b1;
    reg          b_fault     = 1'b0;
 
    tpm2_get_random dut_unit (
        .clk(clk), .rst_n(rst_n),
        .cmd_data(b_cmd_data), .cmd_valid(b_cmd_valid),
        .cmd_last(b_cmd_last), .cmd_ready(b_cmd_ready),
        .rsp_data(b_rsp_data), .rsp_valid(b_rsp_valid),
        .rsp_last(b_rsp_last), .rsp_ready(b_rsp_ready),
        .rng_data(b_rng_data), .rng_valid(b_rng_valid),
        .tpm_initialized(b_init), .rng_fault(b_fault)
    );
 
    // ---------------- Shared buffers ----------------
    reg [7:0] cmd [0:63];
    integer   cmd_len;
    reg [7:0] rsp [0:63];
    integer   rsp_len;
    reg       use_unit;   // 0 = Part A DUT, 1 = Part B DUT
 
    // Build a command frame in cmd[].
    task build;
        input [15:0] tag;
        input [31:0] size;
        input [31:0] code;
        input [15:0] req;
        input integer len;            // bytes actually sent
        integer i;
        begin
            cmd[0] = tag[15:8];  cmd[1] = tag[7:0];
            cmd[2] = size[31:24]; cmd[3] = size[23:16];
            cmd[4] = size[15:8];  cmd[5] = size[7:0];
            cmd[6] = code[31:24]; cmd[7] = code[23:16];
            cmd[8] = code[15:8];  cmd[9] = code[7:0];
            cmd[10] = req[15:8];  cmd[11] = req[7:0];
            for (i = 12; i < 64; i = i + 1) cmd[i] = 8'hEE;
            cmd_len = len;
        end
    endtask
 
    // Send cmd[] and collect the whole response into rsp[], with random
    // gaps on both sides to exercise the valid/ready handshake.
    task transact;
        integer i, guard;
        reg done, rdy;
        begin
            i = 0;
            while (i < cmd_len) begin
                @(negedge clk);
                if ($random(seed) & 1) begin
                    if (use_unit) begin
                        b_cmd_valid = 1; b_cmd_data = cmd[i]; b_cmd_last = (i == cmd_len-1);
                    end else begin
                        a_cmd_valid = 1; a_cmd_data = cmd[i]; a_cmd_last = (i == cmd_len-1);
                    end
                    #1 rdy = use_unit ? b_cmd_ready : a_cmd_ready;
                    @(posedge clk);
                    if (rdy) i = i + 1;   // byte accepted on this edge
                end else begin
                    b_cmd_valid = 0; a_cmd_valid = 0;
                end
            end
            @(negedge clk);
            b_cmd_valid = 0; a_cmd_valid = 0; b_cmd_last = 0; a_cmd_last = 0;
 
            rsp_len = 0; done = 0; guard = 0;
            while (!done && guard < 20000) begin
                @(negedge clk);
                guard = guard + 1;
                if (use_unit) b_rsp_ready = $random(seed) & 1;
                else          a_rsp_ready = $random(seed) & 1;
                #1;
                if (use_unit ? (b_rsp_valid && b_rsp_ready) : (a_rsp_valid && a_rsp_ready)) begin
                    rsp[rsp_len] = use_unit ? b_rsp_data : a_rsp_data;
                    rsp_len = rsp_len + 1;
                    if (use_unit ? b_rsp_last : a_rsp_last) done = 1;
                end
                @(posedge clk);   // byte transfers on this edge
            end
            @(negedge clk);
            a_rsp_ready = 0; b_rsp_ready = 0;
            if (!done) begin
                $display("  FAIL: no response (timeout)");
                errors = errors + 1;
            end
        end
    endtask
 
    // Check header fields and size of the response.
    task check_rsp;
        input [255:0] name;
        input [31:0]  exp_rc;
        input integer exp_n;          // random bytes expected (if success)
        reg [31:0] rsize, rc;
        integer exp_len;
        begin
            exp_len = (exp_rc == 0) ? 12 + exp_n : 10;
            rsize = {rsp[2], rsp[3], rsp[4], rsp[5]};
            rc    = {rsp[6], rsp[7], rsp[8], rsp[9]};
            if ({rsp[0], rsp[1]} !== 16'h8001 || rsize !== exp_len ||
                rsp_len !== exp_len || rc !== exp_rc ||
                (exp_rc == 0 && {rsp[10], rsp[11]} !== exp_n)) begin
                $display("  FAIL %0s: tag=%h size=%0d got_len=%0d rc=%h (expected rc=%h len=%0d)",
                         name, {rsp[0], rsp[1]}, rsize, rsp_len, rc, exp_rc, exp_len);
                errors = errors + 1;
            end else
                $display("  pass %0s: rc=0x%03h, %0d bytes", name, rc, rsp_len);
        end
    endtask
 
    // Print the payload as hex.
    task show_payload;
        integer i;
        begin
            $write("        randomBytes = ");
            for (i = 12; i < rsp_len; i = i + 1) $write("%02h", rsp[i]);
            $write("\n");
        end
    endtask
 
    // Feed one known block into the Part B DUT.
    task feed_block;
        input [255:0] blk;
        begin
            @(negedge clk); b_rng_data = blk; b_rng_valid = 1;
            @(negedge clk); b_rng_valid = 0;
        end
    endtask
 
    reg [7:0] first [0:31];
    integer i, same;
    reg [255:0] pattern;
 
    initial begin
        repeat (3) @(negedge clk);
        rst_n = 1'b1;
 
        // ===================================================================
        $display("Part A: full top level (ring oscillators -> DRBG -> GetRandom)");
        use_unit = 0;
 
        build(16'h8001, 32'd12, 32'h17B, 16'd16, 12); transact;
        check_rsp("request 16 bytes", 32'h0, 16);  show_payload;
 
        build(16'h8001, 32'd12, 32'h17B, 16'd32, 12); transact;
        check_rsp("request 32 bytes", 32'h0, 32);  show_payload;
        for (i = 0; i < 32; i = i + 1) first[i] = rsp[12+i];
 
        build(16'h8001, 32'd12, 32'h17B, 16'd32, 12); transact;
        check_rsp("request 32 again", 32'h0, 32);  show_payload;
        same = 1;
        for (i = 0; i < 32; i = i + 1) if (rsp[12+i] !== first[i]) same = 0;
        if (same) begin
            $display("  FAIL two calls returned identical bytes"); errors = errors + 1;
        end else
            $display("  pass back-to-back calls return different bytes");
 
        build(16'h8001, 32'd12, 32'h17B, 16'd1000, 12); transact;
        check_rsp("request 1000 (clamped to 32)", 32'h0, 32);
 
        build(16'h8001, 32'd12, 32'h17B, 16'd0, 12); transact;
        check_rsp("request 0 bytes", 32'h0, 0);
 
        build(16'h8002, 32'd12, 32'h17B, 16'd8, 12); transact;
        check_rsp("TPM_ST_SESSIONS tag", 32'h01E, 0);
 
        build(16'h00C1, 32'd12, 32'h17B, 16'd8, 12); transact;
        check_rsp("TPM 1.2 style tag", 32'h01E, 0);
 
        build(16'h8001, 32'd14, 32'h17B, 16'd8, 12); transact;
        check_rsp("commandSize says 14, sent 12", 32'h142, 0);
 
        build(16'h8001, 32'd12, 32'h17A, 16'd8, 12); transact;
        check_rsp("wrong command code", 32'h143, 0);
 
        build(16'h8001, 32'd12, 32'h17B, 16'd8, 5); transact;
        check_rsp("5-byte frame", 32'h09A, 0);
 
        build(16'h8001, 32'd10, 32'h17B, 16'd8, 10); transact;
        check_rsp("bytesRequested missing", 32'h1DA, 0);
 
        build(16'h8001, 32'd14, 32'h17B, 16'd8, 14); transact;
        check_rsp("2 extra bytes", 32'h095, 0);
 
        build(16'h8001, 32'd12, 32'h17B, 16'd8, 12); transact;
        check_rsp("good request after errors", 32'h0, 8);
 
        // ===================================================================
        $display("Part B: command module with a known DRBG block");
        use_unit = 1;
        pattern = 256'h00112233_44556677_8899AABB_CCDDEEFF_0F1E2D3C_4B5A6978_8796A5B4_C3D2E1F0;
 
        feed_block(pattern);
        build(16'h8001, 32'd12, 32'h17B, 16'd32, 12); transact;
        check_rsp("payload byte order", 32'h0, 32);
        same = 1;
        for (i = 0; i < 32; i = i + 1)
            if (rsp[12+i] !== pattern[255 - 8*i -: 8]) same = 0;
        if (same) $display("  pass payload equals DRBG block, MSB first");
        else begin $display("  FAIL payload mismatch"); errors = errors + 1; show_payload; end
 
        // Block was consumed: the next command must wait for a new one.
        fork
            begin
                build(16'h8001, 32'd12, 32'h17B, 16'd4, 12); transact;
            end
            begin
                repeat (200) @(negedge clk);
                if (b_rsp_valid) begin
                    $display("  FAIL responded without a fresh block"); errors = errors + 1;
                end else
                    $display("  pass waits for a fresh block (no reuse)");
                feed_block(256'hDEADBEEF << 224);
            end
        join
        check_rsp("after fresh block", 32'h0, 4);
        if ({rsp[12], rsp[13], rsp[14], rsp[15]} === 32'hDEADBEEF)
            $display("  pass used the new block");
        else begin $display("  FAIL wrong payload"); errors = errors + 1; end
 
        b_init = 0;
        build(16'h8001, 32'd12, 32'h17B, 16'd8, 12); transact;
        check_rsp("before TPM2_Startup", 32'h100, 0);
        b_init = 1;
 
        b_fault = 1;
        build(16'h8001, 32'd12, 32'h17B, 16'd8, 12); transact;
        check_rsp("RNG health-test fault", 32'h101, 0);
        b_fault = 0;
 
        // ===================================================================
        if (errors == 0) $display("\nALL TESTS PASSED");
        else             $display("\n%0d TEST(S) FAILED", errors);
        $finish;
    end
 
    initial begin
        #5_000_000;
        $display("GLOBAL TIMEOUT"); $finish;
    end
 
endmodule