// 32 x 32-bit register file, 2 async read ports, 1 sync write port. x0 is hardwired to 0.
module regfile (
    input  wire        clk,
    input  wire        we,
    input  wire [4:0]  ra1, ra2, wa,
    input  wire [31:0] wd,
    output wire [31:0] rd1, rd2
);
    reg [31:0] regs [0:31];
    integer i;
    initial for (i = 0; i < 32; i = i + 1) regs[i] = 32'd0;

    assign rd1 = (ra1 == 5'd0) ? 32'd0 : regs[ra1];
    assign rd2 = (ra2 == 5'd0) ? 32'd0 : regs[ra2];

    always @(posedge clk)
        if (we && wa != 5'd0) regs[wa] <= wd;
endmodule
