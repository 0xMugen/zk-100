import type { Node, ExecutionResult } from '../types/zk100';

const API_BASE_URL = 'http://localhost:3001/api';

export async function executeProgram(nodes: Node[], inputs?: number[]): Promise<ExecutionResult> {
  try {
    const response = await fetch(`${API_BASE_URL}/execute`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ nodes, inputs }),
    });

    if (!response.ok) {
      const error = await response.text();
      return {
        success: false,
        error: `Server error: ${error}`,
      };
    }

    return await response.json();
  } catch (error) {
    return {
      success: false,
      error: `Network error: ${error instanceof Error ? error.message : 'Unknown error'}`,
    };
  }
}