// Single-cycle RV32I subset core.
// Supported: ADD SUB AND OR XOR SLT SLL SRL SRA | ADDI ANDI ORI XORI SLTI SLLI SRLI SRAI
//            LW SW | BEQ BNE | JAL | LUI
module riscv_core (
    input wire clk,
    input wire rst_n
);
    // ---------------- Fetch ----------------
    reg  [31:0] pc;
    wire [31:0] instr;
    imem u_imem (.addr(pc), .instr(instr));

    // ---------------- Decode ----------------
    wire [6:0] opcode = instr[6:0];
    wire [4:0] rd     = instr[11:7];
    wire [2:0] funct3 = instr[14:12];
    wire [4:0] rs1    = instr[19:15];
    wire [4:0] rs2    = instr[24:20];
    wire [6:0] funct7 = instr[31:25];

    wire        reg_write, alu_src, mem_write, mem_to_reg, branch, jal, lui;
    wire [3:0]  alu_ctrl;
    control u_ctrl (.opcode(opcode), .funct3(funct3), .funct7(funct7),
                    .reg_write(reg_write), .alu_src(alu_src), .mem_write(mem_write),
                    .mem_to_reg(mem_to_reg), .branch(branch), .jal(jal), .lui(lui),
                    .alu_ctrl(alu_ctrl));

    wire [31:0] imm;
    imm_gen u_imm (.instr(instr), .imm(imm));

    wire [31:0] rd1, rd2, wb_data;
    regfile u_rf (.clk(clk), .we(reg_write), .ra1(rs1), .ra2(rs2), .wa(rd),
                  .wd(wb_data), .rd1(rd1), .rd2(rd2));

    // ---------------- Execute ----------------
    wire [31:0] alu_b = alu_src ? imm : rd2;
    wire [31:0] alu_y;
    alu u_alu (.a(rd1), .b(alu_b), .ctrl(alu_ctrl), .y(alu_y));

    wire eq           = (rd1 == rd2);
    wire branch_taken = branch && ((funct3 == 3'b000) ? eq : (funct3 == 3'b001) ? !eq : 1'b0);

    // ---------------- Memory ----------------
    wire [31:0] dmem_rdata;
    dmem u_dmem (.clk(clk), .we(mem_write), .addr(alu_y), .wdata(rd2), .rdata(dmem_rdata));

    // ---------------- Write-back ----------------
    assign wb_data = jal        ? (pc + 32'd4) :
                     lui        ? imm          :
                     mem_to_reg ? dmem_rdata   : alu_y;

    // ---------------- Next PC ----------------
    wire [31:0] pc_next = (jal || branch_taken) ? (pc + imm) : (pc + 32'd4);
    always @(posedge clk or negedge rst_n)
        if (!rst_n) pc <= 32'd0;
        else        pc <= pc_next;
endmodule
