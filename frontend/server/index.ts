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

app.post('/api/execute', async (req, res) => {
  const { nodes } = req.body as ExecuteRequest;
  
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
    
    // Execute with Rust host
    const startTime = Date.now();
    const { stdout, stderr } = await execAsync(
      `cargo run --release -- ${tempFile}`,
      { 
        cwd: path.join(__dirname, '../../host'),
        timeout: 30000 // 30 second timeout
      }
    );
    const executionTime = Date.now() - startTime;

    // Parse output
    const output: number[] = [];
    const lines = stdout.split('\n');
    
    for (const line of lines) {
      if (line.includes('Output:')) {
        const match = line.match(/Output: (\d+)/);
        if (match) {
          output.push(parseInt(match[1]));
        }
      }
    }

    // Check for errors
    if (stderr || stdout.includes('Error')) {
      return res.json({
        success: false,
        error: stderr || 'Execution failed',
        executionTime,
      });
    }

    res.json({
      success: true,
      output,
      executionTime,
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