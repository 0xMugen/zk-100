# ZK-100 — Rules of the Game

## Overview

ZK-100 is a parallel programming puzzle game where you program a grid of **tiny compute nodes** to transform an **input stream** into an **output stream** according to challenge specifications.

### Key Concepts
- Each node runs a small **assembly-like program** you write
- All programs execute **in parallel**, cycle by cycle
- Nodes communicate via message ports with neighbors
- Special nodes connect to the outside world (`IN`, `OUT`)
- Your score reflects **solution efficiency** (cycles, messages, nodes)

---

## Grid Architecture

### Layout
- **Grid Size**: 2×2 (4 nodes total)
- **Node Coordinates**: (0,0), (0,1), (1,0), (1,1)

### Node Components
Each node contains:

#### Registers
| Register | Purpose | Type |
|----------|---------|------|
| `ACC` | Main accumulator register | Integer |
| `BAK` | Backup storage register | Integer |
| `LAST` | Stores last port used for `MOV` | Port reference |

#### Flags
- `Z` flag: Set when ACC = 0
- `N` flag: Set when ACC < 0

#### Program Storage
- Up to **32 instructions** per node
- **Program Counter (PC)** tracks current instruction

### Special Node Roles
- **Node (0,0)**: Has `IN` port (reads from input stream)
- **Node (1,1)**: Has `OUT` port (writes to output stream)

---

## Execution Model

The ZK-100 operates in **lock-step cycles** where all nodes execute simultaneously.

### Cycle Execution Steps

1. **Instruction Read**: Every non-halted node reads its current instruction
2. **Execution Phase**:
   - **Non-blocking instructions** (math, jumps, NOP) → Execute immediately
   - **MOV with ports** → May block until communication partner is ready
3. **Communication Matching**:
   - Example: Node A executes `MOV ACC, RIGHT` while Node B executes `MOV LEFT, ACC`
   - Result: Transfer succeeds, both nodes advance
   - If no match: Node waits (PC doesn't advance)
4. **PC Update**: Increment or jump to target
5. **Halt Check**: Nodes with `HLT` become permanently inactive

### System States
- **Running**: At least one node is active
- **Halted**: All nodes have executed `HLT`
- **Deadlocked**: All active nodes are blocked (system stuck)

---

## Communication System

### Port Types

#### Directional Ports
- `UP`, `DOWN`, `LEFT`, `RIGHT` - Connect to adjacent nodes
- `LAST` - References the last port used in a `MOV` operation

#### Special Ports
| Port | Location | Function | Blocking |
|------|----------|----------|----------|
| `IN` | Node (0,0) only | Reads input stream | Blocks when empty |
| `OUT` | Node (1,1) only | Writes to output | Never blocks |
| `NIL` | All nodes | Null port (returns 0/discards) | Never blocks |

### Channel Properties
- Each channel between nodes has **1-slot capacity**
- Transfers require **simultaneous matching** operations
- Unmatched operations cause the initiating node to **block**

---

## Instruction Set

### Data Movement
```asm
MOV SRC, DST    ; Move value from source to destination
```

### Arithmetic Operations
```asm
ADD SRC         ; ACC = ACC + SRC
SUB SRC         ; ACC = ACC - SRC
NEG             ; ACC = -ACC
```

### Register Management
```asm
SAV             ; BAK = ACC (save accumulator)
SWP             ; Swap ACC ↔ BAK
```

### Control Flow
```asm
JMP LABEL       ; Unconditional jump
JZ  LABEL       ; Jump if ACC == 0
JNZ LABEL       ; Jump if ACC != 0
JGZ LABEL       ; Jump if ACC > 0
JLZ LABEL       ; Jump if ACC < 0
```

### System Control
```asm
NOP             ; No operation (advance PC only)
HLT             ; Halt this node permanently
```

### Operand Types

**Sources (SRC)**:
- `ACC` - Accumulator value
- `[number]` - Literal integer
- `NIL` - Always returns 0
- `IN` - Input stream (node 0,0 only)
- `[PORT]` - Port value
- `LAST` - Last used port

**Destinations (DST)**:
- `ACC` - Accumulator
- `NIL` - Discard value
- `OUT` - Output stream (node 1,1 only)
- `[PORT]` - Send to port
- `LAST` - Last used port

---

## Program Structure

### Assembly Format
```asm
#NODE 0,0
MOV IN, RIGHT
HLT

#NODE 0,1
MOV LEFT, DOWN
HLT

#NODE 1,0
MOV UP, RIGHT
HLT

#NODE 1,1
loop:
    MOV LEFT, ACC
    ADD 1
    MOV ACC, OUT
    JMP loop
```

### Labels
- Define with `label:` syntax
- Jump targets for control flow
- Scoped to individual nodes

---

## Scoring System

### Metrics
1. **Cycles**: Total clock cycles until system halt
2. **Messages**: Count of successful inter-node transfers
3. **Nodes Used**: Nodes containing non-NOP instructions

### Score Calculation
```
score = cycles + (5 × nodes_used) + (messages ÷ 4)
```

Lower scores indicate more efficient solutions.

---

## Challenge Format

### Challenge Components
- **Seed**: Generates deterministic input stream
- **Expected Output**: Required output sequence
- **Verification**: Via interpreter or ZK proof

### Example Challenge
**Task**: Increment each input by 1

**Input Stream**: `[3, 5, -1]`  
**Expected Output**: `[4, 6, 0]`

**Solution Metrics**:
- Cycles: 60
- Nodes Used: 3
- Messages: 9
- **Final Score**: 60 + (5×3) + (9÷4) = 77.25

---

## Quick Reference

### Blocking Operations
- ✅ Never blocks: `ACC`, `NIL`, literals
- ⚠️ May block: Ports, `IN`, `LAST`
- ❌ Always blocks when empty: `IN`

### Common Patterns
```asm
; Pass-through
MOV LEFT, RIGHT

; Accumulate and forward
MOV LEFT, ACC
ADD ACC
MOV ACC, RIGHT

; Conditional routing
MOV LEFT, ACC
JGZ positive
MOV ACC, DOWN
JMP done
positive:
MOV ACC, UP
done:
```
