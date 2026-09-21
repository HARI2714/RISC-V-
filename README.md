# RISC-V RV32I Single-Cycle Processor (Verilog)

A single-cycle implementation of a subset of the RISC-V RV32I instruction set, written in Verilog,
with a small Python assembler and a self-checking testbench.

> **Status: in progress.** The single-cycle core below is working and passing its tests in simulation.
> The pipelined version, full RV32I coverage and FPGA implementation are planned (see Roadmap).

---

## 1. What works today

| Category | Instructions |
|----------|--------------|
| R-type ALU | `add sub and or xor slt sll srl sra` |
| I-type ALU | `addi andi ori xori slti slli srli srai` |
| Memory | `lw`, `sw` (word-aligned) |
| Branch | `beq`, `bne` |
| Jump | `jal` |
| Upper immediate | `lui` |

Not yet implemented: `jalr`, `auipc`, `blt/bge/bltu/bgeu`, `sltu/sltiu`, byte/halfword loads and stores
(`lb/lh/lbu/lhu/sb/sh`), `fence`, `ecall/ebreak`, CSRs. Unsupported opcodes decode as a harmless no-op.

## 2. Architecture

Classic single-cycle datapath: every instruction fetches, decodes, executes, accesses memory and writes
back in one clock cycle.

```
            +-----+   +-------+    +---------+   +-----+   +--------+
  PC ------>| IMEM|-->| Decode|--->| RegFile |-->| ALU |-->|  DMEM  |--+
   ^        +-----+   |Control|    +---------+   +-----+   +--------+  |
   |                  |ImmGen |         ^                               |
   |                  +-------+         +----------- write-back mux <---+
   +---- PC+4 / PC+imm (branch, jal) ---+
```

| Module | File | Role |
|--------|------|------|
| `riscv_core` | `rtl/riscv_core.v` | Top level: PC register, wiring, branch logic, write-back mux |
| `control` | `rtl/control.v` | Main decoder (from opcode) and ALU control (from funct3/funct7) |
| `imm_gen` | `rtl/imm_gen.v` | Builds sign-extended immediates for I, S, B, U and J formats |
| `regfile` | `rtl/regfile.v` | 32 x 32-bit registers, 2 async read ports, 1 sync write port, `x0` hardwired to 0 |
| `alu` | `rtl/alu.v` | add, sub, and, or, xor, slt, sll, srl, sra |
| `imem` | `rtl/imem.v` | 256-word instruction memory (async read), loaded from a hex file by the testbench |
| `dmem` | `rtl/dmem.v` | 256-word data memory (async read, sync write) |

## 3. Code explanation

### 3.1 Instruction decode
A RISC-V instruction is 32 bits with fixed field positions, so the core simply slices it:

```verilog
wire [6:0] opcode = instr[6:0];
wire [4:0] rd     = instr[11:7];
wire [2:0] funct3 = instr[14:12];
wire [4:0] rs1    = instr[19:15];
wire [4:0] rs2    = instr[24:20];
wire [6:0] funct7 = instr[31:25];
```

### 3.2 Control unit
`control.v` looks at the opcode and sets the datapath control signals:

| Signal | Meaning |
|--------|---------|
| `reg_write` | Write the result into `rd` |
| `alu_src` | ALU operand B comes from the immediate (1) or from `rs2` (0) |
| `mem_write` | Store to data memory |
| `mem_to_reg` | Write-back data comes from data memory (loads) |
| `branch` | Instruction is a conditional branch |
| `jal` | Instruction is a jump-and-link |
| `lui` | Write the upper immediate directly |

The ALU operation is chosen from `funct3` (and `funct7[5]`, which separates `add/sub` and `srl/sra`).
For loads, stores and branches the ALU is forced to `ADD`, because it is used for address calculation.

### 3.3 Immediate generation
RISC-V scatters immediate bits differently per instruction format, and `imm_gen.v` reassembles them
and sign-extends. For example, the S-type (store) immediate is split across two fields:

```verilog
7'b0100011: imm = {{20{instr[31]}}, instr[31:25], instr[11:7]};   // S-type
```

