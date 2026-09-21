// Main decoder + ALU control
module control (
    input  wire [6:0] opcode,
    input  wire [2:0] funct3,
    input  wire [6:0] funct7,
    output reg        reg_write,
    output reg        alu_src,     // 1: ALU operand B = immediate
    output reg        mem_write,
    output reg        mem_to_reg,  // 1: write-back from data memory
    output reg        branch,
    output reg        jal,
    output reg        lui,
    output reg [3:0]  alu_ctrl
);
    localparam ALU_ADD = 4'd0, ALU_SUB = 4'd1, ALU_AND = 4'd2, ALU_OR  = 4'd3,
               ALU_XOR = 4'd4, ALU_SLT = 4'd5, ALU_SLL = 4'd6, ALU_SRL = 4'd7,
               ALU_SRA = 4'd8;

    wire is_r = (opcode == 7'b0110011);
    wire is_i = (opcode == 7'b0010011);

    reg [3:0] alu_dec;
    always @* begin
        case (funct3)
            3'b000: alu_dec = (is_r && funct7[5]) ? ALU_SUB : ALU_ADD;
            3'b001: alu_dec = ALU_SLL;
            3'b010: alu_dec = ALU_SLT;
            3'b100: alu_dec = ALU_XOR;
            3'b101: alu_dec = funct7[5] ? ALU_SRA : ALU_SRL;
            3'b110: alu_dec = ALU_OR;
            3'b111: alu_dec = ALU_AND;
            default: alu_dec = ALU_ADD;
        endcase
    end

    always @* begin
        reg_write = 0; alu_src = 0; mem_write = 0; mem_to_reg = 0;
        branch = 0; jal = 0; lui = 0;
        alu_ctrl = (is_r || is_i) ? alu_dec : ALU_ADD;
        case (opcode)
            7'b0110011: reg_write = 1;                                   // R-type
            7'b0010011: begin reg_write = 1; alu_src = 1; end            // I-type ALU
            7'b0000011: begin reg_write = 1; alu_src = 1; mem_to_reg = 1; end // LW
            7'b0100011: begin alu_src = 1; mem_write = 1; end            // SW
            7'b1100011: branch = 1;                                      // BEQ / BNE
            7'b1101111: begin reg_write = 1; jal = 1; end                // JAL
            7'b0110111: begin reg_write = 1; lui = 1; end                // LUI
            default: ;
        endcase
    end
endmodule
