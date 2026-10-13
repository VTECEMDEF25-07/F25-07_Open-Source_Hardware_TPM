// RV32I feasibility controller. Descriptor-only MMIO; no secret operand window.
// This module boots a self-test program, not RSA generation firmware.
module keygen_softcore_control #(
    parameter ROM_FILE = "softcore_boot.hex"
) (
    input wire clock_i, input wire reset_n_i, input wire execute_en_i,
    output wire ready_o, output wire trap_o, output wire instruction_progress_o,
    output wire command_valid_o, input wire command_ready_i,
    output wire [7:0] command_opcode_o,
    output wire [31:0] command_arg0_o, command_arg1_o, command_arg2_o, command_arg3_o,
    input wire response_valid_i, output wire response_ready_o,
    input wire [7:0] response_status_i,
    output wire [31:0] report_o
);
    reg [31:0] rom_reg [0:8191];
    reg [31:0] ram_reg [0:4095];
    reg [11:0] scrub_index_reg;
    reg scrub_done_reg;
    reg memory_ready_reg;
    reg [31:0] memory_read_reg;
    reg bus_fault_reg;
    reg command_valid_reg, busy_reg, done_reg;
    reg [7:0] command_opcode_reg, response_status_reg;
    reg [31:0] arg0_reg, arg1_reg, arg2_reg, arg3_reg, report_reg;
    wire cpu_reset_n = reset_n_i && scrub_done_reg && execute_en_i;
    wire memory_valid, memory_instruction, cpu_trap;
    wire [31:0] memory_address, memory_write;
    wire [3:0] memory_strobe;
    wire rom_select = memory_address < 32'h00008000;
    wire ram_select = memory_address >= 32'h10000000 && memory_address < 32'h10004000;
    wire mmio_select = memory_address >= 32'h40000000 && memory_address < 32'h40000020;
    wire write_access = |memory_strobe;
    wire ram_write_en = reset_n_i && (!scrub_done_reg ||
        (memory_valid && !memory_ready_reg && ram_select && write_access));
    wire [11:0] ram_write_address = scrub_done_reg ? memory_address[13:2] : scrub_index_reg;
    wire [31:0] ram_write_data = scrub_done_reg ? memory_write : 32'd0;
    wire [3:0] ram_write_strobe = scrub_done_reg ? memory_strobe : 4'b1111;
    integer byte_index;
    initial $readmemh(ROM_FILE, rom_reg);
    assign ready_o = reset_n_i && scrub_done_reg;
    assign instruction_progress_o = cpu_reset_n && memory_valid && memory_ready_reg && memory_instruction;
    assign trap_o = cpu_trap || bus_fault_reg;
    assign command_valid_o = cpu_reset_n && command_valid_reg;
    assign command_opcode_o = command_valid_o ? command_opcode_reg : 8'd0;
    assign command_arg0_o = command_valid_o ? arg0_reg : 32'd0;
    assign command_arg1_o = command_valid_o ? arg1_reg : 32'd0;
    assign command_arg2_o = command_valid_o ? arg2_reg : 32'd0;
    assign command_arg3_o = command_valid_o ? arg3_reg : 32'd0;
    assign response_ready_o = cpu_reset_n && busy_reg && !command_valid_reg && !done_reg;
    assign report_o = cpu_reset_n ? report_reg : 32'd0;

    picorv32 #(.ENABLE_COUNTERS(0), .ENABLE_COUNTERS64(0),
        .ENABLE_MUL(0), .ENABLE_DIV(0), .ENABLE_FAST_MUL(0),
        .ENABLE_PCPI(0), .ENABLE_IRQ(0), .ENABLE_TRACE(0),
        .COMPRESSED_ISA(0), .PROGADDR_RESET(32'd0), .STACKADDR(32'hffffffff)
    ) cpu (
        .clk(clock_i), .resetn(cpu_reset_n), .trap(cpu_trap),
        .mem_valid(memory_valid), .mem_instr(memory_instruction),
        .mem_ready(memory_ready_reg), .mem_addr(memory_address),
        .mem_wdata(memory_write), .mem_wstrb(memory_strobe), .mem_rdata(memory_read_reg),
        .mem_la_read(), .mem_la_write(), .mem_la_addr(), .mem_la_wdata(), .mem_la_wstrb(),
        .pcpi_valid(), .pcpi_insn(), .pcpi_rs1(), .pcpi_rs2(),
        .pcpi_wr(1'b0), .pcpi_rd(32'd0), .pcpi_wait(1'b0), .pcpi_ready(1'b0),
        .irq(32'd0), .eoi(), .trace_valid(), .trace_data()
    );

    // Scrub every RAM location before CPU release. Reset never relies on boot code.
    always @(posedge clock_i) begin
        if (!reset_n_i) begin
            scrub_index_reg <= 0;
            scrub_done_reg <= 0;
        end else if (!scrub_done_reg) begin
            if (scrub_index_reg == 12'd4095) scrub_done_reg <= 1;
            else scrub_index_reg <= scrub_index_reg + 1'b1;
        end
    end
    // A single physical write port serves both scrub and CPU byte writes.
    // Combining these here preserves block-RAM inference in Quartus.
    always @(posedge clock_i) begin
        if (ram_write_en) begin
            for (byte_index = 0; byte_index < 4; byte_index = byte_index + 1)
                if (ram_write_strobe[byte_index])
                    ram_reg[ram_write_address][byte_index*8 +: 8] <= ram_write_data[byte_index*8 +: 8];
        end
    end

    always @(posedge clock_i) begin
        if (!cpu_reset_n) begin
            memory_ready_reg <= 0; memory_read_reg <= 0; bus_fault_reg <= 0;
            command_valid_reg <= 0; command_opcode_reg <= 0;
            busy_reg <= 0; done_reg <= 0; response_status_reg <= 0;
            arg0_reg <= 0; arg1_reg <= 0; arg2_reg <= 0; arg3_reg <= 0; report_reg <= 0;
        end else begin
            memory_ready_reg <= 0;
            memory_read_reg <= 0;
            if (command_valid_o && command_ready_i) command_valid_reg <= 0;
            if (response_valid_i && response_ready_o) begin
                busy_reg <= 0; done_reg <= 1; response_status_reg <= response_status_i;
            end
            if (memory_valid && !memory_ready_reg) begin
                memory_ready_reg <= 1;
                if (rom_select && !write_access) memory_read_reg <= rom_reg[memory_address[14:2]];
                else if (ram_select) memory_read_reg <= ram_reg[memory_address[13:2]];
                else if (mmio_select && !memory_instruction) begin
                    if (write_access) begin
                        if (memory_strobe != 4'b1111) bus_fault_reg <= 1;
                        else case (memory_address[4:2])
                            3'd0: if (!busy_reg && !done_reg) begin
                                command_opcode_reg <= memory_write[7:0];
                                command_valid_reg <= 1; busy_reg <= 1;
                            end else bus_fault_reg <= 1;
                            3'd2: if (!busy_reg && !done_reg) arg0_reg <= memory_write; else bus_fault_reg <= 1;
                            3'd3: if (!busy_reg && !done_reg) arg1_reg <= memory_write; else bus_fault_reg <= 1;
                            3'd4: if (!busy_reg && !done_reg) arg2_reg <= memory_write; else bus_fault_reg <= 1;
                            3'd5: if (!busy_reg && !done_reg) arg3_reg <= memory_write; else bus_fault_reg <= 1;
                            3'd6: if (!busy_reg) begin done_reg <= 0; response_status_reg <= 0; end
                            3'd7: report_reg <= memory_write;
                            default: bus_fault_reg <= 1;
                        endcase
                    end else case (memory_address[4:2])
                        3'd1: memory_read_reg <= {16'd0, response_status_reg, 6'd0, done_reg, busy_reg};
                        3'd7: memory_read_reg <= report_reg;
                        default: bus_fault_reg <= 1;
                    endcase
                end else bus_fault_reg <= 1;
            end
        end
    end
endmodule
