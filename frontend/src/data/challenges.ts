export interface Challenge {
  id: string;
  name: string;
  description: string;
  inputs: number[];
  expectedOutputs: number[];
  hint?: string;
  difficulty: 'easy' | 'medium' | 'hard';
}

export const challenges: Challenge[] = [
  {
    id: 'pass-through',
    name: 'Pass Through',
    description: 'Read a single input and pass it to output',
    inputs: [42],
    expectedOutputs: [42],
    hint: 'Use MOV to transfer data between nodes',
    difficulty: 'easy',
  },
  {
    id: 'negate',
    name: 'Negate',
    description: 'Read inputs and output their negative values',
    inputs: [5, -3, 10],
    expectedOutputs: [-5, 3, -10],
    hint: 'Use the NEG instruction to negate ACC',
    difficulty: 'easy',
  },
  {
    id: 'double',
    name: 'Double',
    description: 'Read inputs and output double their value',
    inputs: [3, 7, -2],
    expectedOutputs: [6, 14, -4],
    hint: 'ADD ACC to itself',
    difficulty: 'easy',
  },
  {
    id: 'sum-pairs',
    name: 'Sum Pairs',
    description: 'Read pairs of numbers and output their sum',
    inputs: [1, 2, 3, 4, 5, 6],
    expectedOutputs: [3, 7, 11],
    hint: 'Read two values before outputting',
    difficulty: 'medium',
  },
  {
    id: 'filter-positive',
    name: 'Filter Positive',
    description: 'Only output positive numbers (greater than zero)',
    inputs: [-5, 3, 0, -2, 8, -1, 4],
    expectedOutputs: [3, 8, 4],
    hint: 'Use JGZ (Jump if Greater than Zero)',
    difficulty: 'medium',
  },
  {
    id: 'running-sum',
    name: 'Running Sum',
    description: 'Output the running sum of all inputs',
    inputs: [1, 2, 3, 4],
    expectedOutputs: [1, 3, 6, 10],
    hint: 'Keep accumulating values',
    difficulty: 'hard',
  },
];

export function encodeChallenge(inputs: number[], outputs: number[]): string {
  const data = JSON.stringify({ i: inputs, o: outputs });
  return btoa(data).replace(/\+/g, '-').replace(/\//g, '_').replace(/=/g, '');
}

export function decodeChallenge(encoded: string): { inputs: number[], outputs: number[] } | null {
  try {
    const base64 = encoded.replace(/-/g, '+').replace(/_/g, '/');
    const data = JSON.parse(atob(base64));
    return { inputs: data.i, outputs: data.o };
  } catch {
    return null;
  }
}