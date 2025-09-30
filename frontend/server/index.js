import express from 'express';
import cors from 'cors';
import { writeFile, unlink } from 'fs/promises';
import { exec } from 'child_process';
import { promisify } from 'util';
import path from 'path';
import { tmpdir } from 'os';
import { fileURLToPath } from 'url';
import { existsSync } from 'fs';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const execAsync = promisify(exec);
const app = express();
const PORT = 3001;

app.use(cors());
app.use(express.json());

// Find available shell
function findShell() {
  const shells = [
    process.env.SHELL,
    '/run/current-system/sw/bin/bash',
    '/usr/bin/bash',
    '/bin/bash',
    '/bin/sh'
  ].filter(Boolean);

  for (const shell of shells) {
    if (existsSync(shell)) {
      console.log(`Using shell: ${shell}`);
      return shell;
    }
  }
  
  // Default to sh without path (should work on most systems)
  console.log('Using default shell: sh');
  return 'sh';
}

const SHELL = findShell();

function generateAsmContent(nodes) {
  let asm = '';
  
  for (const node of nodes) {
    const code = node.code.trim();
    if (code) {
      asm += `NODE (${node.position.x},${node.position.y})\n`;
      const lines = code.split('\n');
      for (const line of lines) {
        let trimmed = line.trim();
        if (trimmed && !trimmed.startsWith('#')) {
          // Convert port names to P: format
          trimmed = trimmed.replace(/\b(UP|DOWN|LEFT|RIGHT)\b/g, 'P:$1');
          // Fix MOV syntax to use comma
          trimmed = trimmed.replace(/MOV\s+(\S+)\s+(\S+)/, 'MOV $1, $2');
          // Add HLT if not present
          asm += `${trimmed}\n`;
        }
      }
      // Add HLT at end of each node if not already present
      if (!code.includes('HLT')) {
        asm += `HLT\n`;
      }
      asm += '\n';
    }
  }
  
  return asm;
}