and the branch (B-type) immediate has its bit order shuffled and an implicit zero LSB:

```verilog
7'b1100011: imm = {{19{instr[31]}}, instr[31], instr[7], instr[30:25], instr[11:8], 1'b0};
```

### 3.4 Register file
Two combinational read ports and one clocked write port. Register `x0` always reads as zero and
writes to it are ignored, which is required by the ISA:

```verilog
assign rd1 = (ra1 == 5'd0) ? 32'd0 : regs[ra1];
always @(posedge clk) if (we && wa != 5'd0) regs[wa] <= wd;
```

### 3.5 Datapath, branches and jumps
The ALU computes `rs1 op (imm or rs2)`. Branch conditions compare `rs1` and `rs2` directly:

```verilog
wire eq           = (rd1 == rd2);
wire branch_taken = branch && ((funct3 == 3'b000) ? eq : (funct3 == 3'b001) ? !eq : 1'b0);
wire [31:0] pc_next = (jal || branch_taken) ? (pc + imm) : (pc + 32'd4);
```

The write-back mux picks between `PC+4` (for `jal`, the link register), the upper immediate (`lui`),
load data, and the ALU result:

```verilog
assign wb_data = jal ? (pc + 32'd4) : lui ? imm : mem_to_reg ? dmem_rdata : alu_y;
```

### 3.6 Assembler (`tools/asm.py`)
A small two-pass Python assembler for the supported subset. The first pass records label addresses,
the second encodes each instruction into R/I/S/B/J/U format and writes one hex word per line for
`$readmemh`. It supports labels, `offset(reg)` addressing and `#` comments.

## 4. Verification

`tb/tb_riscv_core.v` is self-checking. It loads `programs/test_prog.hex` into instruction memory, runs
the program, then compares registers and memory against expected values.

The test program (`programs/test_prog.s`) covers:
- a loop summing 1 to 10 (`add`, `addi`, `bne`, backward branch) giving 55
- `sw` / `lw` round trip through data memory
- `sub and or xor slt sll slli srai` with known results, including a negative arithmetic shift
- `lui` (upper immediate)
- `jal` (checks link register value and that the skipped instruction does **not** execute)
- `beq` taken (checks the skipped instruction does not execute)
- `x0` stays zero

Result: **18 / 18 checks pass.**

```
RESULT: PASS (all checks)
```
<img width="885" height="537" alt="image" src="https://github.com/user-attachments/assets/c412d605-5d3b-4522-9cb2-2748a40c96f3" />
<img width="1867" height="843" alt="image" src="https://github.com/user-attachments/assets/c18e0b3b-c375-4039-ad77-fb07acf664ea" />


Sanity check of the testbench: breaking the `sub` decode on purpose makes the run fail on `x7`, so
the checks are actually able to catch bugs.

## 5. How to run

```
sudo apt install iverilog gtkwave python3
bash sim/run.sh          # assembles, compiles, simulates
gtkwave sim/riscv.vcd    # optional: view waveforms
```

To run your own program: write it in the supported subset, then
`python3 tools/asm.py my_prog.s programs/test_prog.hex` and rerun `sim/run.sh`.

## 6. Repository structure

```
riscv-singlecycle/
├── rtl/          alu.v, regfile.v, imm_gen.v, control.v, imem.v, dmem.v, riscv_core.v
├── tb/           tb_riscv_core.v
├── programs/     test_prog.s (source), test_prog.hex (assembled)
├── tools/        asm.py (mini assembler)
├── sim/          run.sh
└── README.md
```

## 7. Roadmap

- [x] Single-cycle core for the RV32I subset above, with assembler and self-checking testbench
- [ ] Complete RV32I: `jalr`, `auipc`, remaining branches, `sltu/sltiu`, byte/halfword memory access
- [ ] 5-stage pipeline (IF, ID, EX, MEM, WB)
- [ ] Hazard handling: data forwarding, load-use stall, branch flush
- [ ] Run the official RISC-V compliance tests
- [ ] FPGA implementation (ZedBoard) and synthesis / timing results
