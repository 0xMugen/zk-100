# ZK-100 Frontend

A web-based interface for the ZK-100 puzzle VM, built with React, TypeScript, and Tailwind CSS.

## Features

- **2x2 Node Grid**: Visual representation of the 4 compute nodes
- **Real-time Syntax Validation**: Red underlining for syntax errors
- **Code Editor**: Individual code editors for each node
- **Assembly Execution**: Submit programs to execute with the Rust host
- **Result Display**: Shows execution output or errors

## Running the Frontend

1. Install dependencies:
```bash
bun install
```

2. Run both frontend and backend servers:
```bash
bun run dev:all
```

This will start:
- Frontend dev server on http://localhost:5173
- Backend API server on http://localhost:3001

## Using the Interface

1. Write ZK-100 assembly code in the node editors
2. Node (0,0) can use `IN` to read input
3. Node (1,1) can use `OUT` to write output
4. Click "Execute Program" to run your code
5. View results or errors in the output panel

## Example Programs

See `example_programs.md` for sample programs you can try.

## Architecture

- **Frontend**: React + Vite + TypeScript + Tailwind CSS
- **Backend**: Express.js server that creates ASM files and executes them with the Rust host
- **API Endpoint**: POST `/api/execute` - accepts node code and returns execution results