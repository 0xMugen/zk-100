# ZK-100 Zero Knowledge Proof Game

## Overview

ZK-100 is a parallel programming puzzle game where you program a grid of **tiny compute nodes** to transform an **input stream** into an **output stream** according to challenge specifications. Your programs are proven using zero-knowledge proofs via the STWO proving system.

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
1. **Execute current instruction** on each node
2. **Resolve port communications** between nodes
3. **Increment PC** if not jumping
4. **Repeat until all nodes HLT** or max cycles reached

### Maximum Limits
- **4,096 cycles** per execution
- **32 instructions** per node
- **2,048 port messages** total

---

## Instruction Set

### Data Movement
| Instruction | Effect | Cycles |
|-------------|---------|--------|
| `MOV src, dst` | Copy value from source to destination | 1 |
| `SWP` | Swap ACC and BAK | 1 |
| `SAV` | Copy ACC to BAK | 1 |

### Arithmetic
| Instruction | Effect | Cycles |
|-------------|---------|--------|
| `ADD src` | ACC = ACC + src | 1 |
| `SUB src` | ACC = ACC - src | 1 |
| `NEG` | ACC = -ACC | 1 |

### Control Flow
| Instruction | Effect | Cycles |
|-------------|---------|--------|
| `JMP label` | Jump unconditionally | 1 |
| `JEZ label` | Jump if ACC = 0 | 1 |
| `JZ label` | Jump if ACC = 0 | 1 |
| `JNZ label` | Jump if ACC ≠ 0 | 1 |
| `JGZ label` | Jump if ACC > 0 | 1 |
| `JLZ label` | Jump if ACC < 0 | 1 |

### Special
| Instruction | Effect | Cycles |
|-------------|---------|--------|
| `NOP` | Do nothing | 1 |
| `HLT` | Stop execution | 0 |

### Operand Types
| Operand | Description |
|---------|-------------|
| `ACC` | Accumulator register |
| `BAK` | Backup register |
| `NIL` | Null value (absorbs writes) |
| `IN` | Input port (node 0,0 only) |
| `OUT` | Output port (node 1,1 only) |
| `UP` | Port to node above |
| `DOWN` | Port to node below |
| `LEFT` | Port to node left |
| `RIGHT` | Port to node right |
| `-999..999` | Integer literal |
| `label` | Jump target |

---

## Message Passing

Port connections enable **inter-node communication**:

### Writing to Ports
- Writing to port **blocks until read** by neighbor
- Cannot skip blocked writes (no write combining)
- Writing to **missing neighbor = NIL**
- Writing to NIL **discards value**

### Reading from Ports
- Reading from port **blocks until written** by neighbor
- Cannot skip blocked reads (must wait)
- Reading from **missing neighbor = 0**

### Deadlock Prevention
To avoid deadlock in communication:
- Design complementary send/receive patterns
- Ensure nodes alternate roles per cycle
- Use branching to handle conditional messages

---

## Scoring System

Solutions are scored on **efficiency metrics**:

| Metric | Description |
|--------|-------------|
| **Cycles** | Total cycles until completion |
| **Instructions** | Total instructions across all nodes |
| **Messages** | Total port communications |
| **Nodes Used** | Count of programmed nodes |

Lower scores = better optimization!

---

## Advanced Features

### Zero-Knowledge Proofs
All program executions are verified using the **STWO proving system**:
- Programs are compiled to Cairo bytecode
- Execution traces are proven without revealing internal state
- Proofs verify correct transformation of inputs to outputs

### Merkle Tree Commitments
Programs are committed using **Poseidon hash** merkle trees:
- Each node's program forms a leaf
- Tree root serves as program commitment
- Ensures program integrity in proofs

---

## Example Programs

### Simple Pass-Through (Node 0,0 → 1,1)
```asm
; Node (0,0) - Read and send
loop:
MOV IN, RIGHT
JMP loop

; Node (0,1) - Forward horizontally  
loop:
MOV LEFT, DOWN
JMP loop

; Node (1,0) - Forward vertically
loop:  
MOV UP, RIGHT
JMP loop

; Node (1,1) - Output result
loop:
MOV LEFT, OUT
JMP loop
```

### Negation Pipeline
```asm
; Node (0,0) - Read input
loop:
MOV IN, ACC
NEG
MOV ACC, RIGHT
JMP loop

; Node (1,1) - Write output
loop:
MOV LEFT, OUT  
JMP loop
```

### Conditional Router
```asm
; Node (0,0) - Test and route
loop:
MOV IN, ACC
JGZ send_right
MOV ACC, DOWN
JMP loop
send_right:
MOV ACC, RIGHT
JMP loop
```

## Advanced Techniques

### Label Usage
```asm
; Factorial calculator
start:
MOV 5, ACC      ; n = 5
MOV 1, BAK      ; result = 1

loop:
JEZ done        ; if n == 0, done
MUL BAK         ; result *= n
MOV ACC, BAK    ; save result
SUB 1           ; n--
JMP loop

done:
MOV BAK, OUT    ; output result
HLT
```

### Port Handshaking  
```asm
; Synchronized exchange
MOV 42, ACC
MOV ACC, RIGHT  ; Send first
MOV LEFT, ACC   ; Then receive

; Partner must do opposite:
MOV LEFT, ACC   ; Receive first  
MOV 99, ACC
MOV ACC, RIGHT  ; Then send
```

### Conditional Routing
```asm
; Conditional routing
MOV LEFT, ACC
JGZ positive
MOV ACC, DOWN
JMP done
positive:
MOV ACC, UP
done:
```

---

## Running the Game

### Frontend (Local Proof Game)

The frontend provides a visual interface for writing ZK-100 programs:

```bash
cd frontend
bun install
bun run dev
```

This opens a web interface where you can:
1. Write assembly code for each node
2. Set input values and expected outputs
3. Generate local commands to execute and prove your programs

### Backend (Rust Host)

To run programs directly from the command line:

```bash
cd host

# Assemble a program
cargo run --release -- assemble program.asm -i 1,2,3 -e 3,2,1

# Execute via Cairo (for debugging)
cd ../crates/exec
scarb execute --arguments-file ../../host/args.json --print-program-output

# Generate a zero-knowledge proof
cd ../../host
cargo run --release -- prove program.asm -i 1,2,3 -e 3,2,1
```

### Program Format

Programs are written in `.asm` files with node sections:

```asm
NODE (0,0)
MOV IN, RIGHT
HLT

NODE (1,1)  
MOV LEFT, OUT
HLT
```

### Architecture

- **Rust Host**: Assembles programs, generates merkle commitments
- **Cairo VM**: Executes programs with cryptographic constraints
- **STWO Prover**: Generates zero-knowledge proofs of execution
- **Frontend**: Visual interface for program development

### todos

- **efficient proving**

### License

MIT baby
