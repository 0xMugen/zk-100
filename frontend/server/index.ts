import express from 'express';
import cors from 'cors';
import { writeFile, unlink } from 'fs/promises';
import { exec } from 'child_process';
import { promisify } from 'util';
import path from 'path';
import { tmpdir } from 'os';

const execAsync = promisify(exec);
const app = express();
const PORT = 3001;

app.use(cors());
app.use(express.json());

interface Node {
  id: string;
  position: { x: number; y: number };
  code: string;
}

interface ExecuteRequest {
  nodes: Node[];
  inputs?: number[];
}

function generateAsmContent(nodes: Node[]): string {
  let asm = '';
  
  for (const node of nodes) {
    const code = node.code.trim();
    if (code) {
      asm += `NODE ${node.position.x} ${node.position.y}\n`;
      const lines = code.split('\n');
      for (const line of lines) {
        const trimmed = line.trim();
        if (trimmed && !trimmed.startsWith('#')) {
          asm += `  ${trimmed}\n`;
        }
      }
      asm += '\n';
    }
  }
  
  return asm;
}

function extractErrorMessage(output: string): string {
  // Look for specific error patterns
  if (output.includes('thread') && output.includes('panicked')) {
    const panicMatch = output.match(/thread.*?panicked at ['"](.+?)['"]/);
    if (panicMatch) return `Panic: ${panicMatch[1]}`;
  }
  
  if (output.includes('error:')) {
    const errorMatch = output.match(/error:\s*(.+?)$/m);
    if (errorMatch) return errorMatch[1];
  }
  
  if (output.includes('Error:')) {
    const errorMatch = output.match(/Error:\s*(.+?)$/m);
    if (errorMatch) return errorMatch[1];
  }
  
  // Return first non-empty line that might be an error
  const lines = output.split('\n').filter(line => line.trim());
  return lines.find(line => 
    line.includes('Error') || 
    line.includes('error') || 
    line.includes('failed') ||
    line.includes('Failed')
  ) || 'Execution failed';
}

app.post('/api/execute', async (req, res) => {
  const { nodes, inputs } = req.body as ExecuteRequest;
  
  const asmContent = generateAsmContent(nodes);
  if (!asmContent.trim()) {
    return res.json({
      success: false,
      error: 'No code to execute',
    });
  }

  const tempFile = path.join(tmpdir(), `zk100_${Date.now()}.asm`);
  
  try {
    // Write ASM file
    await writeFile(tempFile, asmContent);
    
    // Create input string for the Rust host
    const inputArgs = inputs && inputs.length > 0 ? inputs.join(' ') : '';
    
    // Execute with Rust host
    const startTime = Date.now();
    const command = inputArgs 
      ? `echo "${inputArgs}" | cargo run --release -- ${tempFile} 2>&1`
      : `cargo run --release -- ${tempFile} 2>&1`;
      
    const { stdout, stderr } = await execAsync(
      command,
      { 
        cwd: path.join(__dirname, '../../host'),
        timeout: 30000, // 30 second timeout
        maxBuffer: 1024 * 1024 * 10, // 10MB buffer
        shell: '/bin/bash'
      }
    );
    const executionTime = Date.now() - startTime;

    // Capture all logs
    const logs = {
      stdout: stdout,
      stderr: stderr,
      cairoOutput: '',
      proverOutput: '',
      rustHostOutput: '',
    };

    // Parse different types of output
    const output: number[] = [];
    const lines = stdout.split('\n');
    
    for (const line of lines) {
      // Capture output values
      if (line.includes('Output:')) {
        const match = line.match(/Output: (-?\d+)/);
        if (match) {
          output.push(parseInt(match[1]));
        }
      }
      
      // Capture Cairo execution logs
      if (line.includes('Cairo') || line.includes('scarb')) {
        logs.cairoOutput += line + '\n';
      }
      
      // Capture prover logs
      if (line.includes('Proving') || line.includes('Proof') || line.includes('cairo-prove')) {
        logs.proverOutput += line + '\n';
      }
      
      // All rust host output
      logs.rustHostOutput += line + '\n';
    }

    // Check for errors
    const hasError = stderr || stdout.includes('Error') || stdout.includes('error:') || stdout.includes('thread') && stdout.includes('panicked');
    
    if (hasError) {
      return res.json({
        success: false,
        error: stderr || extractErrorMessage(stdout),
        output,
        executionTime,
        logs,
      });
    }

    res.json({
      success: true,
      output,
      executionTime,
      logs,
    });

  } catch (error) {
    res.json({
      success: false,
      error: error instanceof Error ? error.message : 'Unknown error',
    });
  } finally {
    // Clean up temp file
    try {
      await unlink(tempFile);
    } catch (e) {
      // Ignore cleanup errors
    }
  }
});

app.listen(PORT, () => {
  console.log(`ZK-100 backend server running on http://localhost:${PORT}`);
});