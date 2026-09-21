#!/usr/bin/env python3
"""Tiny assembler for the RV32I subset supported by this core.
Usage: python3 tools/asm.py programs/test_prog.s programs/test_prog.hex
Writes one 32-bit hex word per line (for $readmemh) and prints a listing."""
import sys, re

R = {'add':(0,0),'sub':(0,0x20),'sll':(1,0),'slt':(2,0),'xor':(4,0),
     'srl':(5,0),'sra':(5,0x20),'or':(6,0),'and':(7,0)}
I = {'addi':0,'slti':2,'xori':4,'ori':6,'andi':7}
SH = {'slli':(1,0),'srli':(5,0),'srai':(5,0x20)}

def reg(s):
    s = s.strip()
    assert re.fullmatch(r'x([0-9]|[12][0-9]|3[01])', s), f'bad register {s}'
    return int(s[1:])

def num(s): return int(s.strip(), 0)

def enc_r(f7,rs2,rs1,f3,rd,op): return (f7<<25)|(rs2<<20)|(rs1<<15)|(f3<<12)|(rd<<7)|op
def enc_i(imm,rs1,f3,rd,op):    return ((imm&0xFFF)<<20)|(rs1<<15)|(f3<<12)|(rd<<7)|op
def enc_s(imm,rs2,rs1,f3,op):
    imm &= 0xFFF
    return ((imm>>5)<<25)|(rs2<<20)|(rs1<<15)|(f3<<12)|((imm&0x1F)<<7)|op
def enc_b(imm,rs2,rs1,f3,op):
    imm &= 0x1FFF
    return (((imm>>12)&1)<<31)|(((imm>>5)&0x3F)<<25)|(rs2<<20)|(rs1<<15)|(f3<<12)|(((imm>>1)&0xF)<<8)|(((imm>>11)&1)<<7)|op
def enc_j(imm,rd,op):
    imm &= 0x1FFFFF
    return (((imm>>20)&1)<<31)|(((imm>>1)&0x3FF)<<21)|(((imm>>11)&1)<<20)|(((imm>>12)&0xFF)<<12)|(rd<<7)|op

def main(src, dst):
    lines, labels, pc = [], {}, 0
    for raw in open(src):
        line = raw.split('#')[0].strip()
        if not line: continue
        while ':' in line:
            lab, line = line.split(':', 1)
            labels[lab.strip()] = pc
            line = line.strip()
        if line:
            lines.append((pc, line)); pc += 4
    words = []
    for pc, line in lines:
        m, _, rest = line.partition(' ')
        m = m.lower(); a = [x.strip() for x in rest.split(',')] if rest else []
        if m in R:
            f3, f7 = R[m]; w = enc_r(f7, reg(a[2]), reg(a[1]), f3, reg(a[0]), 0x33)
        elif m in I:
            w = enc_i(num(a[2]), reg(a[1]), I[m], reg(a[0]), 0x13)
        elif m in SH:
            f3, f7 = SH[m]; w = enc_i((f7<<5)|(num(a[2])&0x1F), reg(a[1]), f3, reg(a[0]), 0x13)
        elif m == 'lw':
            off, base = re.fullmatch(r'(-?\w+)\((x\d+)\)', a[1]).groups()
            w = enc_i(num(off), reg(base), 2, reg(a[0]), 0x03)
        elif m == 'sw':
            off, base = re.fullmatch(r'(-?\w+)\((x\d+)\)', a[1]).groups()
            w = enc_s(num(off), reg(a[0]), reg(base), 2, 0x23)
        elif m in ('beq', 'bne'):
            w = enc_b(labels[a[2]] - pc, reg(a[1]), reg(a[0]), 0 if m == 'beq' else 1, 0x63)
        elif m == 'jal':
            w = enc_j(labels[a[1]] - pc if a[1] in labels else num(a[1]), reg(a[0]), 0x6F)
        elif m == 'lui':
            w = ((num(a[1]) & 0xFFFFF) << 12) | (reg(a[0]) << 7) | 0x37
        elif m == 'nop':
            w = 0x13
        else:
            sys.exit(f'unsupported instruction: {line}')
        words.append(w)
        print(f'{pc:04x}: {w:08x}   {line}')
    with open(dst, 'w') as f:
        for w in words: f.write(f'{w:08x}\n')
        for _ in range(256 - len(words)): f.write('00000013\n')   # pad with NOPs to fill imem

if __name__ == '__main__':
    if len(sys.argv) != 3: sys.exit(__doc__)
    main(sys.argv[1], sys.argv[2])
