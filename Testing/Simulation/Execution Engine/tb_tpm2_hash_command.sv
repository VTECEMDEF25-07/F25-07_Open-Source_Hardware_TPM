`timescale 1ns/1ps
module tb_tpm2_hash_command;
    reg clk=0;
    always #5 clk=~clk;
    reg reset_n=0, send=0, operational=0;
    reg [31:0] command_size;
    reg [7:0] command [0:4095];
    reg [7:0] reply [0:4095];
    reg [7:0] command_byte;
    wire [11:0] cmd_addr, rsp_addr, exec_cmd_addr, exec_rsp_addr, exec_rsp_length;
    wire [7:0] rsp_byte, exec_cmd_byte, exec_rsp_byte, hash_data;
    wire [31:0] rsp_size, code, rc;
    wire [15:0] tag;
    wire write_n, done, execute, executed, ready;
    wire hash_request, hash_grant, hash_valid, hash_end, hash_ready;
    wire [255:0] digest;
    wire digest_valid, digest_ready;
    integer jobs=0, writes=0, i;
    reg passed=0;

    always @(posedge clk) begin
        command_byte <= command[cmd_addr];
        if (!write_n) begin
            reply[rsp_addr] <= rsp_byte;
            writes <= writes+1;
        end
        if (hash_grant) jobs <= jobs+1;
    end

    tpm_crb #(.SCOPED_COMMANDS(1)) crb (
        .clock_i(clk), .reset_n_i(reset_n), .locality_i(8'd0), .cmdAbort_i(1'b0),
        .cmdSize_i(command_size), .rspSize_o(rsp_size),
        .cmdSend_i(send), .rspSend_o(write_n), .rspDone_o(done),
        .cmdOutAddr_o(cmd_addr), .rspOutAddr_o(rsp_addr),
        .cmdByteIn_i(command_byte), .rspByteOut_o(rsp_byte),
        .execDone_o(executed), .execAck_i(executed), .execStart_o(execute),
        .rspReady_i(ready), .responseCode_i(rc), .commandCode_o(code), .commandTag_o(tag),
        .exec_cmd_addr_i(exec_cmd_addr), .exec_cmd_byte_o(exec_cmd_byte),
        .exec_rsp_length_i(exec_rsp_length), .exec_rsp_addr_o(exec_rsp_addr),
        .exec_rsp_byte_i(exec_rsp_byte)
    );
    execution_engine_hash engine (
        .clock_i(clk), .reset_n_i(reset_n), .start_i(execute), .operational_i(operational),
        .command_tag_i(tag), .command_code_i(code), .command_size_i(command_size),
        .command_addr_o(exec_cmd_addr), .command_byte_i(exec_cmd_byte),
        .response_valid_o(ready), .response_code_o(rc), .response_length_o(exec_rsp_length),
        .response_addr_i(exec_rsp_addr), .response_byte_o(exec_rsp_byte),
        .hash_request_o(hash_request), .hash_grant_i(hash_grant), .hash_data_o(hash_data),
        .hash_valid_o(hash_valid), .hash_end_o(hash_end), .hash_ready_i(hash_ready),
        .hash_digest_i(digest), .hash_digest_valid_i(digest_valid), .hash_digest_ready_o(digest_ready)
    );
    hash_engine #(.REQUESTERS(1)) sha (
        .clk_i(clk), .reset_n_i(reset_n), .request_valid_i(hash_request), .request_grant_o(hash_grant),
        .data_in_i(hash_data), .data_valid_i(hash_valid), .message_end_i(hash_end),
        .data_ready_o(hash_ready), .digest_out_o(digest), .digest_valid_o(digest_valid),
        .digest_ready_i(digest_ready)
    );

    task automatic make_hash(input integer length);
        begin
            command_size=length+18;
            {command[0],command[1]}=16'h8001;
            {command[2],command[3],command[4],command[5]}=command_size;
            {command[6],command[7],command[8],command[9]}=32'h0000017d;
            {command[10],command[11]}=length[15:0];
            for (int n=0;n<length;n++) command[12+n]=8'h61+n;
            {command[length+12],command[length+13]}=16'h000b;
            {command[length+14],command[length+15],command[length+16],command[length+17]}=32'h40000007;
        end
    endtask

    task automatic transact(input [31:0] expected_rc, input [255:0] expected_digest);
        integer old_jobs, old_writes;
        integer expected_length;
        begin
            old_jobs=jobs;
            old_writes=writes;
            expected_length=expected_rc==0 ? 52 : 10;
            send=1;
            @(negedge clk); send=0;
            while (!done) @(negedge clk);
            if (rsp_size !== expected_length || writes-old_writes != expected_length ||
                {reply[0],reply[1]} !== (expected_rc==32'h01e ? 16'h00c4 : 16'h8001) ||
                {reply[2],reply[3],reply[4],reply[5]} !== expected_length ||
                {reply[6],reply[7],reply[8],reply[9]} !== expected_rc)
                $fatal(1,"Wrong response header: tag=%h size=%0d writes=%0d rc=%h expected=%h",
                    {reply[0],reply[1]},rsp_size,writes-old_writes,
                    {reply[6],reply[7],reply[8],reply[9]},expected_rc);
            if (jobs-old_jobs != (expected_rc==0 ? 1 : 0))
                $fatal(1,"Unexpected SHA request count");
            if (expected_rc==0) begin
                if ({reply[10],reply[11]} !== 16'h0020) $fatal(1,"Wrong digest size");
                for (i=0;i<32;i++)
                    if (reply[12+i] !== expected_digest[255-i*8 -: 8])
                        $fatal(1,"Wrong digest byte %0d: %h",i,reply[12+i]);
                if ({reply[44],reply[45],reply[46],reply[47],reply[48],reply[49],reply[50],reply[51]}
                    !== 64'h8024400000070000)
                    $fatal(1,"Wrong null ticket");
            end
            repeat (3) @(negedge clk);
        end
    endtask

    initial begin
        repeat(3) @(negedge clk); reset_n=1;
        make_hash(3); transact(32'h100,0);
        operational=1;
        make_hash(3); transact(0,256'hba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad);
        make_hash(0); transact(0,256'he3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855);
        make_hash(64); transact(0,256'hc071fb5b95d7560616f63c0a90d1d462b91f1c992a49cb60dcb85c7e07540e36);
        make_hash(1024); transact(0,256'h284e785ac7a21761525b2e63d06ca8719e40dd69864b176fa01dbe865b145313);
        make_hash(3); command[11]=4; transact(32'h1d5,0);
        make_hash(3); command[16]=4; transact(32'h2c3,0);
        make_hash(3); command[20]=1; transact(32'h3c4,0);
        make_hash(3); command[1]=2; transact(32'h101,0);
        make_hash(3); command[0]=0; transact(32'h01e,0);
        make_hash(3); {command[8],command[9]}=16'h0193; transact(32'h143,0);
        make_hash(3); {command[8],command[9]}=16'h0121; transact(32'h143,0);
        make_hash(3); transact(0,256'hba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad);
        passed=1;
        $display("TPM2_HASH_COMMAND_PASS");
        $finish;
    end
    initial begin #1000000; $fatal(1,"TPM2_Hash command timeout"); end
endmodule
