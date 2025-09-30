import type { Node, ExecutionResult } from '../types/zk100';
import { logger } from '../utils/logger';

const API_URL = 'http://localhost:3001';

interface DebugResponse {
  success: boolean;
  traces?: {
    assemble: any;
    scarb: any;
    prove: any;
  };
  errors?: {
    assemble: string | null;
    scarb: string | null;
    prove: string | null;
  };
  argsJson?: string;
  asmContent?: string;
  scarbOutput?: string;
  error?: string;
}

function generateAsmContent(nodes: Node[]): string {
  let asm = '';
  
  for (const node of nodes) {
    const code = node.code.trim();
    if (code) {
      // Swap x,y to convert from frontend (col,row) to Cairo VM (row,col)
      asm += `NODE (${node.position.y},${node.position.x})\n`;
      const lines = code.split('\n');
      for (const line of lines) {
        let trimmed = line.trim();
        if (trimmed && !trimmed.startsWith('#')) {
          // Convert standalone port names to P: format (but not IN/OUT)
          trimmed = trimmed.replace(/\b(UP|DOWN|LEFT|RIGHT)\b/g, (match) => {
            // Don't convert if it's part of a larger word
            return `P:${match}`;
          });
          // Fix MOV syntax to use comma
          trimmed = trimmed.replace(/MOV\s+(\S+)\s+(\S+)/, 'MOV $1, $2');
          asm += `${trimmed}\n`;
        }
      }
      // Add HLT if not present
      if (!code.includes('HLT')) {
        asm += `HLT\n`;
      }
      asm += '\n';
    }
  }
  
  return asm;
}

export async function executeProgram(nodes: Node[], inputs?: number[]): Promise<ExecutionResult> {
  try {
    const startTime = Date.now();
    
    logger.info('Sending execution request', { nodes, inputs });
    
    // Call the debug endpoint to get full traces
    const response = await fetch(`${API_URL}/api/debug`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ nodes, inputs }),
    });
    
    if (!response.ok) {
      throw new Error(`Server error: ${response.status} ${response.statusText}`);
    }
    
    const data: DebugResponse = await response.json();
    const executionTime = Date.now() - startTime;
    
    logger.info('Received response', data);
    
    // Build detailed error message with traces
    if (!data.success || data.errors?.assemble || data.errors?.scarb || data.errors?.prove) {
      let errorMessage = '';
      
      if (data.errors?.assemble) {
        errorMessage += '=== Assembly Error ===\n';
        errorMessage += data.errors.assemble + '\n\n';
        if (data.traces?.assemble?.errors?.length) {
          errorMessage += 'Trace:\n' + data.traces.assemble.errors.join('\n') + '\n\n';
        }
      }
      
      if (data.errors?.scarb) {
        errorMessage += '=== Cairo Execution Error ===\n';
        errorMessage += data.errors.scarb + '\n\n';
        if (data.traces?.scarb?.errors?.length) {
          errorMessage += 'Trace:\n' + data.traces.scarb.errors.join('\n') + '\n\n';
        }
      }
      
      if (data.errors?.prove) {
        errorMessage += '=== Proving Error ===\n';
        errorMessage += data.errors.prove + '\n\n';
        if (data.traces?.prove?.errors?.length) {
          errorMessage += 'Trace:\n' + data.traces.prove.errors.join('\n') + '\n\n';
        }
      }
      
      // Add debug information
      if (data.scarbOutput) {
        errorMessage += '=== Scarb Output ===\n';
        errorMessage += data.scarbOutput + '\n\n';
      }
      
      if (data.argsJson) {
        errorMessage += '=== Generated args.json ===\n';
        errorMessage += data.argsJson + '\n\n';
      }
      
      if (data.asmContent) {
        errorMessage += '=== Generated ASM ===\n';
        errorMessage += data.asmContent + '\n';
      }
      
      return {
        success: false,
        error: errorMessage || data.error || 'Execution failed',
        executionTime,
        debug: {
          traces: data.traces,
          argsJson: data.argsJson,
          asmContent: data.asmContent,
        }
      };
    }
    
    // Extract outputs from traces
    const output: number[] = [];
    
    // First try to parse scarb output directly
    if (data.scarbOutput) {
      const lines = data.scarbOutput.split('\n');
      for (const line of lines) {
        if (line.includes('Run completed successfully')) {
          // Look for the array output format
          const arrayMatch = line.match(/\[([^\]]+)\]/);
          if (arrayMatch) {
            const values = arrayMatch[1].split(',').map(v => v.trim());
            values.forEach(v => {
              const num = parseInt(v);
              if (!isNaN(num)) {
                output.push(num);
              }
            });
          }
        }
      }
    }
    
    // If no outputs found, try traces
    if (output.length === 0 && data.traces?.scarb) {
      // Look in finalState first
      if (data.traces.scarb.finalState?.outputs) {
        const outputStr = data.traces.scarb.finalState.outputs;
        const matches = outputStr.match(/-?\d+/g);
        if (matches) {
          matches.forEach((m: string) => output.push(parseInt(m)));
        }
      }
      
      // Also check instructions for Output lines
      if (data.traces.scarb.instructions) {
        data.traces.scarb.instructions.forEach((line: string) => {
          if (line.includes('Output:')) {
            const match = line.match(/Output:\s*(-?\d+)/);
            if (match) {
              output.push(parseInt(match[1]));
            }
          }
        });
      }
    }
    
    return {
      success: true,
      output,
      executionTime,
      logs: {
        stdout: JSON.stringify(data.traces, null, 2),
        stderr: '',
        cairoOutput: JSON.stringify(data.traces?.scarb, null, 2),
        proverOutput: JSON.stringify(data.traces?.prove, null, 2),
        rustHostOutput: JSON.stringify(data.traces?.assemble, null, 2),
      },
      debug: {
        traces: data.traces,
        argsJson: data.argsJson,
        asmContent: data.asmContent,
      }
    };
    
  } catch (error) {
    logger.error('Execution error', error);
    return {
      success: false,
      error: `Execution error: ${error instanceof Error ? error.message : 'Unknown error'}`,
    };
  }
}