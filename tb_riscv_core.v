`timescale 1ns/1ps
// Self-checking testbench: loads programs/test_prog.hex, runs it, checks registers and memory.
module tb_riscv_core;
    reg clk = 0, rst_n = 0;
    riscv_core dut (.clk(clk), .rst_n(rst_n));
    always #5 clk = ~clk;

    integer errors = 0;

    task check(input [255:0] name, input [31:0] actual, input [31:0] expected);
        begin
            if (actual === expected)
                $display("  PASS  %-10s = 0x%08h", name, actual);
            else begin
                $display("  FAIL  %-10s = 0x%08h (expected 0x%08h)", name, actual, expected);
                errors = errors + 1;
            end
        end
    endtask

    initial begin
        $dumpfile("sim/riscv.vcd"); $dumpvars(0, tb_riscv_core);
        $readmemh("programs/test_prog.hex", dut.u_imem.mem);
        repeat (3) @(negedge clk);
        rst_n = 1;
        repeat (120) @(negedge clk);      // program finishes well before this, then spins in 'done'

        $display("---- Register / memory check ----");
        check("x1  sum",   dut.u_rf.regs[1],  32'd55);
        check("x4  lw",    dut.u_rf.regs[4],  32'd55);
        check("x7  sub",   dut.u_rf.regs[7],  32'd10);
        check("x8  and",   dut.u_rf.regs[8],  32'd5);
        check("x9  or",    dut.u_rf.regs[9],  32'd15);
        check("x10 xor",   dut.u_rf.regs[10], 32'd10);
        check("x11 slt",   dut.u_rf.regs[11], 32'd1);
        check("x12 sll",   dut.u_rf.regs[12], 32'd480);
        check("x13 slli",  dut.u_rf.regs[13], 32'd20);
        check("x14 srai",  dut.u_rf.regs[14], 32'hFFFFFFFC);
        check("x15 addi-", dut.u_rf.regs[15], 32'hFFFFFFF0);
        check("x16 lui",   dut.u_rf.regs[16], 32'h12345000);
        check("x17 jal lr",dut.u_rf.regs[17], 32'h00000054);
        check("x18 skip",  dut.u_rf.regs[18], 32'd0);
        check("x19",       dut.u_rf.regs[19], 32'd7);
        check("x20 skip",  dut.u_rf.regs[20], 32'd0);
        check("x0 zero",   dut.u_rf.regs[0],  32'd0);
        check("dmem[0]",   dut.u_dmem.mem[0], 32'd55);

        $display("--------------------------------");
        if (errors == 0) $display("RESULT: PASS (all checks)");
        else             $display("RESULT: FAIL (%0d errors)", errors);
        $finish;
    end
endmodule
