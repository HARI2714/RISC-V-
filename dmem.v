// Data memory: 256 words, word-aligned, asynchronous read, synchronous write
module dmem (
    input  wire        clk,
    input  wire        we,
    input  wire [31:0] addr,
    input  wire [31:0] wdata,
    output wire [31:0] rdata
);
    reg [31:0] mem [0:255];
    integer i;
    initial for (i = 0; i < 256; i = i + 1) mem[i] = 32'd0;
    assign rdata = mem[addr[9:2]];
    always @(posedge clk) if (we) mem[addr[9:2]] <= wdata;
endmodule
