`timescale 1ns/1ps
module tb_tpm2_pcr_extend_command #(parameter ENABLE_EXTEND=1, parameter [23:0] EMPTY_MASK=24'h008101);
    reg clk=0;
    always #5 clk=~clk;
    reg reset_n=0, send=0, operational=0;
    reg [7:0] locality=1;
    wire extend_start, pcr_busy, pcr_done, pcr_error;
    wire [4:0] extend_index;
    wire [255:0] measurement;
    integer commits=0, launches=0;
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
    wire [15:0] engine_length;
    wire [3:0] engine_state;
    assign exec_rsp_length=engine_length[11:0];
    integer accepted=0, completed=0, dispatched=0;
    wire [4:0] pcr_index;
    wire [255:0] pcr_data;
    wire pcr_valid;
    wire [31:0] counter;
    reg bank_write=0, bank_read_ok=1;
    reg [4:0] bank_index=0;
    reg [255:0] bank_data=0;
    reg [255:0] expected_bank[0:23];
    reg [7:0] expected[0:511];
    integer expected_size;
    reg [31:0] expected_counter=0;
    always @(posedge clk) if (reset_n) begin
        if (execute && engine_state == 0) accepted <= accepted+1;
        if (engine_state == 10) dispatched <= dispatched+1;
        if (ready) begin
            if (engine_state != 9 || !engine.pcr_active)
                $fatal(1,"PCR reply bypassed Phase One post-processing");
            completed <= completed+1;
        end
        if (engine.pcr_command.start_i && (engine_state != 10 || !engine.pcr_active))
            $fatal(1,"PCR bypassed engine dispatch");
        if (extend_start) launches <= launches+1;
        if (bank.pcr_write_en) commits <= commits+1;
        if (ready && code==32'h182 && rc==0 && engine.pcr_command.extend_count==1 &&
            engine.pcr_command.pcr_handle!=32'h40000007 && counter!=expected_counter)
            $fatal(1,"Success preceded committed update");
    end

    always @(posedge clk) begin
        command_byte <= command[cmd_addr];
        if (!write_n && crb.state == crb.RspOut_wait) begin
            reply[rsp_addr] <= rsp_byte;
            writes <= writes+1;
        end
        if (hash_grant) jobs <= jobs+1;
    end

    tpm_crb #(.SCOPED_COMMANDS(1), .PRESERVE_LEGACY_COMMANDS(1)) crb (
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
    execution_engine #(.ENABLE_HASH_COMMAND(1), .ENABLE_PCR_COMMANDS(1), .ENABLE_PCR_EXTEND(ENABLE_EXTEND),
        .PCR_EXTEND_EMPTY_AUTH_MASK(EMPTY_MASK)) engine (
        .clock_i(clk), .reset_n_i(reset_n), .command_done_i(1'b1), .command_ready_i(execute), .op_state_i(operational ? 3'd3 : 3'd2),
        .command_tag_i(tag),
        .command_code_i(code),
        .command_size_i(command_size),
        .command_addr_o(exec_cmd_addr), .command_byte_i(exec_cmd_byte),
        .response_valid_o(ready), .response_code_o(rc), .response_length_o(engine_length), .current_state_o(engine_state),
        .response_addr_i(exec_rsp_addr), .response_byte_o(exec_rsp_byte),
        .hash_request_o(hash_request), .hash_grant_i(hash_grant), .hash_data_o(hash_data),
        .hash_valid_o(hash_valid), .hash_end_o(hash_end), .hash_ready_i(hash_ready),
        .locality_i(locality), .pcr_extend_start_o(extend_start),
        .pcr_extend_index_o(extend_index), .pcr_measurement_o(measurement),
        .pcr_busy_i(pcr_busy), .pcr_done_i(pcr_done), .pcr_error_i(pcr_error),
        .pcr_read_index_o(pcr_index), .pcr_read_data_i(pcr_data),
        .pcr_read_valid_i(pcr_valid && bank_read_ok), .pcr_update_counter_i(counter),
        .hash_digest_i(digest), .hash_digest_valid_i(digest_valid), .hash_digest_ready_o(digest_ready)
    );
    hash_subsystem bank (
        .clk_i(clk), .reset_n_i(reset_n),
        .raw_request_i(hash_request), .raw_grant_o(hash_grant), .raw_data_i(hash_data),
        .raw_valid_i(hash_valid), .raw_end_i(hash_end), .raw_ready_o(hash_ready),
        .raw_digest_o(digest), .raw_digest_valid_o(digest_valid), .raw_digest_ready_i(digest_ready),
        .hmac_start_en_i(1'b0), .hmac_key_data_i(8'd0), .hmac_key_valid_i(1'b0),
        .hmac_key_end_i(1'b0), .hmac_message_data_i(8'd0), .hmac_message_valid_i(1'b0),
        .hmac_message_end_i(1'b0), .hmac_digest_ready_i(1'b0),
        .pcr_extend_start_en_i(extend_start), .pcr_extend_index_i(extend_index),
        .pcr_measurement_i(measurement), .pcr_busy_o(pcr_busy), .pcr_done_o(pcr_done),
        .pcr_error_o(pcr_error), .pcr_read_index_i(pcr_index), .pcr_read_data_o(pcr_data),
        .pcr_read_valid_o(pcr_valid), .pcr_update_counter_o(counter),
        .rng_hash_msg_data_i(8'd0), .rng_hash_msg_valid_i(1'b0), .rng_hash_msg_last_i(1'b0)
    );
    task automatic header(input [31:0] cc, input integer length);
      command_size=length;
      for(integer n=0;n<128;n++) command[n]=0;
      {command[0],command[1]}=16'h8001;
      {command[2],command[3],command[4],command[5]}=length;
      {command[6],command[7],command[8],command[9]}=cc;
    endtask
    task automatic read_packet(input [23:0] mask, input bit no_selection=0);
      header(32'h17e,no_selection ? 14 : 20);
      {command[10],command[11],command[12],command[13]}=no_selection ? 0 : 1;
      {command[14],command[15],command[16]}=24'h000b03;
      {command[17],command[18],command[19]}={mask[7:0],mask[15:8],mask[23:16]};
    endtask
    task automatic cap_packet(input [31:0] count=1, input [31:0] start_property=0, input [31:0] cap=5);
      header(32'h17a,22);
      {command[10],command[11],command[12],command[13]}=cap;
      {command[14],command[15],command[16],command[17]}=start_property;
      {command[18],command[19],command[20],command[21]}=count;
    endtask
    task automatic expected_header(input integer length, input [31:0] rc=0, input [15:0] rsp_tag=16'h8001);
      for(integer n=0;n<512;n++) expected[n]=0;
      expected_size=length;
      {expected[0],expected[1]}=rsp_tag;
      {expected[2],expected[3],expected[4],expected[5]}=length;
      {expected[6],expected[7],expected[8],expected[9]}=rc;
    endtask
    task automatic expect_read(input [23:0] mask,input bit no_selection=0);
      integer count,pos;
      reg [23:0] selected;
      begin
        count=0;selected=0;
        for(integer n=0;n<24;n++) if(mask[n] && count<8) begin selected[n]=1;count++;end
        expected_header((no_selection?22:28)+count*34);
        {expected[10],expected[11],expected[12],expected[13]}=expected_counter;
        {expected[14],expected[15],expected[16],expected[17]}=no_selection?0:1;
        pos=18;
        if(!no_selection) begin
          {expected[18],expected[19],expected[20]}=24'h000b03;
          {expected[21],expected[22],expected[23]}={selected[7:0],selected[15:8],selected[23:16]};
          pos=24;
        end
        {expected[pos],expected[pos+1],expected[pos+2],expected[pos+3]}=count;
        pos+=4;
        for(integer n=0;n<24;n++) if(selected[n]) begin
          expected[pos]=0;expected[pos+1]=32;pos+=2;
          for(integer j=0;j<32;j++) expected[pos+j]=expected_bank[n][255-j*8 -:8];
          pos+=32;
        end
      end
    endtask
    task automatic expect_cap(input bit empty=0);
      expected_header(empty ? 19 : 25);
      expected[10]=empty ? 1 : 0;expected[14]=5;
      if(!empty) begin
        expected[18]=1;expected[20]=8'h0b;expected[21]=3;
        expected[22]=8'hff;expected[23]=8'hff;expected[24]=8'hff;
      end
    endtask
    task automatic transact;
      integer old_writes;
      begin
        old_writes=writes; send=1;
        @(negedge clk);send=0;
        while(!done) @(negedge clk);
        if(rsp_size !== expected_size || writes-old_writes != expected_size)
          $fatal(1,"PCR response size: got %0d/%0d expected %0d",rsp_size,writes-old_writes,expected_size);
        for(integer n=0;n<expected_size;n++) if(reply[n] !== expected[n])
          $fatal(1,"PCR response byte %0d expected %h got %h cc=%h",n,expected[n],reply[n],code);
        @(negedge clk);repeat(12) @(negedge clk);
      end
    endtask
    task automatic extend_packet(input [31:0] index=0, input [255:0] value=0);
      header(32'h182,65);command[1]=2;
      {command[10],command[11],command[12],command[13]}=index;
      command[17]=9;
      {command[18],command[19],command[20],command[21]}=32'h40000009;
      command[30]=1;command[32]=8'h0b;
      for(integer n=0;n<32;n++) command[33+n]=value[255-n*8 -:8];
    endtask
    task automatic expect_extend;
      expected_header(19,0,16'h8002);expected[16]=1;
    endtask
    task automatic verify_bank;
      read_packet(24'hffffff);expect_read(24'hffffff);transact();
      read_packet(24'hffff00);expect_read(24'hffff00);transact();
      read_packet(24'hff0000);expect_read(24'hff0000);transact();
      if(counter!==expected_counter || commits!=expected_counter)
        $fatal(1,"Counter/commit mismatch");
    endtask
    task automatic reject(input [31:0] err);
      integer old_launches;
      old_launches=launches;
      expected_header(10,err);transact();
      if(old_launches!=launches) $fatal(1,"Rejected command launched mutation");
      if(operational) verify_bank();
    endtask
    initial begin
      for(integer n=0;n<24;n++) expected_bank[n]=0;
      #2;reset_n=1;#2;reset_n=0;repeat(4) @(negedge clk);reset_n=1;
      extend_packet();reject(32'h100);
      operational=1;
      if(!ENABLE_EXTEND) begin
        extend_packet();reject(32'h143);
        passed=1;$display("TPM2_PCR_EXTEND_DISABLED_PASS");$finish;
      end
      if(EMPTY_MASK==0) begin
        extend_packet();reject(32'h98e);
        passed=1;$display("TPM2_PCR_EXTEND_EMPTY_MASK_PASS");$finish;
      end
      verify_bank();
      extend_packet(32'd0,256'h000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f);
      expected_bank[0]=256'hbb2275c49f28ad52cae6d55e34a974a58c7a3ba26f976e8ecbbe7a536918dc73;expected_counter++;
      expect_extend();transact();verify_bank();
      extend_packet(32'd0,256'ha5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5);
      expected_bank[0]=256'h48215992c31177e416a98589ab2ff7642207d6e4ebb9e0133d046b849fe1e8ae;expected_counter++;
      expect_extend();transact();verify_bank();
      extend_packet(32'd8,256'h0909090909090909090909090909090909090909090909090909090909090909);
      expected_bank[8]=256'h20a7d6f6e88f212bd7a6d6098a6dcc93b83def3ea1f696fd81e72bae0edcc3cd;expected_counter++;
      expect_extend();transact();verify_bank();
      extend_packet(32'd15,256'h1010101010101010101010101010101010101010101010101010101010101010);
      expected_bank[15]=256'hb489021588a2f2a51343b40b45b82e62139c2bbd9dcafebaeff1fa85d8a97bf1;expected_counter++;
      expect_extend();transact();verify_bank();
      // Count zero and TPM_RH_NULL are successful no-ops.
      extend_packet();command[30]=0;command_size=31;command[5]=31;
      expect_extend();transact();verify_bank();
      extend_packet(32'h40000007);expect_extend();transact();verify_bank();
      // All rejected packets are followed by a full host read of all 24 PCRs.
      extend_packet(24);reject(32'h18b);
      extend_packet(32'h80000000);reject(32'h18b);
      extend_packet(16);reject(32'h98e); // no static empty-auth contract for PCR16
      extend_packet();command[17]=8;reject(32'h144);
      extend_packet();command[21]=8;reject(32'h98e); // HMAC session handle
      extend_packet();command[23]=1;reject(32'h98e); // nonce
      extend_packet();command[24]=8'h20;reject(32'h98e); // decrypt attribute
      extend_packet();command[26]=1;reject(32'h98e); // nonempty password
      extend_packet();command[0]=8'h70;
      expected_header(10,32'h1e,16'h00c4);transact();verify_bank();
      extend_packet();command[1]=1;reject(32'h125);
      extend_packet();command[30]=2;reject(32'h1d5);
      extend_packet();command[32]=4;reject(32'h1c3);
      extend_packet();command_size=64;command[5]=64;reject(32'h142);
      extend_packet();command_size=66;command[5]=66;reject(32'h142);
      extend_packet();command[30]=0;reject(32'h142); // trailing digest after count0
      extend_packet();command_size=31;command[5]=31;reject(32'h142); // missing digest
      for(integer n=0;n<8;n++) begin
        case(n) 0:locality=0;1:locality=2;2:locality=4;3:locality=8;
          4:locality=16;5:locality=3;6:locality=32;7:locality=8'hxx;endcase
        extend_packet();reject(32'h907);
      end
      locality=1;
      // Phase One must retain the submitting locality throughout execution.
      extend_packet(0,256'd0);
      expected_bank[0]=256'h32385950e2ab3ad85e2c1ac373841816448f5690dceb4aec62b84537f26aacd9;expected_counter++;
      expect_extend();
      fork
        begin wait(engine_state==10);@(negedge clk);locality=2;end
        begin transact();end
      join
      locality=1;verify_bank();
      // Clear continueSession is also valid for TPM_RS_PW.
      extend_packet(8,256'd0);command[24]=0;
      expected_bank[8]=256'h3580e674af4af9ede16509c7897f34084de7274427028f8108e9ace02b22236d;expected_counter++;
      expect_extend();transact();verify_bank();
      // Reset while Phase Two hashes cancels the in-flight job and clears the
      // volatile profile; a fresh command must complete after reset.
      extend_packet();send=1;@(negedge clk);send=0;
      wait(pcr_busy);repeat(15) @(negedge clk);
      reset_n=0;repeat(4) @(negedge clk);reset_n=1;
      expected_counter=0;commits=0;
      for(integer n=0;n<24;n++) expected_bank[n]=0;
      repeat(12) @(negedge clk);verify_bank();
      extend_packet(0,256'd0);
      expected_bank[0]=256'hf5a5fd42d16a20302798ef6ed309979b43003d2320d9f0e8ea9831a92759fb4b;expected_counter++;
      expect_extend();transact();verify_bank();
      // The reset-aborted command dispatches but deliberately never completes.
      if(accepted != completed+1 || dispatched != accepted) $fatal(1,"Lost engine ownership");
      $display("TPM2_PCR_EXTEND_COMMAND_PASS accepted=%0d dispatched=%0d completed=%0d",accepted,dispatched,completed);
      passed=1;$finish;
    end
    initial begin #30000000;$fatal(1,"PCR Extend command timeout");end
endmodule
