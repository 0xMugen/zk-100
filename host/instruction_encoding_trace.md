# Cairo Instruction Encoding and Merkle Tree Analysis

## Overview

This document traces through exactly how Cairo encodes instructions and builds the merkle tree for the proof system.

## Instruction Encoding Format

Both Rust host and Cairo VM use the same encoding format:
```
32-bit encoding: lit(8) | src_port(2) | dst_port(2) | op(4) | src(8) | dst(8)

Bit layout:
- Bits 31-24: Literal value (8 bits) - for Src::Lit operands
- Bits 23-22: Source port tag (2 bits) - for Src::P operands
- Bits 21-20: Destination port tag (2 bits) - for Dst::P operands  
- Bits 19-16: Operation code (4 bits)
- Bits 15-8: Source type (8 bits)
- Bits 7-0: Destination type (8 bits)
```

## Operation Codes (Op enum)
```
Mov = 1    Add = 2    Sub = 3    Neg = 4
Sav = 5    Swp = 6    Jmp = 7    Jz = 8
Jnz = 9    Jgz = 10   Jlz = 11   Nop = 12
Hlt = 13
```

## Source Type Codes (Src enum)
```
Lit(_) = 0   Acc = 1    Nil = 2    In = 3
P(_) = 4     Last = 5
```

## Destination Type Codes (Dst enum)  
```
Acc = 0    Nil = 1    Out = 2    P(_) = 3    Last = 4
```

## Port Tags (PortTag enum)
```
Up = 0    Down = 1    Left = 2    Right = 3
```

## Encoding Examples

### 1. NOP Instruction
```
NOP => Inst { op: Op::Nop, src: Src::Nil, dst: Dst::Nil }

Encoding breakdown:
- lit: 0 (no literal)
- src_port: 0 (not a port)
- dst_port: 0 (not a port)
- op: 12 (Nop)
- src: 2 (Nil)
- dst: 1 (Nil)

Binary: 0000_0000 | 00 | 00 | 1100 | 0000_0010 | 0000_0001
Hex: 0x00C0201

Rust: nop.encode() = 0x00C0201
Cairo: encode_instruction(@nop) = 0x00C0201
```

### 2. MOV 42 OUT
```
MOV 42 OUT => Inst { op: Op::Mov, src: Src::Lit(42), dst: Dst::Out }

Encoding breakdown:
- lit: 42 (0x2A)
- src_port: 0 (not a port)
- dst_port: 0 (not a port)
- op: 1 (Mov)
- src: 0 (Lit)
- dst: 2 (Out)

Binary: 0010_1010 | 00 | 00 | 0001 | 0000_0000 | 0000_0010
Hex: 0x2A010002

Rust: mov_lit.encode() = 0x2A010002
Cairo: encode_instruction(@mov_lit) = 0x2A010002
```

### 3. HLT Instruction
```
HLT => Inst { op: Op::Hlt, src: Src::Nil, dst: Dst::Nil }

Encoding breakdown:
- lit: 0 (no literal)
- src_port: 0 (not a port)
- dst_port: 0 (not a port)
- op: 13 (Hlt)
- src: 2 (Nil)
- dst: 1 (Nil)

Binary: 0000_0000 | 00 | 00 | 1101 | 0000_0010 | 0000_0001
Hex: 0x00D0201

Rust: hlt.encode() = 0x00D0201
Cairo: encode_instruction(@hlt) = 0x00D0201
```

### 4. MOV P:LEFT ACC (Port Communication)
```
MOV P:LEFT ACC => Inst { op: Op::Mov, src: Src::P(PortTag::Left), dst: Dst::Acc }

Encoding breakdown:
- lit: 0 (no literal)
- src_port: 2 (Left)
- dst_port: 0 (not a port)
- op: 1 (Mov)
- src: 4 (P)
- dst: 0 (Acc)

Binary: 0000_0000 | 10 | 00 | 0001 | 0000_0100 | 0000_0000
Hex: 0x00810400

Rust: mov_port.encode() = 0x00810400
Cairo: encode_instruction(@mov_port) = 0x00810400
```

## Merkle Tree Construction

### 1. Program Words Format
For a 2x2 grid of nodes, `prog_words` array contains:
```
[node00_len, ...node00_instructions, 
 node01_len, ...node01_instructions,
 node10_len, ...node10_instructions,
 node11_len, ...node11_instructions]
```

### 2. Merkle Tree Building Process

#### Step 1: Encode each instruction as felt252
- Each instruction is encoded using the format above
- Result is cast to u128/felt252 for Cairo processing

#### Step 2: Build per-node merkle roots
For each node's program:
- If empty: merkle root = 0
- If non-empty: merkle_root([encoded_inst1, encoded_inst2, ...])

#### Step 3: Build final merkle root
- Collect all 4 node merkle roots: [node00_root, node01_root, node10_root, node11_root]
- Compute final: merkle_root([node00_root, node01_root, node10_root, node11_root])

### 3. Merkle Root Algorithm
```
merkle_root(leaves):
  if leaves.is_empty(): return 0
  if leaves.len() == 1: return leaves[0]
  
  // Pad to power of 2
  while len < next_power_of_2:
    leaves.append(0)
  
  // Build tree bottom-up
  while leaves.len() > 1:
    next_level = []
    for i in 0..leaves.len() step 2:
      left = leaves[i]
      right = leaves[i+1] or 0
      hash = hash_pair(left, right)
      next_level.append(hash)
    leaves = next_level
  
  return leaves[0]
```

### 4. Hash Function
The system uses a simplified Blake2s implementation:
```
hash_pair(left, right):
  data = [left, right]
  hash = blake2s_hash(data)
  return blake2s_to_felt(hash)
```

## Empty Program Handling

Empty programs are handled specially:
1. In `prog_words`: length = 0, no instruction words follow
2. In merkle tree: empty program contributes merkle root = 0
3. A grid with all empty programs has final merkle root = 0

## Example: Simple Program Trace

Given assembly:
```
NODE (0,0)
NOP
MOV 42 OUT
HLT
```

Encoding process:
1. Instructions encoded:
   - NOP: 0x00C0201
   - MOV 42 OUT: 0x2A010002  
   - HLT: 0x00D0201

2. prog_words array:
   ```
   [3, 0x00C0201, 0x2A010002, 0x00D0201,  // node (0,0)
    0,                                     // node (0,1) empty
    0,                                     // node (1,0) empty
    0]                                     // node (1,1) empty
   ```

3. Merkle tree:
   - node00_root = merkle_root([0x00C0201, 0x2A010002, 0x00D0201])
   - node01_root = 0
   - node10_root = 0  
   - node11_root = 0
   - final_root = merkle_root([node00_root, 0, 0, 0])

The final merkle root is then passed to Cairo as part of the proof inputs.