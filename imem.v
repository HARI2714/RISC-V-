// Instruction memory: 256 words, asynchronous read, loaded by the testbench ($readmemh)
module imem (
    input  wire [31:0] addr,
    output wire [31:0] instr
);
    reg [31:0] mem [0:255];
    integer i;
    initial for (i = 0; i < 256; i = i + 1) mem[i] = 32'h00000013; // NOP (addi x0,x0,0)
    assign instr = mem[addr[9:2]];
endmodule
