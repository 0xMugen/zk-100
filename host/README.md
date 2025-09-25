# ZK-100 Host

The ZK-100 Host is a Rust application that handles the assembly-to-proof pipeline for ZK-100 programs.

## Features

- Assembly language parser with label support
- Instruction encoding matching Cairo format
- Merkle root computation for program commitment
- Cairo ABI format generation for proof generation
- Integration with cairo-prove
- Organized test/args/proof directory structure
- Convenient bash scripts for proof generation

## Directory Structure

```
host/
├── src/          # Rust source code
├── test/         # Test assembly files and challenges
│   ├── test_*.asm          # Assembly programs
│   └── challenge_*.json    # Input/output specifications
├── args/         # Generated Cairo args files
│   └── args_*.json
├── proof/        # Generated proof files
│   └── proof_*.json
├── prove.sh      # Quick proof generation script
```

## Quick Start

### Generate a proof with one command

```bash
./prove.sh simple
```

This will:
1. Read `test/test_simple.asm` and `test/challenge_simple.json`
2. Generate `args/args_simple.json`
3. Create `proof/proof_simple.json`

### List available tests

```bash
./prove.sh
```

## Usage

### Assemble a program

Using challenge file (recommended):
```bash
cargo run -- assemble test/test_simple.asm --challenge test/challenge_simple.json
```

Using CLI arguments:
```bash
cargo run -- assemble test/test_simple.asm -i 42 -e 42
```

### Generate proof

Using challenge file (recommended):
```bash
cargo run -- prove test/test_simple.asm --challenge test/challenge_simple.json
```

Using CLI arguments:
```bash
cargo run -- prove test/test_simple.asm -i 42 -e 42
```

## Challenge File Format

Challenge files specify the inputs and expected outputs for a puzzle:

```json
{
  "inputs": [1, 2, 3],
  "expected": [10, 20, 30]
}
```

## Assembly Language

ZK-100 assembly supports:
- Node declarations: `NODE (row,col)`
- Labels: `label_name:`
- Instructions: MOV, ADD, SUB, NEG, SAV, SWP, JMP, JZ, JNZ, JGZ, JLZ, NOP, HLT
- Port communication: P:UP, P:DOWN, P:LEFT, P:RIGHT
- Registers: ACC, NIL, IN, OUT, LAST

Example program:
```asm
NODE (0,0)
loop:
    MOV IN, ACC
    JZ done
    MOV ACC, P:RIGHT
    JMP loop
done:
    HLT
```

## Testing

Run unit tests:
```bash
cargo test
```

## Architecture

- `main.rs` - CLI interface and command handling
- `instruction.rs` - Instruction types and encoding
- `assembler.rs` - Assembly parser and program encoding
- `merkle.rs` - Merkle root computation
- `cairo_abi.rs` - Cairo ABI format generation

## Implementation Status

✅ **Merkle Root Verification**: The Rust host now correctly implements the same blake2s-based merkle root calculation as Cairo. The merkle verification is fully enabled and working.

⚠️ **Proof Generation Issue**: While the merkle roots now match perfectly and Cairo tests pass, there's currently an issue with cairo-prove execution. The error `DiffAssertValues((Int(0), Int(1)))` occurs very early in proof generation (pc=0:16), suggesting an issue with how cairo-prove processes the arguments or ABI format. This needs further investigation.