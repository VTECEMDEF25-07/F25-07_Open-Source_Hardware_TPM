`timescale 1ns/1ps
module tb_tpm2_pcr_command;
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
        if (hash_request) $fatal(1,"Read command unexpectedly requested SHA");
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
    execution_engine #(.ENABLE_HASH_COMMAND(1), .ENABLE_PCR_COMMANDS(1)) engine (
        .clock_i(clk), .reset_n_i(reset_n), .command_done_i(1'b1), .command_ready_i(execute), .op_state_i(operational ? 3'd3 : 3'd2),
        .command_tag_i(tag),
        .command_code_i(code),
        .command_size_i(command_size),
        .command_addr_o(exec_cmd_addr), .command_byte_i(exec_cmd_byte),
        .response_valid_o(ready), .response_code_o(rc), .response_length_o(engine_length), .current_state_o(engine_state),
        .response_addr_i(exec_rsp_addr), .response_byte_o(exec_rsp_byte),
        .hash_request_o(hash_request), .hash_grant_i(hash_grant), .hash_data_o(hash_data),
        .hash_valid_o(hash_valid), .hash_end_o(hash_end), .hash_ready_i(hash_ready),
        .pcr_read_index_o(pcr_index), .pcr_read_data_i(pcr_data),
        .pcr_read_valid_i(pcr_valid && bank_read_ok), .pcr_update_counter_i(counter),
        .hash_digest_i(digest), .hash_digest_valid_i(digest_valid), .hash_digest_ready_o(digest_ready)
    );
    pcr_registers bank (
        .clk(clk), .reset_n(reset_n), .read_index(pcr_index), .extend_index(5'd0),
        .read_data(pcr_data), .read_valid(pcr_valid), .extend_data(),
        .write_enable(bank_write), .write_index(bank_index), .write_data(bank_data),
        .update_counter(counter)
    );
    task automatic header(input [31:0] cc, input integer length);
      command_size=length;
      for(integer n=0;n<64;n++) command[n]=0;
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
    task automatic write_bank(input [4:0] index,input [255:0] value);
      @(negedge clk);bank_write=1;bank_index=index;bank_data=value;
      @(negedge clk);bank_write=0;
      if(index<24) begin expected_bank[index]=value;expected_counter++;end
      if(counter !== expected_counter) $fatal(1,"Invalid bank commit counter");
    endtask
    initial begin
      for(integer n=0;n<24;n++) expected_bank[n]=0;
      #2;reset_n=1;#2;reset_n=0;repeat(4) @(negedge clk);reset_n=1;
      read_packet(1);expected_header(10,32'h100);transact(); // before Startup
      operational=1;
      read_packet(24'h800101);expect_read(24'h800101);transact(); // reset PCR0,8,23
      // Distinct literal fixtures, including bytes with high bits and zeroes.
      write_bank(0,256'h000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f);
      write_bank(8,256'hffeeddccbbaa99887766554433221100ffeeddccbbaa99887766554433221100);
      write_bank(16,256'h0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef);
      write_bank(23,256'ha5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5);
      write_bank(31,256'hbad); // rejected address must not advance counter
      read_packet(24'h810101);expect_read(24'h810101);transact();
      read_packet(0);expect_read(0);transact();
      read_packet(0,1);expect_read(0,1);transact();
      read_packet(24'hffffff);expect_read(24'hffffff);transact(); // first 8, ascending
      read_packet(24'hffff00);expect_read(24'hffff00);transact(); // next 8
      read_packet(24'hff0000);expect_read(24'hff0000);transact(); // final 8
      cap_packet();expect_cap();transact();
      cap_packet(0);expect_cap(1);transact();
      cap_packet(32'hffffffff);expect_cap();transact();
      cap_packet(1,1);expected_header(10,32'h2c4);transact();
      cap_packet(1,0,6);expected_header(10,32'h1c4);transact();
      read_packet(1);command[15]=4;expected_header(10,32'h1c3);transact();
      read_packet(1);command[16]=2;expected_header(10,32'h1d5);transact();
      read_packet(1);command[16]=4;expected_header(10,32'h1d5);transact();
      read_packet(1);command[13]=2;expected_header(10,32'h1d5);transact();
      read_packet(1);command[10]=8'h80;expected_header(10,32'h1d5);transact();
      read_packet(1);command_size=19;command[5]=19;expected_header(10,32'h142);transact();
      read_packet(0,1);command_size=15;command[5]=15;expected_header(10,32'h142);transact();
      header(32'h17e,10);expected_header(10,32'h142);transact();
      header(32'h17e,4095);expected_header(10,32'h142);transact();
      cap_packet();command_size=21;command[5]=21;expected_header(10,32'h142);transact();
      read_packet(1);command[1]=2;expected_header(10,32'h145);transact();
      read_packet(1);command[0]=8'h70;expected_header(10,32'h1e,16'h00c4);transact();
      // Read failure does not leak a previous successful response.
      bank_read_ok=0;read_packet(1);expected_header(10,32'h101);transact();bank_read_ok=1;
      // A backend write during collection forces a complete snapshot retry.
      read_packet(24'h800001);
      fork
        begin
          wait(engine.pcr_command.state==4 && pcr_index==4);
          write_bank(0,256'hdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef);
        end
        begin
          // Prepare expected new generation before response comparison.
          expected_bank[0]=256'hdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef;
          expected_counter=5;expect_read(24'h800001);expected_counter=4;
          transact();
        end
      join
      // Same digest write is still a committed bank update.
      write_bank(0,expected_bank[0]);
      read_packet(1);expect_read(1);transact();
      if(accepted != completed || dispatched != accepted) $fatal(1,"Lost engine ownership");
      if(counter != 6) $fatal(1,"Reads/errors changed the bank counter");
      $display("TPM2_PCR_COMMAND_PASS accepted=%0d dispatched=%0d completed=%0d counter=%0d",accepted,dispatched,completed,counter);
      passed=1;$finish;
    end
    initial begin #20000000;$fatal(1,"PCR command timeout");end
endmodule
