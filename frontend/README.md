# ZK-100 Frontend - Local Proof Game

A web-based interface for the ZK-100 puzzle VM, built with React, TypeScript, and Tailwind CSS. This is a local proof game that demonstrates how to run Cairo proofs locally.

## Features

- **2x2 Node Grid**: Visual representation of the 4 compute nodes
- **Real-time Syntax Validation**: Red underlining for syntax errors
- **Code Editor**: Individual code editors for each node
- **Command Generation**: Shows the exact cargo commands to run locally
- **Result Display**: Shows execution output or errors

## Running the Frontend

1. Install dependencies:
```bash
bun install
```

2. Start the debug server (for automatic execution):
```bash
bun run server
```

3. In a new terminal, run the development server:
```bash
bun run dev
```

This will start:
- Debug server on http://localhost:3001 (executes Rust commands)
- Frontend dev server on http://localhost:5173

## How It Works

This is a demonstration frontend that shows what commands need to be run locally:

1. **Assemble**: Generate args.json with merkle root
   ```bash
   cd host
   cargo run --release -- assemble <asm_file> -i <inputs> -e <expected>
   ```

2. **Execute**: Run Cairo program to check logic
   ```bash
   cd crates/exec
   scarb execute --arguments-file args.json --print-program-output
   ```

3. **Prove**: Generate zero-knowledge proof
   ```bash
   cd host
   cargo run --release -- prove <asm_file> -i <inputs> -e <expected>
   ```

## Using the Interface

1. Write ZK-100 assembly code in the node editors
2. Node (0,0) can use `IN` to read input
3. Node (1,1) can use `OUT` to write output
4. Click "Execute Program" to see the commands
5. Copy and run the commands locally to generate proofs

## Example Programs

See `example_programs.md` for sample programs you can try.

## Architecture

- **Frontend**: React + Vite + TypeScript + Tailwind CSS
- **Execution**: Local cargo commands (no server required)
- **Proof Generation**: Uses STWO proving system through the Rust host