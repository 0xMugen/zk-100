# ZK-100 Host

The ZK-100 Host is a Rust application that handles the assembly-to-proof pipeline for ZK-100 programs.

## Features

- Assembly language parser with label support
- Instruction encoding matching Cairo format
- Merkle root computation for program commitment
- Cairo ABI format generation for proof generation
- Integration with cairo-prove

## Usage

### Assemble a program

```bash
cargo run -- assemble <input.asm> -i <inputs> -e <expected> -o <output.json>
```

Example:
```bash
cargo run -- assemble test_program.asm -i 42 -e 42 -o args.json
```

### Generate proof

```bash
cargo run -- prove <input.asm> -i <inputs> -e <expected> --proof <proof.json>
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