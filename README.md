# ZK-100 — Rules of the Game

## 🎮 Overview
You are programming a grid of **tiny compute nodes** to transform an **input stream** of numbers into an **output stream** according to the challenge specification.  

- Each node runs a small **assembly-like program** you write.  
- The programs all run **in parallel**, cycle by cycle.  
- Nodes can talk to their neighbors using message ports, and some nodes connect to the outside world (`IN`, `OUT`).  
- Your score depends on **how efficient** your solution is (cycles, messages, and nodes used).  

---

## Grid & Nodes
- The grid is **2 × 2** = 4 nodes.  
- Each node has:
  - **Registers**
    - `ACC` (main register, integer)
    - `BAK` (backup register, integer)
    - `LAST` (remembers last port used for `MOV`)
    - Flags: `Z` (ACC == 0), `N` (ACC < 0)
  - **Program** of up to 32 instructions
  - **Program Counter** (`PC`) to track the current line

Special roles:
- Node `(0,0)` has access to **IN** (reads numbers from the challenge input stream).
- Node `(1,1)` has access to **OUT** (writes numbers to the challenge output stream).

---

## Execution Model
The machine runs in **lock-step cycles**.  

Each cycle:
1. Every non-halted node reads its current instruction.
2. If the instruction is **non-blocking** (math, jumps, NOP, etc.) → execute immediately.
3. If the instruction is **MOV with a port**:
   - It may **block** until the corresponding neighbor is ready the same cycle.
   - Example: Node A does `MOV ACC, RIGHT`, Node B does `MOV LEFT, ACC` → transfer succeeds, both advance.
   - If no match, the node **waits** (does not advance PC).
4. After execution, program counters update (`PC + 1` or jump target).
5. A node with `HLT` becomes inert forever.

The system halts when **all nodes are halted**.  
If every non-halted node is blocked in the same cycle → **deadlock** (program stuck).

---

## Communication
- **Ports:** `UP`, `DOWN`, `LEFT`, `RIGHT`, `LAST`  
- **Special ports:**
  - `IN` (only at `(0,0)`): reads next input value. Blocks if no value left.
  - `OUT` (only at `(1,1)`): writes to output. Never blocks (unbounded).
  - `NIL`: fake port. As `SRC` → 0; as `DST` → discard. Never blocks.
- **Channels:** between adjacent nodes. Each channel is **1-slot**. Transfers succeed only if both sides match in the same cycle.

---

## Instruction Set
MOV SRC, DST ; move a value from SRC to DST
ADD SRC ; ACC += SRC
SUB SRC ; ACC -= SRC
NEG ; ACC = -ACC

SAV ; BAK = ACC
SWP ; swap ACC <-> BAK

JMP LABEL ; unconditional jump
JZ LABEL ; jump if ACC == 0
JNZ LABEL ; jump if ACC != 0
JGZ LABEL ; jump if ACC > 0
JLZ LABEL ; jump if ACC < 0

NOP ; do nothing
HLT ; halt this node

markdown
Copy code

- **Sources (SRC):** `ACC`, `LITERAL`, `NIL`, `IN`, `PORT`, `LAST`  
- **Destinations (DST):** `ACC`, `NIL`, `OUT`, `PORT`, `LAST`  
- **Blocking rules:**  
  - Using a **port/IN/OUT/LAST** can block.  
  - `NIL` and `ACC` never block.

---

## Assembly Layout
Programs are defined **per node**:

#NODE 0,0
MOV IN, RIGHT
HLT

#NODE 0,1
MOV LEFT, DOWN
HLT

#NODE 1,1
loop:
MOV UP, ACC
ADD 1
MOV ACC, OUT
JMP loop

yaml
Copy code

This program reads numbers from input, routes them through, increments each, and outputs the results.

---

## Scoring
Every valid run produces:
- **Cycles**: total lock-step cycles until halt.  
- **Messages**: number of successful inter-node transfers.  
- **Nodes used**: nodes with ≥1 non-NOP instruction.  

**Example score formula:**
score = cycles + 5 * nodes_used + messages / 4

yaml
Copy code
Leaderboards can rank by lowest score.

---

## Challenges
A **challenge** provides:
- `seed`: generates the input stream
- `expected output`: what must appear on OUT

Your program must transform the inputs into the correct outputs.  
Correctness can be verified by running the interpreter or by generating a **zk proof** that your program yields the same output + score.

---

## Example Run
**Challenge:** For each input number `x`, output `x+1`.

- Input: `[3, 5, -1]`  
- Expected output: `[4, 6, 0]`  

Program above produces exactly that.  

Suppose it takes:
- 60 cycles  
- 3 nodes  
- 9 messages  

Score = `60 + 5*3 + 9/4 = 75.25`.

---
