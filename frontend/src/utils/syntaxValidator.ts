import type { Instruction, Operand, CodeLine, NodePosition } from '../types/zk100';

const INSTRUCTIONS: Record<string, { operandCount: number; validOperands?: Operand[] }> = {
  'MOV': { operandCount: 2 },
  'ADD': { operandCount: 1 },
  'SUB': { operandCount: 1 },
  'NEG': { operandCount: 0, validOperands: [] },
  'JMP': { operandCount: 1 },
  'JEZ': { operandCount: 1 },
  'JNZ': { operandCount: 1 },
  'JGZ': { operandCount: 1 },
  'JLZ': { operandCount: 1 },
  'NOP': { operandCount: 0, validOperands: [] },
};

const PORTS = ['UP', 'DOWN', 'LEFT', 'RIGHT'];
const REGISTERS = ['ACC', 'NIL', 'IN', 'OUT'];

export function validateLine(line: string, nodePosition: NodePosition): CodeLine {
  const trimmed = line.trim();
  
  // Empty line or comment
  if (!trimmed || trimmed.startsWith('#')) {
    return { instruction: 'NOP', operands: [] };
  }

  // Check for label
  let label: string | undefined;
  let instructionPart = trimmed;
  
  if (trimmed.includes(':')) {
    const [labelPart, rest] = trimmed.split(':');
    label = labelPart.trim();
    instructionPart = rest.trim();
  }

  // Parse instruction and operands
  const parts = instructionPart.split(/\s+/).filter(p => p);
  if (parts.length === 0) {
    return { instruction: 'NOP', operands: [], label };
  }

  const instruction = parts[0].toUpperCase();
  const operands = parts.slice(1).map(op => {
    const upper = op.toUpperCase();
    if (REGISTERS.includes(upper) || PORTS.includes(upper)) {
      return upper as Operand;
    }
    // Check if it's a number
    const num = parseInt(op);
    if (!isNaN(num)) {
      return num;
    }
    // Otherwise it's a label
    return op;
  });

  // Validate instruction
  if (!(instruction in INSTRUCTIONS)) {
    return {
      instruction: 'NOP',
      operands: [],
      label,
      error: `Unknown instruction: ${instruction}`
    };
  }

  const instrInfo = INSTRUCTIONS[instruction];
  
  // Validate operand count
  if (operands.length !== instrInfo.operandCount) {
    return {
      instruction: instruction as Instruction,
      operands,
      label,
      error: `${instruction} expects ${instrInfo.operandCount} operands, got ${operands.length}`
    };
  }

  // Special validation for IN and OUT
  if (operands.includes('IN') && (nodePosition.x !== 0 || nodePosition.y !== 0)) {
    return {
      instruction: instruction as Instruction,
      operands,
      label,
      error: 'IN can only be used in node (0,0)'
    };
  }

  if (operands.includes('OUT') && (nodePosition.x !== 1 || nodePosition.y !== 1)) {
    return {
      instruction: instruction as Instruction,
      operands,
      label,
      error: 'OUT can only be used in node (1,1)'
    };
  }

  // Validate MOV specific rules
  if (instruction === 'MOV') {
    const [src, dst] = operands;
    
    // Can't move to ACC or NIL as destination
    if (dst === 'ACC' || dst === 'NIL') {
      return {
        instruction: instruction as Instruction,
        operands,
        label,
        error: `Cannot use ${dst} as destination in MOV`
      };
    }

    // Can't move from OUT
    if (src === 'OUT') {
      return {
        instruction: instruction as Instruction,
        operands,
        label,
        error: 'Cannot read from OUT'
      };
    }

    // Can't move to IN
    if (dst === 'IN') {
      return {
        instruction: instruction as Instruction,
        operands,
        label,
        error: 'Cannot write to IN'
      };
    }
  }

  return {
    instruction: instruction as Instruction,
    operands,
    label
  };
}

export function validateCode(code: string, nodePosition: NodePosition): CodeLine[] {
  const lines = code.split('\n');
  return lines.map(line => validateLine(line, nodePosition));
}