function extractErrorMessage(output) {
  // Look for specific error patterns
  if (output.includes('thread') && output.includes('panicked')) {
    const panicMatch = output.match(/thread.*?panicked at ['"](.+?)['"]/);
    if (panicMatch) return `Panic: ${panicMatch[1]}`;
    
    // Try to extract more context around panic
    const lines = output.split('\n');
    const panicIndex = lines.findIndex(line => line.includes('panicked'));
    if (panicIndex >= 0) {
      return lines.slice(Math.max(0, panicIndex - 1), panicIndex + 3).join('\n');
    }
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
  ) || output || 'Execution failed';
}

app.post('/api/execute', async (req, res) => {
  const { nodes, inputs } = req.body;
  
  console.log('=== Execution Request ===');
  console.log('Inputs:', inputs);
  console.log('Nodes:', JSON.stringify(nodes, null, 2));
  
  const asmContent = generateAsmContent(nodes);
  console.log('Generated ASM:\n', asmContent);
  
  if (!asmContent.trim()) {
    return res.json({
      success: false,
      error: 'No code to execute',
      debug: {
        nodes,
        asmContent: '',
      }
    });
  }

  const tempFile = path.join(tmpdir(), `zk100_${Date.now()}.asm`);
  const hostDir = path.join(__dirname, '../../host');
  
  console.log('Temp file:', tempFile);
  console.log('Host directory:', hostDir);
  console.log('Shell:', SHELL);
  
  try {
    // Write ASM file
    await writeFile(tempFile, asmContent);
    console.log('ASM file written successfully');
    
    // Build the command
    let command = `cargo run --release -- prove ${tempFile}`;
    
    // Add inputs if provided
    if (inputs && inputs.length > 0) {
      command += ` -i ${inputs.join(',')}`;
    }
    
    // Add expected outputs (for now, same as inputs for testing)
    if (inputs && inputs.length > 0) {
      command += ` -e ${inputs.join(',')}`;
    }
    
    console.log('Command:', command);
    console.log('Working directory:', hostDir);
    
    // Execute with Rust host
    const startTime = Date.now();
    
    try {
      const { stdout, stderr } = await execAsync(
        command,
        { 
          cwd: hostDir,
          timeout: 60000, // 60 second timeout
          maxBuffer: 1024 * 1024 * 10, // 10MB buffer
          shell: SHELL,
          env: { ...process.env }
        }
      );
      
      const executionTime = Date.now() - startTime;
      
      console.log('=== Execution Output ===');
      console.log('STDOUT:', stdout);
      console.log('STDERR:', stderr);
      console.log('Execution time:', executionTime, 'ms');

      // Capture all logs
      const logs = {
        stdout: stdout || '',
        stderr: stderr || '',
        cairoOutput: '',
        proverOutput: '',
        rustHostOutput: stdout || '',
      };

      // Parse different types of output
      const output = [];
      const lines = (stdout || '').split('\n');
      
      for (const line of lines) {
        // Capture output values
        if (line.includes('Output:')) {
          const match = line.match(/Output:\s*(-?\d+)/);
          if (match) {
            output.push(parseInt(match[1]));
            console.log('Found output:', match[1]);
          }
        }
        
        // Capture Cairo execution logs
        if (line.includes('Cairo') || line.includes('scarb') || line.includes('Executing')) {
          logs.cairoOutput += line + '\n';
        }
        
        // Capture prover logs
        if (line.includes('Proving') || line.includes('Proof') || line.includes('cairo-prove')) {
          logs.proverOutput += line + '\n';
        }
      }

      // Check for errors
      const hasError = stderr || 
        stdout.includes('Error') || 
        stdout.includes('error:') || 
        stdout.includes('thread') && stdout.includes('panicked') ||
        stdout.includes('failed') ||
        stdout.includes('FAILED');
      
      if (hasError) {
        console.log('Error detected in output');
        return res.json({
          success: false,
          error: stderr || extractErrorMessage(stdout),
          output,
          executionTime,
          logs,
          debug: {
            asmContent,
            command,
            workingDir: hostDir,
            shell: SHELL,
            tempFile,
          }
        });
      }

      console.log('Execution successful, outputs:', output);
      
      res.json({
        success: true,
        output,
        executionTime,
        logs,
        debug: {
          asmContent,
          command,
          workingDir: hostDir,
          shell: SHELL,
          tempFile,
        }
      });
      
    } catch (execError) {
      console.error('Exec error:', execError);
      
      // Handle execution errors
      const errorMessage = execError.message || 'Unknown execution error';
      const errorOutput = execError.stdout || '';
      const errorStderr = execError.stderr || '';
      
      return res.json({
        success: false,
        error: `Execution failed: ${errorMessage}`,
        output: [],
        logs: {
          stdout: errorOutput,
          stderr: errorStderr,
          cairoOutput: '',
          proverOutput: '',
          rustHostOutput: errorOutput + '\n' + errorStderr,
        },
        debug: {
          asmContent,
          command,
          workingDir: hostDir,
          shell: SHELL,
          tempFile,
          execError: {
            message: errorMessage,
            code: execError.code,
            killed: execError.killed,
            signal: execError.signal,
          }
        }
      });
    }

  } catch (error) {
    console.error('General error:', error);
    res.json({
      success: false,
      error: error instanceof Error ? error.message : 'Unknown error',
      debug: {
        asmContent,
        tempFile,
        hostDir,
        shell: SHELL,
        errorStack: error instanceof Error ? error.stack : undefined,
      }
    });
  } finally {
    // Clean up temp file
    try {
      await unlink(tempFile);
      console.log('Temp file cleaned up');
    } catch (e) {
      console.log('Failed to clean up temp file:', e.message);
    }
  }
});

app.listen(PORT, () => {
  console.log(`ZK-100 backend server running on http://localhost:${PORT}`);
  console.log(`Using shell: ${SHELL}`);
  console.log(`Host directory: ${path.join(__dirname, '../../host')}`);
});