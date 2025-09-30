export type NodePosition = {
  x: 0 | 1;
  y: 0 | 1;
};

export type NodeId = `${NodePosition['x']},${NodePosition['y']}`;

export type Instruction = 
  | 'MOV' | 'ADD' | 'SUB' | 'NEG' 
  | 'JMP' | 'JEZ' | 'JNZ' | 'JGZ' | 'JLZ'
  | 'NOP';

export type Operand = 
  | 'ACC' | 'NIL' | 'IN' | 'OUT' 
  | 'UP' | 'DOWN' | 'LEFT' | 'RIGHT'
  | number
  | string; // labels

export type CodeLine = {
  instruction: Instruction;
  operands: Operand[];
  label?: string;
  error?: string;
};

export type Node = {
  id: NodeId;
  position: NodePosition;
  code: string;
  lines: CodeLine[];
  hasError: boolean;
};

export type ExecutionLogs = {
  stdout: string;
  stderr: string;
  cairoOutput: string;
  proverOutput: string;
  rustHostOutput: string;
};

export type ExecutionResult = {
  success: boolean;
  output?: number[];
  error?: string;
  executionTime?: number;
  logs?: ExecutionLogs;
};