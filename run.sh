#!/bin/bash
# Run from repo root:  bash sim/run.sh   (needs python3, iverilog, optionally gtkwave)
set -e
mkdir -p sim
python3 tools/asm.py programs/test_prog.s programs/test_prog.hex
iverilog -g2012 -o sim/riscv.vvp rtl/*.v tb/tb_riscv_core.v
vvp sim/riscv.vvp
echo "Waveform: gtkwave sim/riscv.vcd"
